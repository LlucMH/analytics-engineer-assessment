{{ config(
    tags=['campaigns', 'efficiency']
) }}

with
events as (select * from {{ ref('stg_events') }}),

campaigns as (select * from {{ ref('stg_campaigns') }}),

campaign_meetings as (
    select
        campaign_id,
        count(distinct event_id) as meetings_booked
    from events
    where is_meeting_booked
    group by 1
),

campaign_efficiency as (
    select
        c.client_id,
        c.campaign_id,
        c.campaign_name,
        c.channel,
        c.budget,
        m.meetings_booked,
        c.budget / m.meetings_booked as cost_per_meeting,
        avg(c.budget / m.meetings_booked) over (
            partition by c.channel
        ) as avg_cost_per_meeting_for_channel
    from campaigns c
    -- INNER JOIN: only campaigns with at least one meeting booked.
    -- Campaigns with no meetings are excluded before the window function.
    inner join campaign_meetings m
        on c.campaign_id = m.campaign_id
)

select
    client_id,
    campaign_id,
    campaign_name,
    channel,
    budget,
    meetings_booked,
    round(cost_per_meeting, 2) as cost_per_meeting,
    round(avg_cost_per_meeting_for_channel, 2) as avg_cost_per_meeting_for_channel
from campaign_efficiency
where cost_per_meeting < avg_cost_per_meeting_for_channel