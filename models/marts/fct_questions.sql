-- One row per question: the single source of truth for the three analyses.
-- It stores neutral facts only; analytical choices (the "current year", minimum volumes,
-- whether self-accepted answers count) are applied in the report models.
--
-- Clustered, not partitioned, on purpose: in BigQuery sandbox, partitions expire 60 days after
-- their partition date, so a table partitioned by question date (2008-2022) would lose its data.
{{ config(cluster_by=['creation_year']) }}

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

first_answers as (
    select
        question_id,
        min(created_at) as first_answer_at
    from {{ ref('stg_answers') }}
    group by question_id
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
        first_answers.first_answer_at,
        askers.reputation as asker_reputation,
        askers.created_at as asker_created_at,
        -- An acceptance is valid only if the accepted answer exists, answers this question and
        -- was posted after it. Profiling found 332 that fail (230 / 62 / 40).
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
    left join first_answers
        on questions.question_id = first_answers.question_id
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

        -- Tags: the array for per-tag analysis, the original string as the tag combination
        split(tags, '|') as tags,
        tags as tag_combination,
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
