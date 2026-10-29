-- The fact must hold exactly one row per staged question: unique() catches duplicates from a
-- join fan-out, this test catches questions lost along the way.
with counts as (
    select
        (select count(*) from {{ ref('stg_questions') }}) as staged_questions,
        (select count(*) from {{ ref('fct_questions') }}) as fact_questions
)

select staged_questions, fact_questions
from counts
where staged_questions != fact_questions
