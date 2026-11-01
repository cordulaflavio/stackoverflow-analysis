-- posts_answers: coverage window, id uniqueness and orphans
-- (answers whose parent question is not in posts_questions).
-- Estimated scan (dry-run): 1.00 GB.
with answers as (
    select
        id as answer_id,
        parent_id,
        creation_date
    from `bigquery-public-data.stackoverflow.posts_answers`
),

question_ids as (
    select id as question_id
    from `bigquery-public-data.stackoverflow.posts_questions`
),

answers_with_parent as (
    select
        answers.answer_id,
        answers.creation_date,
        question_ids.question_id
    from answers
    left join question_ids
        on answers.parent_id = question_ids.question_id
)

select
    count(*) as answers,
    count(*) - count(distinct answer_id) as duplicate_ids,
    min(creation_date) as first_answer_at,
    max(creation_date) as last_answer_at,
    countif(question_id is null) as orphan_answers,
    round(safe_divide(countif(question_id is null), count(*)), 4) as orphan_share
from answers_with_parent
