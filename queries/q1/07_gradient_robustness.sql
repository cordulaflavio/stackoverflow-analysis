-- Does the combination frequency gradient survive two confounders?
-- Estimated scan (dry-run): 0.06 GB.
-- Source of the "Never-edited" and "Edited" rows of table B in docs/question_1.md.
--   1. Tag count: unique combinations tend to have more tags. Cut "by tag_count" (full
--      population, rare tags included; the frequent-tags version is in 06).
--   2. Editing: tags are the CURRENT ones. Editors could move answered questions into common
--      tag sets, which would create the gradient after the fact. In never-edited questions
--      the tags are the ones chosen at posting time.
-- Same population, bands and metric as 06.
with combinations as (
    select
        tag_count,
        is_edited,
        count(*) over (partition by tag_combination) as combination_questions,
        is_accepted_within_30d and not is_self_accepted as is_community_accepted
    from `stackoverflow-analysis-512922.dbt_dev_marts.fct_questions`
    where creation_year = 2022
        and has_full_30d_window
        and tag_count >= 2
),

banded as (
    select
        case
            when combination_questions >= 200 then 'a) 200+'
            when combination_questions >= 20 then 'b) 20-199'
            when combination_questions >= 2 then 'c) 2-19'
            else 'd) unique'
        end as combination_size,
        tag_count,
        is_edited,
        is_community_accepted
    from combinations
),

results as (
    select
        'by tag_count' as cut,
        cast(tag_count as string) as stratum,
        combination_size,
        count(*) as questions,
        countif(is_community_accepted) as community_accepted_questions
    from banded
    group by tag_count, combination_size

    union all

    select
        'by edited',
        cast(is_edited as string),
        combination_size,
        count(*),
        countif(is_community_accepted)
    from banded
    group by is_edited, combination_size
),

final as (
    select
        cut,
        stratum,
        combination_size,
        questions,
        community_accepted_questions,
        round(safe_divide(community_accepted_questions, questions), 4) as community_accepted_rate
    from results
)

select *
from final
order by cut, stratum, combination_size
