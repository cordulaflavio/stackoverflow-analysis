-- Only the columns needed to time answers and to spot self-accepted ones; `body` is left out.
with answers as (
    select
        id as answer_id,
        parent_id as question_id,
        owner_user_id,
        creation_date as created_at,
        score
    from {{ source('stackoverflow', 'posts_answers') }}
)

select * from answers
