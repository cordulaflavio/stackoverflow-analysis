-- Q1, per tag: which tags get the most / fewest answers and the highest / lowest
-- accepted-answer rate in the current year.
--
-- "Current year" = 2022, the latest year in the dump. Only questions with a full 30-day window
-- are kept (posted up to ~2022-08-26), and every metric counts only what happened in those
-- 30 days, so a question from January has no advantage over one from August.
-- A question counts once for each of its tags: a 'pandas|python' question is in both rows.
-- The metric definitions are the same as in rpt_q1_tag_combinations.

-- The 2022 population: questions with a complete 30-day window, one row each.
with questions as (
    select
        question_id,
        tags,
        answers_within_30d,
        is_answered_within_30d,
        is_accepted_within_30d,
        is_self_accepted,
        hours_to_first_answer
    from {{ ref('fct_questions') }}
    where creation_year = 2022
        and has_full_30d_window
),

-- One row per question and tag, so a question counts once in each of its tags.
question_tags as (
    select
        tag,
        questions.*,
        -- Exact median, so results do not change between runs (approx_quantiles can). BigQuery has
        -- it only as a window function; it skips nulls, which leaves out unanswered questions.
        percentile_cont(
            if(questions.is_answered_within_30d, questions.hours_to_first_answer, null), 0.5
        ) over (partition by tag) as median_hours_to_first_answer
    from questions
    cross join unnest(questions.tags) as tag
),

-- Counts and rates per tag; tags under 500 questions are dropped (see having).
tag_metrics as (
    select
        tag,
        count(*) as total_questions,
        sum(answers_within_30d) as total_answers,
        countif(is_answered_within_30d) as answered_questions,
        countif(not is_answered_within_30d) as unanswered_questions,
        safe_divide(sum(answers_within_30d), count(*)) as answers_per_question,
        safe_divide(countif(is_answered_within_30d), count(*)) as answered_question_rate,
        -- Two acceptance rates: self-accepted answers (about 11% of all acceptances) say more about the
        -- asker than about the community, so the ranking uses the rate without them.
        countif(is_accepted_within_30d) as accepted_questions,
        safe_divide(countif(is_accepted_within_30d), count(*)) as accepted_rate,
        safe_divide(countif(is_accepted_within_30d and not is_self_accepted), count(*))
            as community_accepted_rate,
        -- Splits community_accepted_rate in two steps, getting an answer and getting a solution:
        -- community_accepted_rate = answered_question_rate * community_acceptance_rate_answered.
        safe_divide(
            countif(is_accepted_within_30d and not is_self_accepted), countif(is_answered_within_30d)
        ) as community_acceptance_rate_answered,
        safe_divide(
            countif(is_accepted_within_30d and is_self_accepted), countif(is_accepted_within_30d)
        ) as self_accepted_share,
        -- Same value on every row of the tag (computed in question_tags).
        any_value(median_hours_to_first_answer) as median_hours_to_first_answer
    from question_tags
    group by tag
    -- 500 questions keep the 95% margin of error of a rate at about ±4.3 percentage points at
    -- most (792 tags qualify).
    having count(*) >= 500
),

-- Ranks on the unrounded rates (rounding happens in final).
ranked as (
    select
        tag,
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
    from tag_metrics
),

-- Rounded only after ranking, so rounding cannot create artificial ties. Four decimals are
-- far finer than the margin of error, and every rate can be recomputed from the counts.
final as (
    select
        tag,
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
