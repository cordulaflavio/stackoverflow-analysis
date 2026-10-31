# Project structure

How data flows from the public source to the answers, and why each layer exists.

## Overview

```
bigquery-public-data.stackoverflow     (source, read-only)
        │
        ▼  0. Ingestion: none (read in place)
        ▼  1. Profiling: queries/profiling/01–13 → docs/data_quality.md
        ▼
  stg_*  (views)                        models/staging/
        ▼
  fct_questions  (table)                models/marts/
        ▼
  rpt_q1_*  (tables)                    models/reports/
        ▼
  results/*.csv  →  docs/question_1.md  (the analysis reads the reports)
```

## 0. Ingestion: none

- **What:** dbt reads `bigquery-public-data.stackoverflow` in place, declared in
  `models/staging/sources.yml`.
- **Why:** the data is public and static. A copy would use a large part of the 10 GB sandbox
  storage and add nothing.
- **No freshness check.** The snapshot never changes. Instead, the singular test
  `tests/assert_source_snapshot_unchanged.sql` fails if the last question is no longer dated
  2022-09-25, which would mean the dataset was refreshed.

## 1. Profiling and Exploratory Data Analysis (EDA), before modeling

- **What:** 13 queries in `queries/profiling/`, with the findings in `docs/data_quality.md`.
- **Findings that became decisions:**
  - **The data ends on 2022-09-25**, so 2022 is a partial year.
  - **332 invalid acceptances:**
    - 230 point to an answer that does not exist;
    - 62 point to an answer of another question;
    - 40 point to an answer posted before the question.

    These cases define the "valid acceptance" rule.
  - **94.7% of first answers arrive within 30 days.** This justifies the 30-day window.
  - **Survivorship bias.** Unanswered questions with a score ≤ 0 are automatically deleted after
    about one year, and deleted posts are not in the dump.
    - **Evidence:** among questions created after September 2021, which were not yet one year old,
      the share of this group jumps from 12.5% to 26.6%. This is consistent with the Roomba
      deletion rule.
    - **Why 2022 helps:** using only 2022 questions avoids the one-year rule.
    - **What remains:** shorter deletion rules still apply to 2022 questions:
      - unanswered questions with a negative score are deleted after 30 days;
      - closed questions (not as duplicates) with a score ≤ 0 and no positively scored or
        accepted answer are deleted 9 days after closure.

      Both remove questions that failed, so the remaining data contains proportionally more
      answered and accepted questions, and the rates look higher than they actually were.
  - **`body` is 36 of the 40 GB of `posts_questions`.** It is read only once.

## 2. Staging: four models

Rename, cast and keep only the columns needed. No business logic. Views cost no storage.

| Model | What it does | Why |
|---|---|---|
| `stg_questions` | id → question_id, tags, dates, counters | no `body`, the expensive column |
| `stg_answers` | answer_id, question_id (parent_id), owner, date | to count answers within 30 days and detect self-acceptance |
| `stg_users` | reputation, account creation date | for Q3 (account age) |
| `stg_question_body_features` | the only model that reads `body`; a **table** | reads 36 GB **once** and stores five numbers per question (length, code blocks, links, images, error report), used by Q3 |

Tests: `unique` + `not_null` on keys, and `relationships` on foreign keys. Relationships use
`severity: warn`, because the dump has known, documented orphans.

## 3. Mart: `fct_questions`, one row per question

The single source of truth for the three questions.

**Central principle: the fact table stores neutral facts, not analytical choices.**
- A fact: whether a question was answered within 30 days, or whether an acceptance was a
  self-acceptance.
- A choice: the "current year", the minimum volume, or whether self-acceptance counts. Choices
  belong in the report models.

**Columns used by Q1**

