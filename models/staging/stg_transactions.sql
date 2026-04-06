with source as (

    select *
    from {{ source('raw', 'transactions') }}

),

renamed as (

    select
        trim(cast(transaction_id as string)) as transaction_id,
        trim(cast(merchant_id as string)) as merchant_id,
        trim(cast(customer_id as string)) as customer_id,
        cast(amount_cents as int64) as amount_cents,
        safe_divide(cast(amount_cents as numeric), 100) as amount_brl,
        trim(cast(status as string)) as status,
        trim(cast(payment_method as string)) as payment_method,
        cast(created_at as timestamp) as created_at,
        cast(updated_at as timestamp) as updated_at,
        metadata
    from source
    where status != 'test'

)

select *
from renamed