-- Proof that a combination does not depend on tag order.
-- Estimated scan (dry-run): 0.10 GB.
-- Questions tagged python + pandas may arrive as 'python|pandas' or 'pandas|python' in the
-- source. After sorting, both must land in the same combination, 'pandas|python'.
-- Expected result: one or two source orders, and a single tag_combination.
with two_tag_questions as (
    select
        -- The original order, kept in the tags ARRAY of fct_questions.
        concat(tags[offset(0)], ' then ', tags[offset(1)]) as source_order,
        tag_combination
    from `stackoverflow-analysis-512922.dbt_dev_marts.fct_questions`
    where creation_year = 2022
        and tag_count = 2
        and 'python' in unnest(tags)
        and 'pandas' in unnest(tags)
)

select
    source_order,
    tag_combination,
    count(*) as questions
from two_tag_questions
group by source_order, tag_combination
order by questions desc
