-- Q1 population and 2022 baseline.
-- Estimated scan (dry-run): 0.07 GB.
-- The tag and combination rates only mean something next to the overall rate, so this query
-- gives the reference values cited in docs/question_1.md ("Baseline"):
--   1,121,356 questions, 988,059 with 2+ tags, 583,276 distinct combinations,
--   0.80 answers per question, 60.6% answered, 27.2% community-accepted.
-- Population: same filter as the rpt_q1 models, 2022 questions with a complete 30-day window
-- (created up to ~2022-08-26; the dump ends 2022-09-25), so no question is right-censored.
-- Reads the project's mart (dbt_dev_marts.fct_questions), clustered by creation_year:
-- only the 2022 block is scanned.
select
    count(*) as questions,
    countif(tag_count >= 2) as questions_2plus_tags,
    -- Combinations exist only with 2+ tags; single-tag questions appear only in the tag report.
    count(distinct if(tag_count >= 2, tag_combination, null)) as distinct_combinations,
    round(sum(answers_within_30d) / count(*), 4) as answers_per_question,
    round(countif(is_answered_within_30d) / count(*), 4) as answered_question_rate,
    -- Main acceptance metric: accepted within 30 days, answer written by someone else.
    round(countif(is_accepted_within_30d and not is_self_accepted) / count(*), 4)
        as community_accepted_rate,
    -- Same rate restricted to 2+ tag questions: the baseline for the combinations.
    round(
        safe_divide(
            countif(tag_count >= 2 and is_accepted_within_30d and not is_self_accepted),
            countif(tag_count >= 2)
        ),
        4
    ) as community_accepted_rate_2plus_tags
from `stackoverflow-analysis-512922.dbt_dev_marts.fct_questions`
where creation_year = 2022
    and has_full_30d_window
