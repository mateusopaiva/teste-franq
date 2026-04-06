with source as (

    select *
    from {{ source('raw', 'transactions') }}

),

renamed as (

    select
        cast(transaction_id as string) as transaction_id,
        cast(merchant_id as string) as merchant_id,
        cast(customer_id as string) as customer_id,
        cast(amount_cents as int64) as amount_cents,
        safe_divide(cast(amount_cents as numeric), 100) as amount_brl,
        cast(status as string) as status,
        cast(payment_method as string) as payment_method,
        cast(created_at as timestamp) as created_at,
        cast(updated_at as timestamp) as updated_at,
        metadata
    from source
    where status != 'test'

)

select *
from renamed