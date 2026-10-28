-- Is the falling answer rate partly survivorship?
-- Stack Overflow automatically deletes old questions that never got an answer and have a
-- low score. Deleted posts are absent from the dump, so older months would keep only the
-- unanswered questions that "survived". If that is happening, two things should show up
-- about one year before the end of the dump (2022-09-25):
--   1. a step down in share_answered, and
--   2. a jump in the share of unanswered questions with score <= 0 (the deletion candidates).
with questions as (
    select
        date_trunc(date(creation_date), month) as creation_month,
        answer_count,
        score
    from `bigquery-public-data.stackoverflow.posts_questions`
    where creation_date >= '2020-01-01'
)

select
    creation_month,
    count(*) as questions,
    round(safe_divide(countif(answer_count > 0), count(*)), 3) as share_answered,
    round(safe_divide(countif(answer_count = 0 and score <= 0), count(*)), 3)
        as share_unanswered_score_le_0,
    round(safe_divide(countif(answer_count = 0 and score > 0), count(*)), 3)
        as share_unanswered_score_gt_0
from questions
group by creation_month
order by creation_month
