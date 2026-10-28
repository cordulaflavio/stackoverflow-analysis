-- Does posts_questions.answer_count match the answers actually present in posts_answers?
-- A mismatch means the denormalized counter and the answers table disagree (e.g. deleted
-- answers), which decides which source the "answers per question" metric should use.
with answers_per_question as (
    select
        parent_id as question_id,
        count(*) as actual_answers
    from `bigquery-public-data.stackoverflow.posts_answers`
    group by parent_id
),

questions as (
    select
        id as question_id,
        answer_count as declared_answers
    from `bigquery-public-data.stackoverflow.posts_questions`
),

compared as (
    select
        questions.question_id,
        questions.declared_answers,
        coalesce(answers_per_question.actual_answers, 0) as actual_answers
    from questions
    left join answers_per_question
        on questions.question_id = answers_per_question.question_id
)

select
    case
        when declared_answers = actual_answers then 'match'
        when declared_answers > actual_answers then 'declared > actual'
        else 'declared < actual'
    end as comparison,
    count(*) as questions,
    sum(declared_answers - actual_answers) as net_difference
from compared
group by comparison
order by questions desc