| Column | Rule | Why |
|---|---|---|
| `tags` (array) | `split(tags, '\|')`, source order kept | a question counts in each of its tags |
| `tag_combination` | tags **sorted** alphabetically | the source order is not alphabetical and can vary, so python\|pandas and pandas\|python must become the same combination |
| `answers_within_30d` | answers posted within 30 days | `answer_count` favours older questions, which had more time |
| `is_answered_within_30d` | first answer within 30 days | the same window for every question |
| `has_accepted_answer` | the accepted answer exists, belongs to this question and was posted after it | excludes the 332 invalid acceptances |
| `is_self_accepted` | the accepted answer's owner is the asker | separates community help from self-help |
| `is_accepted_within_30d` | a valid acceptance of an answer posted within 30 days | the dump has no acceptance date; the answer date is the proxy |
| `has_full_30d_window` | posting date + 30 days falls before the end of the dump | right-censoring |

**Technical decisions**
- **Clustered by `creation_year`, not partitioned.**
  - **What clustering does:** a filter on `creation_year` lets BigQuery skip the blocks of other
    years. The 2022 report `rpt_q1_tags` is billed about 0.07 GB (72 MB in the dbt run results).
  - **Why not partitioning:**
    - **Size.** The table is 5.5 GB, about 0.4 GB per year on average. BigQuery suggests
      clustering instead of partitioning when partitions would hold less than approximately
      10 GB. This is a guideline, not a hard limit.
    - **Sandbox.** All tables and partitions expire after 60 days, counted from the partition
      boundary. A table partitioned by question date would expire every partition from 2008 to
      2022 immediately.
  - **Integer-range partitioning** on `creation_year` has no partition expiration, but it brings
    no benefit over clustering at this size.
  - **The table itself still expires.** Every dataset has a 60-day default table expiration, so
    the table expires 60 days after each build. The current build expires on 2026-12-28.
- **`pre_hook` that drops the table first.** During a rebuild the old and new tables coexist,
  which exceeds the 10 GB sandbox storage.
- **One wide table, no dimensions.** This is an analysis, not a data warehouse.
- **Tests:**
  - `question_id` unique and not null;
  - `creation_year` and `tag_combination` not null;
  - `answers_within_30d <= answer_count`;
  - `tag_combination` equals the sorted tags, whatever the source order;
  - `tests/assert_fct_questions_keeps_every_question.sql`: one fact row for every staged
    question.

## 4. Reports: one table per Q1 view

All Q1 analytical choices live here.

| | `rpt_q1_tags` | `rpt_q1_tag_combinations` |
|---|---|---|
| Population | 2022 + `has_full_30d_window`: 1,121,356 questions | the same, 2+ tags only: 988,059 |
| Unit | one tag (a question counts in each of its tags) | the exact tag set (a question counts in one combination) |
| Minimum volume | 500 questions → 792 tags | 200 questions → 174 combinations |

**Steps (CTEs)**
1. `questions`: filters the population.
2. `question_tags`: one row per tag, plus the **exact** median time to the first answer.
   `approx_quantiles` changed between runs.
3. `tag_metrics`: counts and rates, with `having count(*) >= 500`.
4. `ranked`: three rankings:
   - by answers per question;
   - by community acceptance;
   - by acceptance including self-acceptance.
5. `final`: rounds to 4 decimals **after** ranking, so rounding creates no artificial ties.

**Analytical choices**
- **"Current year" = 2022.** It is the latest year in the dump. It covers January to about
  2022-08-26, because of the 30-day window.
- **The main metric is `community_accepted_rate`.** It excludes self-acceptance; the rate with
  self-acceptance is shown next to it.
- **Two readings of "most answers":** total answers (volume) and answers per question
  (comparable across tags of different sizes).
- **A tested identity:** community acceptance = answered rate × acceptance among answered
  questions. It splits the outcome into two steps: getting an answer, then getting a solution.

**Tests (14, all passing):**
- minimum volume;
- rates between 0 and 1;
- community acceptance ≤ total acceptance;
- the identity;
- unique key.

## 5. Output: CSVs and the write-up

- **`results/`:** both reports exported, identical to the tables.
- **`docs/question_1.md`:** the complete analysis, written from the CSVs.
