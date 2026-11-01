-- Format of posts_questions.tags, a '|'-separated string (e.g. 'python|pandas|numpy').
-- Distribution of tags per question, plus malformed segments (empty, padded or uppercase)
-- that would break an exact match such as tags = 'python'.
-- Estimated scan (dry-run): 0.63 GB.
with tag_lists as (
    select split(tags, '|') as tag_array
    from `bigquery-public-data.stackoverflow.posts_questions`
)

select
    array_length(tag_array) as tags_per_question,
    count(*) as questions,
    countif(exists(
        select 1
        from unnest(tag_array) as tag
        where tag = '' or tag != trim(tag) or tag != lower(tag)
    )) as questions_with_malformed_tag
from tag_lists
group by tags_per_question
order by tags_per_question
