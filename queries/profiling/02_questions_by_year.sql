-- Question volume and raw outcome rates per year.
-- Shows the coverage window (first and last question) and whether any year is partial,
-- which decides what "current year" (Q1) and "last 10 years" (Q2) can mean.
-- Estimated scan (dry-run): 0.46 GB.
with questions as (
    select
        extract(year from creation_date) as creation_year,
        creation_date,
        answer_count,
        accepted_answer_id
    from `bigquery-public-data.stackoverflow.posts_questions`
)

select
    creation_year,
    count(*) as questions,
    min(creation_date) as first_question_at,
    max(creation_date) as last_question_at,
    round(safe_divide(countif(answer_count > 0), count(*)), 3) as share_answered,
    round(safe_divide(countif(accepted_answer_id is not null), count(*)), 3) as share_accepted
from questions
group by creation_year
order by creation_year
