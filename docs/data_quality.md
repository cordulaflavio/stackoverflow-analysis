# Data quality assessment

Profiling of `bigquery-public-data.stackoverflow` done before any modeling.
Every number below comes from a query in [`queries/profiling/`](../queries/profiling/)
or, where noted, from a dbt test; each profiling query runs as-is in the BigQuery console. Profiling scanned about 10 GB in total.

## Summary

| Area | Finding | Impact |
|---|---|---|
| Coverage | Questions and answers end on **2022-09-25** | 2022 is a partial year |
| Survivorship | Unanswered low-score questions older than ~1 year are missing (auto-deleted) | Answer rates are **not comparable** between questions older and younger than ~1 year |
| Consistency | `answer_count` matches `posts_answers` for 100% of questions; no orphans, no duplicate ids | `answer_count` can be used directly |
| Accepted answers | 332 of 11.8M accepted answers are broken; 11.4% are self-accepted | Negligible errors; self-acceptance is a definition choice |
| Tags | `\|`-separated string, clean; parsing matches the official `tags` table within 0.01% | Exact matches such as `tags = 'python'` are safe |
| dbt sample | Questions tagged only `dbt`: none before 2020, then 31 / 58 / 79 per year | Q2 for dbt rests on very small samples |
| Answer timing | Median time to first answer is 34 minutes; 94.7% of first answers arrive within 30 days | A 30-day window loses little and handles right-censoring |

## Tables and cost
[`01_table_metadata.sql`](../queries/profiling/01_table_metadata.sql) (free: catalog metadata only).

| Table | Rows | Size | Last modified |
|---|---:|---:|---|
| posts_questions | 23.0M | 39.9 GB | 2022-11-24 |
| posts_answers | 34.0M | 30.7 GB | 2022-11-24 |
| users | 18.7M | 3.4 GB | 2022-11-24 |
| badges | 46.1M | 2.1 GB | 2022-11-24 |
| post_links | 8.4M | 0.3 GB | 2022-11-24 |
| post_history | 152.4M | 121.5 GB | 2022-11-25 |
| stackoverflow_posts | 31.0M | 31.5 GB | **2017-07-11** (legacy, not used) |

BigQuery bills by column. Dry-runs per column show that `body` alone is **36.0 GB of the 39.9 GB**
in `posts_questions` (28.4 GB in `posts_answers`); every other column used here costs under 1.3 GB.
`body` is therefore read once, in a single model, and never again.

## Coverage
[`02_questions_by_year.sql`](../queries/profiling/02_questions_by_year.sql),
[`05_answers_integrity.sql`](../queries/profiling/05_answers_integrity.sql)

- Questions: 2008-07-31 → **2022-09-25**. Answers: 2008-07-31 → 2022-09-25.
- 2022 holds about nine months (1.27M questions vs 1.63M in 2021).

## Survivorship: auto-deleted questions
[`02_questions_by_year.sql`](../queries/profiling/02_questions_by_year.sql),
[`12_answer_rate_by_month.sql`](../queries/profiling/12_answer_rate_by_month.sql)

The share of answered questions falls every year, from 99.9% (2008) to 75.8% (2021) and 61.4% (2022).
Part of that is a real trend, but part is an artifact of the dump: Stack Overflow automatically deletes
old questions that never got an answer and have a low score, and deleted posts are not in the dump.

The monthly view shows the cut-off clearly, about one year before the end of the data:

| Month | Answered | Unanswered, score ≤ 0 | Unanswered, score > 0 |
|---|---:|---:|---:|
| 2021-08 | 79.6% | 12.5% | 7.9% |
| 2021-09 | 75.7% | 16.7% | 7.6% |
| 2021-10 | 66.8% | 26.6% | 6.7% |
| 2022-08 | 59.8% | 34.9% | 5.3% |

The jump is confined to unanswered questions with score ≤ 0, the deletion candidates; unanswered questions
with a positive score stay flat. Question volume also rises from October 2021, as expected if those
questions have not been deleted yet. This is consistent with Stack Overflow's automatic cleanup of
abandoned questions; the dump itself cannot prove the mechanism, but the pattern is unambiguous.

**Consequence:** questions created after roughly 2021-09-25 still include future deletions, while older
questions are survivors. Rates computed across that boundary are biased in favour of older periods.

