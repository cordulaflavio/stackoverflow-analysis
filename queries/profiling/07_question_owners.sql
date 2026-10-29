-- Can question owners be found in users?
-- Hypothesis tested here: only the asker can accept an answer, so questions without an owner
-- (deleted account) should show a lower accepted-answer rate. The data refuted it: they show a
-- higher one, since acceptances made before the account was deleted are kept (see
-- docs/data_quality.md).
with questions as (
    select
        owner_user_id,
        creation_date as question_created_at,
        accepted_answer_id
    from `bigquery-public-data.stackoverflow.posts_questions`
),

users as (
    select
        id as user_id,
        creation_date as user_created_at
    from `bigquery-public-data.stackoverflow.users`
),

questions_with_owner as (
    select
        questions.owner_user_id,
        questions.question_created_at,
        questions.accepted_answer_id,
        users.user_id,
        users.user_created_at
    from questions
    left join users
        on questions.owner_user_id = users.user_id
)

select
    count(*) as questions,
    (select count(*) - count(distinct user_id) from users) as duplicate_user_ids,
    countif(owner_user_id is null) as no_owner,
    countif(owner_user_id is not null and user_id is null) as owner_not_in_users,
    countif(user_created_at > question_created_at) as user_created_after_question,
    round(safe_divide(
        countif(owner_user_id is null and accepted_answer_id is not null),
        countif(owner_user_id is null)
    ), 4) as accepted_share_without_owner,
    round(safe_divide(
        countif(owner_user_id is not null and accepted_answer_id is not null),
        countif(owner_user_id is not null)
    ), 4) as accepted_share_with_owner
from questions_with_owner
