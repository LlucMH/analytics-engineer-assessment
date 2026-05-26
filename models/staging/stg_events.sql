{{ config(
    tags=['events']
) }}

with 
raw_events as (select * from {{ source('raw', 'raw_events') }}),

renamed as (
    select
        event_id,
        campaign_id,
        client_id,
        account_id,
        cast(event_date as date) as event_date,
        lower(event_type) as event_type,
        cast(coalesce(revenue_influenced, 0) as decimal) as revenue_influenced,
        lower(event_type) in ('form_fill', 'meeting_booked') as is_conversion,
        lower(event_type) = 'meeting_booked' as is_meeting_booked,
        date_trunc('month', cast(event_date as date)) as event_month
    from raw_events
    where event_id is not null
)

select * from renamed