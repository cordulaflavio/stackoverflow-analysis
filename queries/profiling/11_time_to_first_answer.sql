-- How long do questions wait for their first answer?
-- If almost all first answers arrive within days, a fixed observation window
-- (e.g. "answered within 30 days") makes recent questions comparable with old ones,
-- neutralising right-censoring at the end of the dump.
with first_answers as (
    select
        parent_id as question_id,
        min(creation_date) as first_answer_at
    from `bigquery-public-data.stackoverflow.posts_answers`
    group by parent_id
),

questions as (
    select
        id as question_id,
        creation_date as question_created_at
    from `bigquery-public-data.stackoverflow.posts_questions`
),

waits as (
    select
        timestamp_diff(first_answers.first_answer_at, questions.question_created_at, minute) / 60
            as hours_to_first_answer
    from questions
    inner join first_answers
        on questions.question_id = first_answers.question_id
)

select
    count(*) as answered_questions,
    countif(hours_to_first_answer < 0) as answered_before_asked,
    approx_quantiles(hours_to_first_answer, 100)[offset(50)] as p50_hours,
    approx_quantiles(hours_to_first_answer, 100)[offset(75)] as p75_hours,
    approx_quantiles(hours_to_first_answer, 100)[offset(90)] as p90_hours,
    approx_quantiles(hours_to_first_answer, 100)[offset(95)] as p95_hours,
    round(safe_divide(countif(hours_to_first_answer <= 24), count(*)), 3) as share_within_1_day,
    round(safe_divide(countif(hours_to_first_answer <= 24 * 7), count(*)), 3) as share_within_7_days,
    round(safe_divide(countif(hours_to_first_answer <= 24 * 30), count(*)), 3) as share_within_30_days,
    round(safe_divide(countif(hours_to_first_answer <= 24 * 365), count(*)), 3) as share_within_1_year
from waits
