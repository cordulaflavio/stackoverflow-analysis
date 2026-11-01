-- Is accepted_answer_id trustworthy?
-- Checks that the accepted answer exists, belongs to the same question and was posted
-- after it, and measures self-accepted answers (asker answered and accepted their own question).
-- Estimated scan (dry-run): 1.73 GB.
with questions as (
    select
        id as question_id,
        owner_user_id as asker_id,
        creation_date as question_created_at,
        accepted_answer_id
    from `bigquery-public-data.stackoverflow.posts_questions`
    where accepted_answer_id is not null
),

answers as (
    select
        id as answer_id,
        parent_id,
        owner_user_id as answerer_id,
        creation_date as answer_created_at
    from `bigquery-public-data.stackoverflow.posts_answers`
),

accepted as (
    select
        questions.question_id,
        questions.asker_id,
        questions.question_created_at,
        answers.answer_id,
        answers.parent_id,
        answers.answerer_id,
        answers.answer_created_at
    from questions
    left join answers
        on questions.accepted_answer_id = answers.answer_id
)

select
    count(*) as questions_with_accepted,
    countif(answer_id is null) as accepted_answer_missing,
    countif(parent_id != question_id) as accepted_answer_other_question,
    countif(answer_created_at < question_created_at) as accepted_before_question,
    countif(answerer_id = asker_id) as self_accepted,
    round(safe_divide(countif(answerer_id = asker_id), count(*)), 4) as self_accepted_share
from accepted
