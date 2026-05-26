{{ config(
    tags=['channels', 'revenue']
) }}

with
events as (select * from {{ ref('stg_events') }} where event_date >= current_date - interval '90' day),

campaigns as (select * from {{ ref('stg_campaigns') }}),

channel_revenue as (
    select
        e.client_id,
        c.channel,
        sum(e.revenue_influenced) as total_revenue_influenced
    from events e
    -- INNER JOIN: events without a campaign have no channel and cannot be aggregated.
    inner join campaigns c
        on e.campaign_id = c.campaign_id
    group by 1, 2
),

ranked as (
    select
        client_id,
        channel,
        total_revenue_influenced,
        row_number() over (
            partition by client_id
            order by total_revenue_influenced desc
        ) as channel_rank
    from channel_revenue
)

select
    client_id,
    channel,
    total_revenue_influenced,
    channel_rank
from ranked
where channel_rank <= 3
order by client_id, channel_rank