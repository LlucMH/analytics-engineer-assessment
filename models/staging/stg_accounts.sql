{{ config(
    tags=['accounts']
) }}

with
raw_accounts as (select * from {{ source('raw', 'raw_accounts') }}),

renamed as (
    select
        account_id,
        client_id,
        account_name,
        industry,
        cast(employee_count as integer) as employee_count
    from raw_accounts
    where account_id is not null
)

select * from renamed