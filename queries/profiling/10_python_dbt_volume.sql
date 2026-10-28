-- Q2 sample size: questions tagged ONLY 'python' or ONLY 'dbt' (the whole tags string is
-- that single tag) per year, next to all questions carrying the tag, to show how much the
-- "only" filter shrinks each sample and how much data backs each year-over-year change.
with questions as (
    select
        extract(year from creation_date) as creation_year,
        tags,
        split(tags, '|') as tag_array
    from `bigquery-public-data.stackoverflow.posts_questions`
)

select
    creation_year,
    countif(tags = 'python') as python_only,
    countif('python' in unnest(tag_array)) as python_any,
    countif(tags = 'dbt') as dbt_only,
    countif('dbt' in unnest(tag_array)) as dbt_any
from questions
group by creation_year
order by creation_year