## Consistency between tables
[`03_questions_completeness.sql`](../queries/profiling/03_questions_completeness.sql),
[`04_answer_count_consistency.sql`](../queries/profiling/04_answer_count_consistency.sql),
[`05_answers_integrity.sql`](../queries/profiling/05_answers_integrity.sql),
[`06_accepted_answer_integrity.sql`](../queries/profiling/06_accepted_answer_integrity.sql),
[`07_question_owners.sql`](../queries/profiling/07_question_owners.sql)

| Check | Result |
|---|---|
| Duplicate ids (questions / answers / users) | 0 / 0 / 0 |
| `posts_questions.answer_count` vs. rows in `posts_answers` | Match for all 23,020,127 questions |
| Answers whose parent question is missing | 0 |
| Accepted answer missing from `posts_answers` | 230 |
| Accepted answer belongs to another question | 62 |
| Accepted answer created before its question | 40 |
| Answers created before their question | 507 ² |
| Questions without owner (deleted account) | 457,862 (2.0%) |
| Owner id not found in `users` (questions) | 5 |
| Owner id not found in `users` (answers) | 1 ¹ |
| Owner account created after the question | 32,321 |
| Nulls in `answer_count`, `score`, `view_count`, `comment_count`, `tags` | 0 |
| Null `favorite_count` | 78% (null most likely means zero) |

¹ Measured by the dbt `relationships` test on `stg_answers.owner_user_id`, not by a profiling query.

² These answers are kept: they count in `answers_within_30d` and can mark a question as answered
within 30 days. An accepted answer created before its question, by contrast, makes the acceptance
invalid. The asymmetry was left in place: 507 answers are negligible in a dump of tens of millions,
and aligning the rules would mean rebuilding `fct_questions`. How many fall in each reported tag or
year was not measured.

**A hypothesis that did not hold.** Only the asker can accept an answer, so questions whose owner deleted
their account were expected to show a lower accepted-answer rate. They show a *higher* one
(55.3% vs 51.0%): the answer was presumably accepted before the account was deleted. Ownerless
questions are therefore kept.

**Self-accepted answers.** 11.4% of accepted answers were written by the asker. Whether they count as
"accepted" is a metric-definition choice, made explicitly in the metric definitions.

## Tags
[`08_tags_format.sql`](../queries/profiling/08_tags_format.sql),
[`09_tags_vs_tags_table.sql`](../queries/profiling/09_tags_vs_tags_table.sql)

- `tags` is a `|`-separated string, never empty, with no empty, padded or uppercase segments.
- Tags per question: 1 (2.7M), 2 (6.0M), 3 (6.6M), 4 (4.6M), 5 (3.1M), and **6 for 119 questions**,
  although the site allows at most 5 (legacy data).
- Counts from splitting `tags` match the official `tags` table within 0.01% for the top tags
  (`python`: 2,026,601 vs 2,026,741) and exactly for `dbt` (674).

## Sample size for Q2 (only `python` / only `dbt`)
[`10_python_dbt_volume.sql`](../queries/profiling/10_python_dbt_volume.sql)

| Year | Only `python` | Any `python` | Only `dbt` | Any `dbt` |
|---|---:|---:|---:|---:|
| 2013 | 7,819 | 96,111 | 0 | 0 |
| 2016 | 10,344 | 158,116 | 0 | 0 |
| 2019 | 14,503 | 223,982 | 0 | 3 |
| 2020 | 16,256 | 285,228 | 31 | 96 |
| 2021 | 15,811 | 262,585 | 58 | 224 |
| 2022 (to Sep 25) | 12,809 | 202,689 | 79 | 351 |

`python` has thousands of questions per year. "Only `dbt`" does not exist before 2020: within the last
ten years there are two year-over-year changes for dbt, each based on tens of questions.

## Time to first answer
[`11_time_to_first_answer.sql`](../queries/profiling/11_time_to_first_answer.sql)

| Percentile | Hours |
|---|---:|
| p50 | 0.6 |
| p75 | 6.0 |
| p90 | 94.6 |
| p95 | 893 |

84.4% of answered questions get their first answer within a day, 91.8% within 7 days,
94.7% within 30 days and 98.7% within a year. A fixed observation window (e.g. "answered within
30 days") therefore keeps almost all the signal while making questions of different ages comparable.
