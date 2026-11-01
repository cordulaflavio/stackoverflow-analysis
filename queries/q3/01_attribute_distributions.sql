-- Q3: distribution of the post attributes, to set fixed bucket limits before building the report.
-- Estimated scan (dry-run): 1.60 GB (billed 1.60 GB on 2026-10-31; clustering on creation_year skips 2008-2012).
-- Descriptive only: no answer or acceptance metric is computed here.
-- Population: questions created 2013-2022 with a complete 30-day window, the Q3 population.
-- Bucket limits must be the same for every year, so they are set once on the pooled 2013-2022
-- population; scope '2022' repeats the same statistics for 2022 alone, to check whether the
-- most recent year (and the Q1 population) is distributed differently.
-- Output, one row per statistic:
--   kind = 'summary':    min, max, distinct values, nulls and zeros of the continuous attributes;
--   kind = 'percentile': p0, p5, ..., p100 of the continuous attributes (approx_quantiles, whose
--                        error is small at these volumes; good enough to choose round limits);
--   kind = 'value':      questions and share for each value of the discrete attributes and flags.
--                        Nulls are reported as the value 'null', never dropped.
--   kind = 'domain':     questions outside the expected domain of hour (0-23), weekday (1-7)
--                        and tag count (1-5; the site allows at most 5 tags, so the 119
--                        questions with 6 are expected to show here). Nulls count as outside.
with questions as (
    select
        creation_year,
        body_length,
        title_length,
        asker_account_age_days,
        code_block_count,
        link_count,
        image_count,
        has_error_report,
        title_has_question_mark,
        has_owner,
        created_hour_utc,
        created_weekday,
        tag_count
    from `stackoverflow-analysis-512922.dbt_dev_marts.fct_questions`
    where creation_year between 2013 and 2022
        and has_full_30d_window
),

-- Every question counts in the pooled scope; 2022 questions also count in their own scope.
scoped as (
    select
        scope,
        questions.*
    from questions
    cross join unnest(
        if(questions.creation_year = 2022, ['2013-2022', '2022'], ['2013-2022'])
    ) as scope
),

-- Continuous attributes: summary statistics and 21 cut points (every 5%) in one aggregation.
-- approx_quantiles ignores nulls; the null count is reported next to it.
continuous_stats as (
    select
        scope,
        count(*) as scope_questions,
        [
            struct(
                'body_length' as attribute,
                min(body_length) as min_value,
                max(body_length) as max_value,
                count(distinct body_length) as distinct_values,
                countif(body_length is null) as null_questions,
                countif(body_length = 0) as zero_questions,
                approx_quantiles(body_length, 20) as cut_points
            ),
            struct(
                'title_length',
                min(title_length),
                max(title_length),
                count(distinct title_length),
                countif(title_length is null),
                countif(title_length = 0),
                approx_quantiles(title_length, 20)
            ),
            -- Null when the question has no owner or the account appears to be created after it.
            struct(
                'asker_account_age_days',
                min(asker_account_age_days),
                max(asker_account_age_days),
                count(distinct asker_account_age_days),
                countif(asker_account_age_days is null),
                countif(asker_account_age_days = 0),
                approx_quantiles(asker_account_age_days, 20)
            )
        ] as stats
    from scoped
    group by scope
),

summary_rows as (
    select
        continuous_stats.scope,
        stat.attribute,
        'summary' as kind,
        summary.label,
        summary.stat_value,
        summary.questions,
        round(safe_divide(summary.questions, continuous_stats.scope_questions), 4) as share,
        summary.sort_key
    from continuous_stats
    cross join unnest(continuous_stats.stats) as stat
    cross join unnest([
        struct('min' as label, cast(stat.min_value as float64) as stat_value, cast(null as int64) as questions, 1 as sort_key),
        struct('max', cast(stat.max_value as float64), null, 2),
        struct('distinct_values', cast(stat.distinct_values as float64), null, 3),
        struct('nulls', null, stat.null_questions, 4),
        struct('zeros', null, stat.zero_questions, 5)
    ]) as summary
),

