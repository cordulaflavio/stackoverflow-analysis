-- Every published number describes the snapshot whose questions end on 2022-09-25.
-- If Google refreshes the public dataset, the results change silently; this test fails
-- so they are rebuilt and re-read instead.
with snapshot_end as (
    select date(max(created_at)) as last_question_date
    from {{ ref('stg_questions') }}
)

select last_question_date
from snapshot_end
where last_question_date != '2022-09-25'
