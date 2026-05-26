{{ config(
    tags=['ad_spend', 'budget', 'finance']
) }}

-- Production config:
-- BigQuery: no partition (small aggregated table), cluster_by (client_id, channel)
-- Snowflake: cluster by (client_id, channel)
-- Redshift: distkey(client_id), sortkey(channel)

with
campaigns as (select * from {{ ref('stg_campaigns') }}),

ad_spend as (select * from {{ ref('stg_ad_spend') }}),

campaign_spend as (
    select
        campaign_id,
        sum(actual_spend) as total_actual_spend
    from ad_spend
    group by 1
)

select
    c.client_id,
    c.campaign_id,
    c.campaign_name,
    c.channel,
    c.budget,
    coalesce(s.total_actual_spend, 0) as total_actual_spend,
    c.budget - coalesce(s.total_actual_spend, 0) as variance,
    round(
        (c.budget - coalesce(s.total_actual_spend, 0))
        / nullif(c.budget, 0) * 100,
    2) as variance_pct,
    case
        when coalesce(s.total_actual_spend, 0) > c.budget then 'over_budget'
        else 'under_budget'
    end as status
from campaigns c
left join campaign_spend s
    on c.campaign_id = s.campaign_id