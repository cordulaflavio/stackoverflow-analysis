-- Cross-check the tag parsing: questions per tag counted by splitting posts_questions.tags
-- versus the official count in the tags table. Top 15 tags plus 'dbt'.
-- Estimated scan (dry-run): 0.63 GB.
with parsed as (
    select
        tag_name,
        count(*) as parsed_questions
    from `bigquery-public-data.stackoverflow.posts_questions`,
        unnest(split(tags, '|')) as tag_name
    group by tag_name
),

official as (
    select
        tag_name,
        count as official_count
    from `bigquery-public-data.stackoverflow.tags`
),

compared as (
    select
        parsed.tag_name,
        parsed.parsed_questions,
        official.official_count,
        parsed.parsed_questions - official.official_count as difference,
        row_number() over (order by parsed.parsed_questions desc) as popularity_rank
    from parsed
    left join official
        on parsed.tag_name = official.tag_name
)

select
    popularity_rank,
    tag_name,
    parsed_questions,
    official_count,
    difference
from compared
where popularity_rank <= 15 or tag_name = 'dbt'
order by popularity_rank
