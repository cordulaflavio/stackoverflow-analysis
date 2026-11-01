-- How much can questions whose asker deleted the account bias community acceptance?
-- fct_questions.is_self_accepted compares the accepted answer's owner with the asker. When the
-- asker deleted the account, owner_user_id is null, the comparison is null, and the question
-- counts as community-accepted even if the asker had accepted their own answer.
-- A deleted account also loses the ownership of its answers, so a self-accepted question of a
-- deleted account has both owners null. That case bounds the misclassification from above.
-- Population: the Q1 population (2022, complete 30-day window).
-- Estimated scan (dry-run): 0.85 GB.
-- Result: 9,868 ownerless questions; 4,327 of them count as community-accepted, but only 275
-- have an accepted answer that is also ownerless. At most 275 of 304,920 community acceptances
-- could be hidden self-acceptances: the 2022 rate is 27.19%, and at least 27.17%.
with questions as (
    select
        question_id,
        owner_user_id,
        is_accepted_within_30d,
        is_self_accepted
    from `stackoverflow-analysis-512922.dbt_dev_marts.fct_questions`
    where creation_year = 2022
        and has_full_30d_window
),

accepted_answer_ids as (
    select
        id as question_id,
        accepted_answer_id
    from `bigquery-public-data.stackoverflow.posts_questions`
    where accepted_answer_id is not null
),

answer_owners as (
    select
        id as answer_id,
        owner_user_id as answer_owner_id
    from `bigquery-public-data.stackoverflow.posts_answers`
),

flagged as (
    select
        questions.owner_user_id is null as is_ownerless,
        questions.is_accepted_within_30d and not questions.is_self_accepted as is_community_accepted,
        -- Both owners missing: the only case where a self-acceptance could hide.
        questions.owner_user_id is null
            and questions.is_accepted_within_30d
            and answer_owners.answer_owner_id is null as could_be_self_accepted
    from questions
    left join accepted_answer_ids
        on questions.question_id = accepted_answer_ids.question_id
    left join answer_owners
        on accepted_answer_ids.accepted_answer_id = answer_owners.answer_id
)

select
    count(*) as questions,
    countif(is_ownerless) as ownerless_questions,
    countif(is_community_accepted) as community_accepted,
    countif(is_ownerless and is_community_accepted) as ownerless_community_accepted,
    countif(could_be_self_accepted) as could_be_self_accepted,
    round(safe_divide(countif(is_community_accepted), count(*)), 4) as community_accepted_rate,
    -- The rate if every could_be_self_accepted question were in fact self-accepted.
    round(safe_divide(countif(is_community_accepted) - countif(could_be_self_accepted), count(*)), 4)
        as community_accepted_rate_lower_bound
from flagged
