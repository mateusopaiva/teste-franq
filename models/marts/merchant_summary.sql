{{ config(materialized='table') }}

select
    merchant_id,
    merchant_name,
    mcc_code,
    count(*) as total_transactions,
    sum(revenue_impact_brl) as total_revenue_brl,
    sum(coalesce(fee_amount_brl, 0)) as total_fees_brl,
    sum(case when status = 'chargeback' then 1 else 0 end) as chargebacks,
    safe_divide(
        sum(case when status = 'chargeback' then 1 else 0 end),
        count(*)
    ) as chargeback_rate,
    min(transaction_date) as first_transaction,
    max(transaction_date) as last_transaction
from {{ ref('revenue_report') }}
group by 1, 2, 3