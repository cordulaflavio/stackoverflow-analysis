-- rpt_q3_post_qualities: every attribute must split its segment and year into buckets without
-- losing or duplicating a question, and each segment must match an independent count.
-- Returns one row per failing segment and year:
--   1. the attributes do not all add up to the same number of questions;
--   2. 'all' differs from fct_questions with the same filter (2022 is the Q1 population);
--   3. 'python_only' differs from rpt_q2_python_dbt_by_year, built separately;
--   4. 'never_edited' is larger than 'all'.
with attribute_totals as (
    select
        segment,
        creation_year,
        attribute,
        sum(total_questions) as attribute_questions
    from {{ ref('rpt_q3_post_qualities') }}
    group by segment, creation_year, attribute
),

segment_totals as (
    select
        segment,
        creation_year,
        min(attribute_questions) as min_questions,
        max(attribute_questions) as max_questions
    from attribute_totals
    group by segment, creation_year
),

fct_population as (
    select
        creation_year,
        count(*) as questions
    from {{ ref('fct_questions') }}
    where creation_year between 2013 and 2022
        and has_full_30d_window
    group by creation_year
),

-- Same population as python_only: rpt_q2 keeps creation years 2013-2022, has_full_30d_window,
-- tag_count = 1 and tag_combination = 'python', from the same fct_questions.
q2_python as (
    select
        creation_year,
        total_questions as questions
    from {{ ref('rpt_q2_python_dbt_by_year') }}
    where tag = 'python'
),

checks as (
    select
        segment_totals.segment,
        segment_totals.creation_year,
        segment_totals.min_questions,
        segment_totals.max_questions,
        case segment_totals.segment
            when 'all' then fct_population.questions
            when 'python_only' then q2_python.questions
        end as expected_questions,
        all_segment.max_questions as all_questions
    from segment_totals
    left join fct_population
        on segment_totals.creation_year = fct_population.creation_year
    left join q2_python
        on segment_totals.creation_year = q2_python.creation_year
    left join segment_totals as all_segment
        on segment_totals.creation_year = all_segment.creation_year
        and all_segment.segment = 'all'
),

-- A year present in the fact but missing from the report fails too.
missing_years as (
    select
        'all' as segment,
        fct_population.creation_year,
        cast(null as int64) as min_questions,
        cast(null as int64) as max_questions,
        fct_population.questions as expected_questions,
        cast(null as int64) as all_questions
    from fct_population
    left join segment_totals
        on fct_population.creation_year = segment_totals.creation_year
        and segment_totals.segment = 'all'
    where segment_totals.creation_year is null
)

select *
from checks
where min_questions != max_questions
    or (segment in ('all', 'python_only') and max_questions is distinct from expected_questions)
    or (segment = 'never_edited' and max_questions > all_questions)
union all
select *
from missing_years