percentile_rows as (
    select
        continuous_stats.scope,
        stat.attribute,
        'percentile' as kind,
        concat('p', cast(position * 5 as string)) as label,
        cast(cut_point as float64) as stat_value,
        cast(null as int64) as questions,
        cast(null as float64) as share,
        position as sort_key
    from continuous_stats
    cross join unnest(continuous_stats.stats) as stat
    cross join unnest(stat.cut_points) as cut_point with offset as position
),

-- Discrete attributes and flags, one (attribute, value) pair per question and attribute.
-- Code blocks, links and images of 10 or more are grouped as '10+': the frequencies only need
-- to show where the tail starts. Hour, weekday and tag count keep their raw values, so values
-- outside the expected domain stay visible.
value_counts as (
    select
        scope,
        pair.attribute,
        pair.label,
        pair.sort_key,
        count(*) as questions,
        countif(pair.out_of_domain) as out_of_domain_questions
    from scoped
    cross join unnest([
        struct(
            'code_block_count' as attribute,
            case
                when code_block_count is null then 'null'
                when code_block_count >= 10 then '10+'
                else cast(code_block_count as string)
            end as label,
            coalesce(least(code_block_count, 10), -1) as sort_key,
            false as out_of_domain
        ),
        struct(
            'link_count',
            case
                when link_count is null then 'null'
                when link_count >= 10 then '10+'
                else cast(link_count as string)
            end,
            coalesce(least(link_count, 10), -1),
            false
        ),
        struct(
            'image_count',
            case
                when image_count is null then 'null'
                when image_count >= 10 then '10+'
                else cast(image_count as string)
            end,
            coalesce(least(image_count, 10), -1),
            false
        ),
        struct(
            'has_error_report',
            coalesce(cast(has_error_report as string), 'null'),
            coalesce(cast(has_error_report as int64), -1),
            false
        ),
        struct(
            'title_has_question_mark',
            coalesce(cast(title_has_question_mark as string), 'null'),
            coalesce(cast(title_has_question_mark as int64), -1),
            false
        ),
        struct(
            'has_owner',
            coalesce(cast(has_owner as string), 'null'),
            coalesce(cast(has_owner as int64), -1),
            false
        ),
        struct(
            'created_hour_utc',
            coalesce(cast(created_hour_utc as string), 'null'),
            coalesce(created_hour_utc, -1),
            coalesce(created_hour_utc not between 0 and 23, true)
        ),
        -- 1 = Sunday ... 7 = Saturday
        struct(
            'created_weekday',
            coalesce(cast(created_weekday as string), 'null'),
            coalesce(created_weekday, -1),
            coalesce(created_weekday not between 1 and 7, true)
        ),
        struct(
            'tag_count',
            coalesce(cast(tag_count as string), 'null'),
            coalesce(tag_count, -1),
            coalesce(tag_count not between 1 and 5, true)
        )
    ]) as pair
    group by scope, pair.attribute, pair.label, pair.sort_key
),

scope_totals as (
    select
        scope,
        scope_questions
    from continuous_stats
),

value_rows as (
    select
        value_counts.scope,
        value_counts.attribute,
        'value' as kind,
        value_counts.label,
        cast(null as float64) as stat_value,
        value_counts.questions,
        round(safe_divide(value_counts.questions, scope_totals.scope_questions), 4) as share,
        value_counts.sort_key
    from value_counts
    inner join scope_totals
        on value_counts.scope = scope_totals.scope
),

-- One row per attribute with a domain: questions outside it (0 when every value is valid).
domain_rows as (
    select
        value_counts.scope,
        value_counts.attribute,
        'domain' as kind,
        'out_of_domain' as label,
        cast(null as float64) as stat_value,
        sum(value_counts.out_of_domain_questions) as questions,
        round(
            safe_divide(sum(value_counts.out_of_domain_questions), any_value(scope_totals.scope_questions)), 4
        ) as share,
        0 as sort_key
    from value_counts
    inner join scope_totals
        on value_counts.scope = scope_totals.scope
    where value_counts.attribute in ('created_hour_utc', 'created_weekday', 'tag_count')
    group by value_counts.scope, value_counts.attribute
),

final as (
    select * from summary_rows
    union all
    select * from percentile_rows
    union all
    select * from value_rows
    union all
    select * from domain_rows
)

select
    scope,
    attribute,
    kind,
    label,
    stat_value,
    questions,
    share
from final
order by scope, attribute, kind, sort_key
