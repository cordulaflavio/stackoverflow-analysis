-- How many tags and combinations pass each minimum-volume threshold, and how much they cover.
-- Estimated scan (dry-run): 0.11 GB.
-- Supports the choice of 500 questions per tag and 200 per combination
-- (docs/question_1.md, "Why 200 questions"). A threshold trades coverage for precision:
-- the 95% interval of a rate shrinks with the square root of the number of questions.
-- Population: 2022 questions with a complete 30-day window (same as the rpt_q1 models).
-- Combinations: exact tag set, 2+ tags, sorted alphabetically (fct_questions.tag_combination).
with questions as (
    select
        tags,
        tag_count,
        tag_combination,
        answers_within_30d
    from `stackoverflow-analysis-512922.dbt_dev_marts.fct_questions`
    where creation_year = 2022
        and has_full_30d_window
),

-- A question counts once in each of its tags, as in rpt_q1_tags.
per_tag as (
    select
        tag,
        count(*) as questions
    from questions
    cross join unnest(questions.tags) as tag
    group by tag
),

-- A question counts in exactly one combination, as in rpt_q1_tag_combinations.
per_combination as (
    select
        tag_combination,
        count(*) as questions,
        sum(answers_within_30d) as answers
    from questions
    where tag_count >= 2
    group by tag_combination
),

thresholds as (
    select threshold
    from unnest([100, 200, 500, 1000, 2000]) as threshold
),

tags_by_threshold as (
    select
        thresholds.threshold,
        countif(per_tag.questions >= thresholds.threshold) as tags
    from thresholds
    cross join per_tag
    group by thresholds.threshold
),

combinations_by_threshold as (
    select
        thresholds.threshold,
        countif(per_combination.questions >= thresholds.threshold) as combinations,
        sum(if(per_combination.questions >= thresholds.threshold, per_combination.questions, 0))
            as questions_covered,
        sum(if(per_combination.questions >= thresholds.threshold, per_combination.answers, 0))
            as answers_covered,
        -- Share of all questions with 2+ tags that the reported combinations describe.
        round(
            safe_divide(
                sum(if(per_combination.questions >= thresholds.threshold, per_combination.questions, 0)),
                sum(per_combination.questions)
            ),
            4
        ) as share_of_2plus_tag_questions
    from thresholds
    cross join per_combination
    group by thresholds.threshold
),

final as (
    select
        tags_by_threshold.threshold,
        tags_by_threshold.tags,
        combinations_by_threshold.combinations,
        combinations_by_threshold.questions_covered,
        combinations_by_threshold.answers_covered,
        combinations_by_threshold.share_of_2plus_tag_questions
    from tags_by_threshold
    inner join combinations_by_threshold
        on tags_by_threshold.threshold = combinations_by_threshold.threshold
)

select *
from final
order by threshold
