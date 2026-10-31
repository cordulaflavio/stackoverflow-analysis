-- Combination frequency gradient, and the rare-tag control.
-- Estimated scan (dry-run): 0.11 GB.
-- Source of tables A, B (first five rows) and the question counts in docs/question_1.md,
-- "Combination frequency gradient".
--
-- Frequency of a combination = number of questions in the population with exactly that tag
-- set. Each question falls into one band (200+, 20-199, 2-19, unique), so the bands add up to
-- all 988,059 questions with 2+ tags.
--
-- Control: a unique combination often contains a rare tag, so the gradient could just reflect
-- rare tags. The control keeps only questions whose tags ALL belong to rpt_q1_tags (the 792
-- tags with 500+ questions). A combination fixes the tag set, so the filter keeps or drops
-- whole combinations and the frequency of a kept combination does not change.
--
-- Population and metric are the same as the rpt_q1 models: 2022, complete 30-day window,
-- community acceptance (accepted within 30 days, answer not written by the asker).
with frequent_tags as (
    select tag
    from `stackoverflow-analysis-512922.dbt_dev_reports.rpt_q1_tags`
),

questions as (
    select
        question_id,
        tags,
        tag_count,
        tag_combination,
        is_accepted_within_30d and not is_self_accepted as is_community_accepted
    from `stackoverflow-analysis-512922.dbt_dev_marts.fct_questions`
    where creation_year = 2022
        and has_full_30d_window
        and tag_count >= 2
),

questions_with_rare_tag as (
    select distinct questions.question_id
    from questions
    cross join unnest(questions.tags) as tag
    left join frequent_tags
        on tag = frequent_tags.tag
    where frequent_tags.tag is null
),

classified as (
    select
        questions.question_id,
        questions.tag_count,
        questions.is_community_accepted,
        questions_with_rare_tag.question_id is null as has_only_frequent_tags,
        -- The window runs over the whole population, before any control filter, so the
        -- band of a combination is the same in every row of the result.
        case
            when count(*) over (partition by questions.tag_combination) >= 200 then 'a) 200+'
            when count(*) over (partition by questions.tag_combination) >= 20 then 'b) 20-199'
            when count(*) over (partition by questions.tag_combination) >= 2 then 'c) 2-19'
            else 'd) unique'
        end as combination_size
    from questions
    left join questions_with_rare_tag
        on questions.question_id = questions_with_rare_tag.question_id
),

results as (
    -- Table A: the full 2+ tag population.
    select
        'all 2+ tag questions' as population,
        'all' as tag_count,
        combination_size,
        count(*) as questions,
        countif(is_community_accepted) as community_accepted_questions
    from classified
    group by combination_size

    union all

    -- Table B: only frequent tags, all tag counts together.
    select
        'only frequent tags',
        'all',
        combination_size,
        count(*),
        countif(is_community_accepted)
    from classified
    where has_only_frequent_tags
    group by combination_size

    union all

    -- Table B: only frequent tags, one row per tag count. More tags make a combination
    -- rarer, so comparing bands within a tag count removes that confounder.
    select
        'only frequent tags',
        cast(tag_count as string),
        combination_size,
        count(*),
        countif(is_community_accepted)
    from classified
    where has_only_frequent_tags
    group by tag_count, combination_size
),

final as (
    select
        population,
        tag_count,
        combination_size,
        questions,
        community_accepted_questions,
        round(safe_divide(community_accepted_questions, questions), 4) as community_accepted_rate
    from results
)

select *
from final
order by population, tag_count, combination_size
