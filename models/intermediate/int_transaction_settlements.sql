with settlements as (

    select *
    from {{ ref('stg_settlements') }}

),

ranked as (

    select
        settlement_id,
        transaction_id,
        net_amount_brl,
        fee_amount_brl,
        settlement_date,
        paid_at,
        row_number() over (
            partition by transaction_id
            order by settlement_date desc, paid_at desc, settlement_id desc
        ) as rn
    from settlements

)

select
    settlement_id,
    transaction_id,
    net_amount_brl,
    fee_amount_brl,
    settlement_date,
    paid_at
from ranked
where rn = 1