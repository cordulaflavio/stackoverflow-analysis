-- How many questions have an invalid acceptance, counting each question once?
-- Query 06 counts each failed check on its own (230 missing, 62 from another question, 40
-- posted before the question), and those add up to 332. A question can fail more than one
-- check: an accepted answer from another question can also be older than this question.
-- fct_questions.has_invalid_accepted_answer counts questions, so it can be lower than 332.
-- Estimated scan (dry-run): 1.28 GB.
-- Result: 332 failed checks on 331 questions. One question (id 3896786) fails two: its
-- accepted answer belongs to another question and was posted before it.
with questions as (
    select
        id as question_id,
        creation_date as question_created_at,
        accepted_answer_id
    from `bigquery-public-data.stackoverflow.posts_questions`
    where accepted_answer_id is not null
),

answers as (
    select
        id as answer_id,
        parent_id,
        creation_date as answer_created_at
    from `bigquery-public-data.stackoverflow.posts_answers`
),

checks as (
    select
        questions.question_id,
        answers.answer_id is null as is_missing,
        coalesce(answers.parent_id != questions.question_id, false) as is_other_question,
        coalesce(answers.answer_created_at < questions.question_created_at, false) as is_before_question
    from questions
    left join answers
        on questions.accepted_answer_id = answers.answer_id
),

failed as (
    select
        question_id,
        is_missing,
        is_other_question,
        is_before_question,
        cast(is_missing as int64) + cast(is_other_question as int64) + cast(is_before_question as int64)
            as failed_checks
    from checks
    where is_missing or is_other_question or is_before_question
)

select
    countif(is_missing) as accepted_answer_missing,
    countif(is_other_question) as accepted_answer_other_question,
    countif(is_before_question) as accepted_before_question,
    sum(failed_checks) as failed_checks,
    count(*) as questions_with_invalid_acceptance,
    countif(failed_checks >= 2) as questions_failing_two_or_more,
    array_agg(if(failed_checks >= 2, question_id, null) ignore nulls) as question_ids_failing_two_or_more
from failed
