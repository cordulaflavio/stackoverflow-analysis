-- Q2: for questions tagged only 'python' or only 'dbt', the year-over-year change of the
-- question-to-answer ratio and of the accepted-answer rate over the last 10 years.
--
-- "Only" = the question has exactly one tag. The last 10 years = 2013 to 2022, the latest
-- years in the dump; 2022 is partial (January to ~2022-08-26, the questions with a full
-- 30-day window). Answers count only if posted within 30 days of the question, so a 2013
-- question has no advantage over a 2022 one in answers. Acceptance follows that rule only in
-- part: the dump has no acceptance date, so a question counts as accepted when its accepted
-- answer was posted within 30 days. The acceptance itself may have happened later, up to the
-- snapshot, so older questions had more time for it (not measured).
-- Every tag has a row for every year, even with no questions: dbt has none before 2020, and
-- its rates stay null in those years instead of showing a misleading 0%.
with questions as (
    select
        tag_combination as tag,
        creation_year,
        answers_within_30d,
        is_answered_within_30d,
        is_accepted_within_30d,
        is_self_accepted
    from {{ ref('fct_questions') }}
    where creation_year between 2013 and 2022
        and has_full_30d_window
        -- With a single tag, the combination is the tag itself.
        and tag_count = 1
        and tag_combination in ('python', 'dbt')
),

tag_years as (
    select
        tag,
        creation_year
    from unnest(['python', 'dbt']) as tag
    cross join unnest(generate_array(2013, 2022)) as creation_year
),

year_metrics as (
    select
        tag,
        creation_year,
        count(*) as total_questions,
        sum(answers_within_30d) as total_answers,
        countif(is_answered_within_30d) as answered_questions,
        countif(is_accepted_within_30d) as accepted_questions,
        countif(is_accepted_within_30d and not is_self_accepted) as community_accepted_questions
    from questions
    group by tag, creation_year
),

year_rates as (
    select
        tag_years.tag,
        tag_years.creation_year,
        tag_years.creation_year = 2022 as is_partial_year,
        coalesce(year_metrics.total_questions, 0) as total_questions,
        coalesce(year_metrics.total_answers, 0) as total_answers,
        coalesce(year_metrics.answered_questions, 0) as answered_questions,
        coalesce(year_metrics.accepted_questions, 0) as accepted_questions,
        coalesce(year_metrics.community_accepted_questions, 0) as community_accepted_questions,
        -- The question's wording: questions per answer. answers_per_question is its inverse,
        -- the metric used in Q1.
        safe_divide(year_metrics.total_questions, year_metrics.total_answers)
            as question_to_answer_ratio,
        safe_divide(year_metrics.total_answers, year_metrics.total_questions)
            as answers_per_question,
        safe_divide(year_metrics.accepted_questions, year_metrics.total_questions) as accepted_rate,
        -- Main acceptance metric, as in Q1: the accepted answer was not written by the asker.
        safe_divide(year_metrics.community_accepted_questions, year_metrics.total_questions)
            as community_accepted_rate
    from tag_years
    left join year_metrics
        on tag_years.tag = year_metrics.tag
        and tag_years.creation_year = year_metrics.creation_year
),

year_over_year as (
    -- Rates change in percentage points; the ratio changes in percent of the previous year.
    -- A change is null when either year has no questions (for dbt, every year up to 2020).
    select
        *,
        (safe_divide(
            question_to_answer_ratio,
            lag(question_to_answer_ratio) over (partition by tag order by creation_year)
        ) - 1) * 100 as question_to_answer_ratio_change_pct,
        (accepted_rate - lag(accepted_rate) over (partition by tag order by creation_year)) * 100
            as accepted_rate_change_pp,
        (
            community_accepted_rate
            - lag(community_accepted_rate) over (partition by tag order by creation_year)
        ) * 100 as community_accepted_rate_change_pp
    from year_rates
),

final as (
    -- Rounded at the end, as in Q1; every rate can be recomputed from the counts.
    select
        tag,
        creation_year,
        is_partial_year,
        total_questions,
        total_answers,
        answered_questions,
        accepted_questions,
        community_accepted_questions,
        round(question_to_answer_ratio, 4) as question_to_answer_ratio,
        round(answers_per_question, 4) as answers_per_question,
        round(accepted_rate, 4) as accepted_rate,
        round(community_accepted_rate, 4) as community_accepted_rate,
        round(question_to_answer_ratio_change_pct, 4) as question_to_answer_ratio_change_pct,
        round(accepted_rate_change_pp, 4) as accepted_rate_change_pp,
        round(community_accepted_rate_change_pp, 4) as community_accepted_rate_change_pp
    from year_over_year
)

select * from final
