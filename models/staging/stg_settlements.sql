with source as (

    select *
    from {{ source('raw', 'settlements') }}

),

unnested as (

    select
        cast(settlement_id as string) as settlement_id,
        cast(transaction_id as string) as transaction_id,
        safe_divide(cast(net_amount_cents as numeric), 100) as net_amount_brl,
        safe_divide(cast(fee_amount_cents as numeric), 100) as fee_amount_brl,
        cast(settlement_date as date) as settlement_date,
        cast(paid_at as timestamp) as paid_at
    from source,
    unnest(transaction_ids) as transaction_id

)

select *
from unnested