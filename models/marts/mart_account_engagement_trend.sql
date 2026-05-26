{{ config(
    tags=['accounts', 'engagement']
) }}

with
events as (select * from {{ ref('stg_events') }}),

monthly_events as (
    select
        client_id,
        account_id,
        event_month,
        count(distinct event_id) as total_events
    from events
    group by 1, 2, 3
),

with_mom as (
    select
        client_id,
        account_id,
        event_month,
        total_events,
        lag(total_events) over (
            partition by client_id, account_id
            order by event_month asc
        ) as prev_month_events
    from monthly_events
)

select
    client_id,
    account_id,
    event_month,
    total_events,
    prev_month_events,
    total_events - coalesce(prev_month_events, 0) as mom_change
from with_mom