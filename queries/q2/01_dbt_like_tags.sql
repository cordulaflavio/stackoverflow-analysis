-- Which tags look like dbt, how many questions each has, and the official tag excerpt text.
-- Estimated scan (dry-run): 0.01 GB.
-- Q2 filters on the exact tag 'dbt'. This query shows that it is the data build tool ("Questions
-- relating to dbt (data build tool) set up and usage") and that no other tag refers to it: the
-- other tags containing "dbt" (mdbtools, sqldbtype, dbtype, ...) are unrelated subjects.
with dbt_like_tags as (
    select
        tag_name,
        count as questions,
        excerpt_post_id
    from `bigquery-public-data.stackoverflow.tags`
    where tag_name like '%dbt%'
)

select
    dbt_like_tags.tag_name,
    dbt_like_tags.questions,
    excerpts.body as tag_excerpt
from dbt_like_tags
left join `bigquery-public-data.stackoverflow.posts_tag_wiki_excerpt` as excerpts
    on dbt_like_tags.excerpt_post_id = excerpts.id
order by dbt_like_tags.questions desc
