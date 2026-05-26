{{ config(
    tags=['ad_spend', 'external'],
    materialized='incremental',
    unique_key=['campaign_id', 'spend_date'],
    incremental_strategy='delete+insert'
) }}

-- Production config:
-- BigQuery: partition_by spend_date, cluster_by (campaign_id, client_id)
-- Snowflake: cluster by (campaign_id, spend_date)
-- Redshift: distkey(campaign_id), sortkey(spend_date)

with
raw_ad_spend as (select * from {{ source('external', 'ad_spend') }}),

renamed as (
    select
        cast(campaign_id as varchar) as campaign_id,
        cast(client_id as varchar) as client_id,
        cast(spend_date as date) as spend_date,
        cast(actual_spend as decimal) as actual_spend
    from raw_ad_spend

    {% if is_incremental() %}
        where cast(spend_date as date) >= (select max(spend_date) from {{ this }}) - interval '7' day
    {% endif %}
)

select * from renamed