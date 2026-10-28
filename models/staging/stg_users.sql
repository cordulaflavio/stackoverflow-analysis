-- `reputation` is the value at the snapshot date, not at the time a question was posted.
with users as (
    select
        id as user_id,
        reputation,
        creation_date as created_at
    from {{ source('stackoverflow', 'users') }}
)

select * from users
