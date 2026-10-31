-- Is every question accepted within 30 days also answered within 30 days?
-- Estimated scan (dry-run): 0.05 GB.
-- The rpt_q1 models rely on the identity
--   community_accepted_rate = answered_question_rate x community_acceptance_rate_answered,
-- which holds only if accepted questions are a subset of answered questions. The acceptance
-- date is approximated by the accepted answer's posting date, so an accepted answer inside
-- the window is also an answer inside the window. Expected result: 0 violations.
-- Checks the whole dump, not only 2022.
select
    countif(is_accepted_within_30d) as accepted_within_30d,
    countif(is_accepted_within_30d and not is_answered_within_30d) as accepted_but_not_answered
from `stackoverflow-analysis-512922.dbt_dev_marts.fct_questions`
