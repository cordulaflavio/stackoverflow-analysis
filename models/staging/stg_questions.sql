-- `body` is left out on purpose: it is 36 of the table's 40 GB and is read only once,
-- in stg_question_body_features.
with questions as (
    select
        id as question_id,
        title,
        -- '|'-separated, exactly as in the source (e.g. 'python|pandas'); split downstream.
        tags,
        creation_date as created_at,
        owner_user_id,
        accepted_answer_id,
        answer_count,
        -- Cumulative at the snapshot date, so observed after posting, not at posting time.
        score,
        view_count,
        comment_count,
        -- Null most likely means zero; kept as-is here and handled where it is used.
        favorite_count,
        last_edit_date as last_edited_at
    from {{ source('stackoverflow', 'posts_questions') }}
)

select * from questions
