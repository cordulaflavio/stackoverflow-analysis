-- Q1, per tag combination: which combinations get the most / fewest answers and the highest /
-- lowest accepted-answer rate in the current year.
--
-- Same population and metric definitions as rpt_q1_tags: 2022 questions with a full 30-day
-- window, metrics counted within those 30 days.
-- A combination is the exact set of a question's tags (2 or more), sorted alphabetically:
-- 'pandas|python' holds only questions tagged exactly pandas and python, not those that add
-- a third tag. Each question belongs to one combination.
with questions as (
    select
        question_id,
        tag_combination,
        tag_count,
        answers_within_30d,
        is_answered_within_30d,
        is_accepted_within_30d,
        is_self_accepted,
        -- Exact median, so results do not change between runs (approx_quantiles can). BigQuery has
        -- it only as a window function; it skips nulls, which leaves out unanswered questions.
        -- Window functions run after the where clause, so only the filtered questions count.
        percentile_cont(
            if(is_answered_within_30d, hours_to_first_answer, null), 0.5
        ) over (partition by tag_combination) as median_hours_to_first_answer
    from {{ ref('fct_questions') }}
    where creation_year = 2022
        and has_full_30d_window
        -- Single-tag questions are covered by rpt_q1_tags.
        and tag_count >= 2
),

combination_metrics as (
    select
        tag_combination,
        any_value(tag_count) as tag_count,
        count(*) as total_questions,
        sum(answers_within_30d) as total_answers,
        countif(is_answered_within_30d) as answered_questions,
        countif(not is_answered_within_30d) as unanswered_questions,
        safe_divide(sum(answers_within_30d), count(*)) as answers_per_question,
        safe_divide(countif(is_answered_within_30d), count(*)) as answered_question_rate,
        countif(is_accepted_within_30d) as accepted_questions,
        safe_divide(countif(is_accepted_within_30d), count(*)) as accepted_rate,
        safe_divide(countif(is_accepted_within_30d and not is_self_accepted), count(*))
            as community_accepted_rate,
        safe_divide(
            countif(is_accepted_within_30d and not is_self_accepted), countif(is_answered_within_30d)
        ) as community_acceptance_rate_answered,
        safe_divide(
            countif(is_accepted_within_30d and is_self_accepted), countif(is_accepted_within_30d)
        ) as self_accepted_share,
        -- Same value on every row of the combination (computed in questions).
        any_value(median_hours_to_first_answer) as median_hours_to_first_answer
    from questions
    group by tag_combination
    -- Combinations are much smaller than tags: 200 questions keep the 95% margin of error of a
    -- rate at about ±6.8 percentage points at most (174 combinations qualify); 500 would leave
    -- only 50.
    having count(*) >= 200
),

ranked as (
    select
        tag_combination,
        tag_count,
        total_questions,
        total_answers,
        answered_questions,
        unanswered_questions,
        answers_per_question,
        answered_question_rate,
        accepted_questions,
        accepted_rate,
        community_accepted_rate,
        community_acceptance_rate_answered,
        self_accepted_share,
        median_hours_to_first_answer,
        rank() over (order by answers_per_question desc) as rank_answers,
        rank() over (order by community_accepted_rate desc) as rank_community_accepted,
        rank() over (order by accepted_rate desc) as rank_if_self_accepted_counted
    from combination_metrics
),

final as (
    -- Rounded only after ranking, so rounding cannot create artificial ties. Four decimals are
    -- far finer than the margin of error, and every rate can be recomputed from the counts.
    select
        tag_combination,
        tag_count,
        total_questions,
        total_answers,
        answered_questions,
        unanswered_questions,
        round(answers_per_question, 4) as answers_per_question,
        round(answered_question_rate, 4) as answered_question_rate,
        accepted_questions,
        round(accepted_rate, 4) as accepted_rate,
        round(community_accepted_rate, 4) as community_accepted_rate,
        round(community_acceptance_rate_answered, 4) as community_acceptance_rate_answered,
        round(self_accepted_share, 4) as self_accepted_share,
        round(median_hours_to_first_answer, 4) as median_hours_to_first_answer,
        rank_answers,
        rank_community_accepted,
        rank_if_self_accepted_counted
    from ranked
)

select * from final
