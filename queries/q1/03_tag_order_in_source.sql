-- Is the tag order in the source stable enough to use the raw string as the combination key?
-- Estimated scan (dry-run): 0.82 GB.
-- posts_questions.tags is a '|'-separated string. Its order is not alphabetical, and the same
-- set of tags can appear in different orders. Grouping by the raw string would then split one
-- combination in two. Comparing distinct raw strings with distinct sorted strings shows how often that
-- happens. Finding: few merges in 2022, many in earlier years. This is why
-- fct_questions.tag_combination is sorted alphabetically, which also matters for Q2 (10 years).
-- Reads the source directly (tags and creation_date columns only).
with questions as (
    select
        extract(year from creation_date) as creation_year,
        tags as raw_combination,
        array_to_string(
            array(select tag from unnest(split(tags, '|')) as tag order by tag),
            '|'
        ) as sorted_combination
    from `bigquery-public-data.stackoverflow.posts_questions`
)

select
    creation_year = 2022 as is_2022,
    count(distinct raw_combination) as distinct_raw,
    -- distinct_raw - distinct_sorted = combinations that sorting merges.
    count(distinct sorted_combination) as distinct_sorted,
    countif(raw_combination != sorted_combination) as questions_not_alphabetical
from questions
group by is_2022
order by is_2022
