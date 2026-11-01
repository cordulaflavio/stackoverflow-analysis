-- Is the code gap only an effect of body length or asker experience?
-- Questions with code also have longer bodies, and their askers may be more experienced, so the
-- one-attribute-at-a-time gap in rpt_q3_post_qualities could come from either. This compares
-- questions with and without a code block inside each body-length bucket, each account-age
-- bucket, and each body-length x account-age cell, then averages the gaps over the strata,
-- weighted by stratum size. If the code gap persists within strata, neither attribute explains it.
-- Population: 2022 with a complete 30-day window (the Q1 and Q3 population), known account age
-- only ('unknown' is a data limitation, as in Q3). Metric: community acceptance within 30 days.
-- Buckets: the same limits as rpt_q3_post_qualities.
-- Estimated scan (dry-run): 0.04 GB.
-- Result: the gap is 12.1 pp without strata, 11.7 pp within account age (11.5 to 11.9 per
-- bucket), 14.3 pp within body length (13.1 to 15.5) and 14.0 pp within the 25 body length x
-- account age cells (10.4 to 18.9). Neither attribute explains it; holding body length fixed
-- makes it larger, since long bodies do worse and code makes bodies longer.
with questions as (
    select
        code_block_count > 0 as has_code,
        case
            when body_length < 500 then '<500'
            when body_length < 1000 then '500-999'
            when body_length < 2000 then '1000-1999'
            when body_length < 4000 then '2000-3999'
            else '4000+'
        end as body_bucket,
        case
            when asker_account_age_days = 0 then '0'
            when asker_account_age_days <= 30 then '1-30'
            when asker_account_age_days <= 365 then '31-365'
            when asker_account_age_days <= 1095 then '366-1095'
            else '1096+'
        end as age_bucket,
        is_accepted_within_30d and not is_self_accepted as is_community_accepted
    from `stackoverflow-analysis-512922.dbt_dev_marts.fct_questions`
    where creation_year = 2022
        and has_full_30d_window
        and asker_account_age_days is not null
),

-- Each question once per stratification: no strata, by body length, by account age, by both.
stratified as (
    select
        stratum.stratum_type,
        stratum.stratum,
        questions.has_code,
        questions.is_community_accepted
    from questions
    cross join unnest([
        struct('none' as stratum_type, 'all' as stratum),
        struct('body_length', questions.body_bucket),
        struct('account_age', questions.age_bucket),
        struct('body_length x account_age', questions.body_bucket || ' / ' || questions.age_bucket)
    ]) as stratum
),

strata as (
    select
        stratum_type,
        stratum,
        countif(not has_code) as questions_without_code,
        countif(has_code) as questions_with_code,
        safe_divide(countif(not has_code and is_community_accepted), countif(not has_code)) as rate_without_code,
        safe_divide(countif(has_code and is_community_accepted), countif(has_code)) as rate_with_code
    from stratified
    group by stratum_type, stratum
),

strata_gaps as (
    select
        *,
        rate_with_code - rate_without_code as gap,
        -- 95% margin of the difference between two independent proportions.
        1.96 * sqrt(
            rate_with_code * (1 - rate_with_code) / questions_with_code
            + rate_without_code * (1 - rate_without_code) / questions_without_code
        ) as gap_margin
    from strata
    -- A stratum needs questions on both sides to have a gap.
    where questions_with_code > 0
        and questions_without_code > 0
),

-- One summary row per stratification: the stratum gaps averaged, weighted by stratum size.
summary as (
    select
        stratum_type,
        count(*) as strata,
        min(gap) as smallest_stratum_gap,
        max(gap) as largest_stratum_gap,
        sum(gap * (questions_with_code + questions_without_code))
            / sum(questions_with_code + questions_without_code) as weighted_gap
    from strata_gaps
    group by stratum_type
),

final as (
    select
        'summary' as row_type,
        stratum_type,
        cast(null as string) as stratum,
        strata,
        cast(null as int64) as questions_without_code,
        cast(null as int64) as questions_with_code,
        cast(null as float64) as rate_without_code,
        cast(null as float64) as rate_with_code,
        round(weighted_gap * 100, 1) as gap_pp,
        cast(null as float64) as gap_margin_pp,
        round(smallest_stratum_gap * 100, 1) as smallest_stratum_gap_pp,
        round(largest_stratum_gap * 100, 1) as largest_stratum_gap_pp
    from summary
    union all
    select
        'stratum',
        stratum_type,
        stratum,
        null,
        questions_without_code,
        questions_with_code,
        round(rate_without_code, 4),
        round(rate_with_code, 4),
        round(gap * 100, 1),
        round(gap_margin * 100, 1),
        null,
        null
    from strata_gaps
    where stratum_type in ('body_length', 'account_age')
)

select * from final
order by row_type desc, stratum_type, stratum
