-- One row per question: the single source of truth for the three analyses.
-- It stores neutral facts only; analytical choices (the "current year", minimum volumes,
-- whether self-accepted answers count) are applied in the report models.
--
-- Clustered by creation_year, not partitioned. A filter on creation_year lets BigQuery skip the
-- blocks of other years: the 2022 report rpt_q1_tags is billed about 0.07 GB.
-- Partitioning does not pay off at this size. The table is 5.5 GB, about 0.4 GB per year on
-- average, and BigQuery suggests clustering instead when partitions would hold less than
-- approximately 10 GB. Partitioning by question date would also fail in the sandbox: partitions
-- expire 60 days after their partition boundary, so every partition from 2008 to 2022 would
-- expire immediately. Integer-range partitioning has no expiration, but no benefit here either.
-- Sandbox storage is also capped at 10 GB: a rebuild would hold the old and the new table at
-- once, so the old one is dropped first.
{{ config(cluster_by=['creation_year'], pre_hook="drop table if exists {{ this }}") }}

with questions as (
    select
        question_id,
        title,
        tags,
        created_at,
        owner_user_id,
        accepted_answer_id,
        answer_count,
        score,
        view_count,
        comment_count,
        favorite_count,
        last_edited_at
    from {{ ref('stg_questions') }}
),

answer_stats as (
    select
        answers.question_id,
        min(answers.created_at) as first_answer_at,
        -- Answers keep arriving until the snapshot, so answer_count favours older questions;
        -- counting only the first 30 days gives every question the same window.
        countif(answers.created_at < timestamp_add(questions.created_at, interval 30 day))
            as answers_within_30d
    from {{ ref('stg_answers') }} as answers
    inner join questions
        on answers.question_id = questions.question_id
    group by answers.question_id
),

accepted_answers as (
    select
        answer_id,
        question_id,
        owner_user_id,
        created_at
    from {{ ref('stg_answers') }}
),

askers as (
    select
        user_id,
        reputation,
        created_at
    from {{ ref('stg_users') }}
),

body_features as (
    select
        question_id,
        body_length,
        code_block_count,
        link_count,
        image_count,
        has_error_report
    from {{ ref('stg_question_body_features') }}
),

snapshot_end as (
    -- Last question in the dump; questions closer than 30 days to it had a shorter window.
    select max(created_at) as snapshot_end_at
    from questions
),

questions_enriched as (
    select
        questions.*,
        answer_stats.first_answer_at,
        coalesce(answer_stats.answers_within_30d, 0) as answers_within_30d,
        askers.reputation as asker_reputation,
        askers.created_at as asker_created_at,
        -- An acceptance is valid only if the accepted answer exists, answers this question and
        -- was posted after it. Profiling found 331 questions that fail (230 / 62 / 40 failed checks; one question fails two).
        accepted_answers.answer_id is not null
            and accepted_answers.question_id = questions.question_id
            and accepted_answers.created_at >= questions.created_at
            as is_valid_acceptance,
        accepted_answers.owner_user_id as accepted_answer_owner_id,
        accepted_answers.created_at as accepted_answer_created_at_raw,
        snapshot_end.snapshot_end_at,
        body_features.body_length,
        body_features.code_block_count,
        body_features.link_count,
        body_features.image_count,
        body_features.has_error_report
    from questions
    cross join snapshot_end
    left join answer_stats
        on questions.question_id = answer_stats.question_id
    left join accepted_answers
        on questions.accepted_answer_id = accepted_answers.answer_id
    left join askers
        on questions.owner_user_id = askers.user_id
    left join body_features
        on questions.question_id = body_features.question_id
),

final as (
    select
        -- Identification and posting time (UTC, not the asker's local time)
        question_id,
        created_at,
        extract(year from created_at) as creation_year,
        extract(hour from created_at) as created_hour_utc,
        -- 1 = Sunday ... 7 = Saturday
        extract(dayofweek from created_at) as created_weekday,

        -- Tags: the array keeps the source order and serves per-tag analysis. The combination
        -- sorts the tags alphabetically: the source order is not alphabetical and the same set
        -- of tags can appear in different orders, so 'python|pandas' and 'pandas|python' would
        -- otherwise count as two different combinations.
        split(tags, '|') as tags,
        array_to_string(
            array(select tag from unnest(split(tags, '|')) as tag order by tag), '|'
        ) as tag_combination,
        array_length(split(tags, '|')) as tag_count,

        -- Title (latest version)
        length(title) as title_length,
        strpos(title, '?') > 0 as title_has_question_mark,

        -- Body features (latest version of the body)
        body_length,
        code_block_count,
        link_count,
        image_count,
        has_error_report,

        -- Asker
        owner_user_id,
        owner_user_id is not null as has_owner,
        -- Known at posting time. Null when the account appears to be created after the question
        -- (32,321 questions in profiling), which makes the age meaningless.
        case
            when asker_created_at <= created_at
                then date_diff(date(created_at), date(asker_created_at), day)
        end as asker_account_age_days,
        -- Snapshot value: includes reputation earned after the question.
        asker_reputation,

        -- Answers
        answer_count,
        answer_count > 0 as is_answered,
        answers_within_30d,
        first_answer_at,
        timestamp_diff(first_answer_at, created_at, minute) / 60 as hours_to_first_answer,
        coalesce(first_answer_at < timestamp_add(created_at, interval 30 day), false)
            as is_answered_within_30d,

        -- Acceptance. The dump has no acceptance date, so the accepted answer's creation date
        -- is used as a proxy (the acceptance itself can only come later).
        coalesce(is_valid_acceptance, false) as has_accepted_answer,
        accepted_answer_id is not null and not coalesce(is_valid_acceptance, false)
            as has_invalid_accepted_answer,
        if(is_valid_acceptance, accepted_answer_created_at_raw, null) as accepted_answer_created_at,
        coalesce(is_valid_acceptance and accepted_answer_owner_id = owner_user_id, false)
            as is_self_accepted,
        coalesce(
            is_valid_acceptance
            and accepted_answer_created_at_raw < timestamp_add(created_at, interval 30 day),
            false
        ) as is_accepted_within_30d,

        -- Right-censoring: true when the dump covers the full 30 days after posting.
        timestamp_add(created_at, interval 30 day) <= snapshot_end_at as has_full_30d_window,

        -- Snapshot metrics: observed after posting, partly caused by the answers themselves.
        score,
        view_count,
        comment_count,
        favorite_count,
        last_edited_at is not null as is_edited
    from questions_enriched
)

select * from final
