with source as (

    select *
    from {{ source('raw', 'merchants') }}

),

renamed as (

    select
        cast(id as string) as merchant_id,
        trim(cast(trade_name as string)) as merchant_name,
        cast(mcc_code as string) as mcc_code
    from source

)

select *
from renamed