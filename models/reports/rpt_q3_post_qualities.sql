-- Q3: which qualities of a post, other than its tags, go with higher answer and community
-- acceptance rates.
--
-- Population: questions created 2013-2022 with a full 30-day window, shown per creation year.
-- 2022 is partial (January to ~2022-08-26) and is exactly the Q1 population.
-- Metrics: the Q1 definitions, counted within the first 30 days. A question counts as accepted
-- when its accepted answer was posted within 30 days; the dump has no acceptance date, so the
-- acceptance itself may have happened later.
-- Only attributes known at posting time. has_owner is left out: an owner can delete the account
-- later, so it describes the snapshot, not the posting.
-- Bucket limits are fixed for every year (set on the 2013-2022 distribution,
-- queries/q3/01_attribute_distributions.sql), so years can be compared bucket by bucket.
with questions as (
    select
        creation_year,
        tag_count,
        tag_combination,
        is_edited,
        body_length,
        title_length,
        asker_account_age_days,
        code_block_count,
        link_count,
        image_count,
        created_hour_utc,
        created_weekday,
        has_error_report,
        title_has_question_mark,
        is_answered_within_30d,
        is_accepted_within_30d,
        is_self_accepted
    from {{ ref('fct_questions') }}
    where creation_year between 2013 and 2022
        and has_full_30d_window
),

-- Robustness segments are subsets of 'all', never mixed into it: a question can appear once in
-- each segment it belongs to.
--   never_edited: last_edited_at is null, so title and body are the posted version (an edit of
--                 the tags alone also counts as an edit).
--   python_only:  exactly one tag, 'python', as in Q2.
question_segments as (
    select
        segment,
        questions.*
    from questions
    cross join unnest(array_concat(
        ['all'],
        if(not questions.is_edited, ['never_edited'], []),
        if(questions.tag_count = 1 and questions.tag_combination = 'python', ['python_only'], [])
    )) as segment
),

-- One row per question, segment and attribute. Each attribute splits the segment into buckets
-- without losing or duplicating a question. No case has an else: a null or out-of-range value
-- gets a null bucket, which the not_null tests catch, instead of landing silently in the last one.
question_buckets as (
    select
        question_segments.segment,
        question_segments.creation_year,
        bucket.attribute,
        bucket.bucket,
        bucket.bucket_order,
        question_segments.is_answered_within_30d,
        question_segments.is_accepted_within_30d,
        question_segments.is_self_accepted
    from question_segments
    cross join unnest([
        struct(
            'body_length' as attribute,
            case
                when body_length < 500 then '<500'
                when body_length < 1000 then '500-999'
                when body_length < 2000 then '1000-1999'
                when body_length < 4000 then '2000-3999'
                when body_length >= 4000 then '4000+'
            end as bucket,
            case
                when body_length < 500 then 1
                when body_length < 1000 then 2
                when body_length < 2000 then 3
                when body_length < 4000 then 4
                when body_length >= 4000 then 5
            end as bucket_order
        ),
        struct(
            'title_length',
            case
                when title_length < 40 then '<40'
                when title_length < 50 then '40-49'
                when title_length < 60 then '50-59'
                when title_length < 75 then '60-74'
                when title_length >= 75 then '75+'
            end,
            case
                when title_length < 40 then 1
                when title_length < 50 then 2
                when title_length < 60 then 3
                when title_length < 75 then 4
                when title_length >= 75 then 5
            end
        ),
        -- 'unknown' is a data limitation, not an asker profile: no owner (deleted account) or an
        -- account that appears to be created after the question.
        struct(
            'asker_account_age_days',
            case
                when asker_account_age_days is null then 'unknown'
                when asker_account_age_days = 0 then '0'
                when asker_account_age_days <= 30 then '1-30'
                when asker_account_age_days <= 365 then '31-365'
                when asker_account_age_days <= 1095 then '366-1095'
                when asker_account_age_days > 1095 then '1096+'
            end,
            case
                when asker_account_age_days is null then 6
                when asker_account_age_days = 0 then 1
                when asker_account_age_days <= 30 then 2
                when asker_account_age_days <= 365 then 3
                when asker_account_age_days <= 1095 then 4
                when asker_account_age_days > 1095 then 5
            end
        ),
        struct(
            'code_block_count',
            if(code_block_count >= 3, '3+', cast(code_block_count as string)),
            least(code_block_count, 3) + 1
        ),
        struct(
            'link_count',
            if(link_count >= 2, '2+', cast(link_count as string)),
            least(link_count, 2) + 1
        ),
        struct(
            'image_count',
            if(image_count >= 2, '2+', cast(image_count as string)),
            least(image_count, 2) + 1
        ),
        -- 5+ holds the few questions with 6 tags (106 in 2013-2022).
        struct(
            'tag_count',
            if(tag_count >= 5, '5+', cast(tag_count as string)),
            least(tag_count, 5)
        ),
        -- UTC, not the asker's local time.
        struct(
            'created_hour_utc',
            case div(created_hour_utc, 6)
                when 0 then '00-05 UTC'
                when 1 then '06-11 UTC'
                when 2 then '12-17 UTC'
                when 3 then '18-23 UTC'
            end,
            div(created_hour_utc, 6) + 1
        ),
        -- UTC day; 1 = Sunday ... 7 = Saturday.
        struct(
            'created_weekday',
            case created_weekday
                when 1 then 'Sunday'
                when 2 then 'Monday'
                when 3 then 'Tuesday'
                when 4 then 'Wednesday'
                when 5 then 'Thursday'
                when 6 then 'Friday'
                when 7 then 'Saturday'
            end,
            created_weekday
        ),
        struct(
            'has_error_report',
            cast(has_error_report as string),
            cast(has_error_report as int64) + 1
        ),
        struct(
            'title_has_question_mark',
            cast(title_has_question_mark as string),
            cast(title_has_question_mark as int64) + 1
        )
    ]) as bucket
),

bucket_metrics as (
    select
        segment,
        creation_year,
        attribute,
        bucket,
        bucket_order,
        count(*) as total_questions,
        countif(is_answered_within_30d) as answered_questions,
        -- Same rule as Q1: the accepted answer was not written by the asker.
        countif(is_accepted_within_30d and not is_self_accepted) as community_accepted_questions
    from question_buckets
    group by segment, creation_year, attribute, bucket, bucket_order
),

final as (
    -- Rounded at the end, as in Q1 and Q2; every rate can be recomputed from the counts.
    select
        segment,
        creation_year,
        creation_year = 2022 as is_partial_year,
        attribute,
        bucket,
        bucket_order,
        total_questions,
        answered_questions,
        community_accepted_questions,
        round(safe_divide(answered_questions, total_questions), 4) as answered_question_rate,
        round(safe_divide(community_accepted_questions, total_questions), 4) as community_accepted_rate
    from bucket_metrics
)

select * from final
