-- ============================================================
-- ISSUES FOUND:
-- ============================================================
--
-- 1. MART READS DIRECTLY FROM RAW SOURCES
--    Marts should consume staging models via ref(), not raw sources via source().
--    Skipping staging bypasses cleaning, casting and business logic.
--
-- 2. MISSING client_id — RESULT IS GLOBAL, NOT PER CLIENT
--    The model is described as "top 10 accounts by client" but client_id
--    is absent from SELECT and GROUP BY. Result is a global top 10.
--
-- 3. LIMIT 10 IS NOT PER CLIENT
--    LIMIT 10 returns the global top 10, not top 10 per client.
--    Requires ROW_NUMBER() OVER (PARTITION BY client_id) instead.
--
-- 4. HARDCODED DATE FILTER ('2024-01-01')
--    A literal date goes stale over time and silently returns wrong results.
--    Should be relative to current_date or removed if the intent is all-time.
--
-- 5. LEFT JOIN HIDES DATA QUALITY ISSUES
--    An account_id in events that doesn't exist in accounts is a data quality
--    problem. LEFT JOIN silently produces NULLs instead of surfacing it.
--
-- 6. revenue_influenced IS NULL FOR NON-CONVERSION EVENTS
--    In raw_events, revenue_influenced is NULL for impressions and clicks.
--    sum() over NULLs works but the intent is ambiguous without staging.
--
-- 7. revenue_per_event IS A MISLEADING METRIC
--    Divides total revenue by ALL events including impressions and clicks
--    which carry no revenue. Only meaningful over conversion events.
-- ============================================================

select
    e.account_id,
    a.account_name,
    a.industry,
    sum(e.revenue_influenced) as total_revenue,
    count(*) as total_events,
    sum(e.revenue_influenced) / count(*) as revenue_per_event

from {{ source('raw', 'raw_events') }} e
left join {{ source('raw', 'raw_accounts') }} a on e.account_id = a.account_id

where e.event_date >= '2024-01-01'

group by 1, 2, 3

order by total_revenue desc
limit 10

-- ============================================================
-- YOUR IMPROVED VERSION:
-- ============================================================

--with
-- events as (select * from {{ ref('stg_events') }}),

-- accounts as (select * from {{ ref('stg_accounts') }}),

-- account_metrics as (
--     select
--         e.client_id,
--         e.account_id,
--         sum(e.revenue_influenced)                   as total_revenue_influenced,
--         count(distinct e.event_id)                  as total_events,
--         count(distinct case when e.is_conversion then e.event_id end) as total_conversions
--     from events e
--     group by 1, 2
-- ),

-- ranked as (
--     select
--         m.client_id,
--         m.account_id,
--         a.account_name,
--         a.industry,
--         m.total_revenue_influenced,
--         m.total_events,
--         m.total_conversions,
--         row_number() over (
--             partition by m.client_id
--             order by m.total_revenue_influenced desc
--         ) as account_rank
--     from account_metrics m
--     INNER JOIN: unmatched account_ids indicate a data quality issue, not hidden with NULLs.
--     inner join accounts a
--         on m.account_id = a.account_id
--         and m.client_id = a.client_id
-- )

-- select
--     client_id,
--     account_rank,
--     account_id,
--     account_name,
--     industry,
--     total_revenue_influenced,
--     total_events,
--     total_conversions
-- from ranked
-- where account_rank <= 10