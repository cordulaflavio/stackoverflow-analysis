-- Do answers carry tags?
-- Estimated scan (dry-run): under 0.01 GB.
-- posts_answers has a tags column, but tags belong to questions on Stack Overflow. If the
-- column is always null, an answer's tags must come from its question (as fct_questions does).
-- Expected result: answers_with_tags = 0.
select
    count(*) as answers,
    countif(tags is not null) as answers_with_tags
from `bigquery-public-data.stackoverflow.posts_answers`
