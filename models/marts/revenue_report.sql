{{
    config(
        materialized='table',
        partition_by={
            "field": "transaction_date",
            "data_type": "date",
            "granularity": "day"
        }
    )
}}

with transactions as (

    select *
    from {{ ref('stg_transactions') }}

),

merchants as (

    select *
    from {{ ref('stg_merchants') }}

),

settlements as (

    select *
    from {{ ref('int_transaction_settlements') }}

),

final as (

    select
        t.transaction_id,
        t.merchant_id,
        m.merchant_name,
        m.mcc_code,
        t.customer_id,
        t.amount_cents,
        t.amount_brl,
        t.status,
        t.payment_method,
        date(t.created_at) as transaction_date,
        t.created_at,
        t.updated_at,
        s.settlement_id,
        s.net_amount_brl,
        s.fee_amount_brl,
        s.settlement_date,
        s.paid_at,
        case
            when t.status = 'captured' then t.amount_brl
            when t.status = 'refunded' then -t.amount_brl
            when t.status = 'chargeback' then -t.amount_brl
            else 0
        end as revenue_impact_brl
    from transactions t
    left join merchants m
        on t.merchant_id = m.merchant_id
    left join settlements s
        on t.transaction_id = s.transaction_id
    where t.status in ('captured', 'refunded', 'chargeback')

)

select *
from final