# Architecture

How data flows from the public source to the answers, and why each layer exists.

## Overview

```
bigquery-public-data.stackoverflow     (source, read-only)
        │
        ▼  0. Ingestion: none (read in place)
        ▼  1. Profiling: queries/profiling/01–14 → docs/data_quality.md
        ▼
  stg_*  (views; body features: table)  models/staging/        shared
        ▼
  fct_questions  (table)                models/marts/          shared
        ▼
        ├──► rpt_q1_tags, rpt_q1_tag_combinations  (tables)   models/reports/   Q1
        │         ▼
        │    results/q1_*.csv  →  docs/question_1.md
        │
        ├──► rpt_q2_python_dbt_by_year  (table)               models/reports/   Q2
        │         ▼
        │    results/q2_python_dbt_by_year.csv  →  docs/question_2.md
        │
        └──► rpt_q3_post_qualities  (table)                   models/reports/   Q3
                  ▼
             results/q3_post_qualities.csv  →  docs/question_3.md
```

Staging and the fact table are shared by every question. Each question has its own report
models, CSV exports and write-up; the reports read only `fct_questions`, never each other.

## Repository layout

```
models/staging/   stg_* views, plus the body features table
models/marts/     fct_questions
models/reports/   rpt_q<N>_*: the tables that answer question N
tests/            singular data quality and consistency tests
queries/          profiling/, exploration/ and q<N>/: the SQL behind each finding
scripts/q<N>/     Python checks and derived statistics, read from results/
results/          CSV exports of the report tables
docs/             one write-up per question, plus data quality, Stack Overflow rules, cost and this page
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

- **What:** 14 queries in `queries/profiling/`, with the findings in `docs/data_quality.md`.
- **Findings that became decisions:**
  - **The data ends on 2022-09-25**, so 2022 is a partial year.
  - **331 questions with an invalid acceptance** (332 failed checks; one question fails two):
    - 230 point to an answer that does not exist;
    - 62 point to an answer of another question;
    - 40 point to an answer posted before the question.

    These cases define the "valid acceptance" rule.
  - **94.7% of first answers arrive within 30 days.** This justifies the 30-day window.
  - **Survivorship bias.** After about one year, Stack Overflow automatically deletes some
    unanswered questions that meet its cleanup criteria, a score of 0 or less among them (see
    [stackoverflow_rules.md](stackoverflow_rules.md)). Deleted posts are not in the dump.
    - **Evidence:** among questions created after September 2021, which were not yet one year old,
      the share of unanswered questions with a score ≤ 0 jumps from 12.5% to 26.6%. This is
      consistent with the one-year deletion rule.
    - **Why 2022 helps:** 2022 questions had not reached the one-year rule.
    - **What remains:** shorter deletion rules can still remove 2022 questions:
      - the 30-day rule can delete some unanswered questions with a negative score;
      - the closed-question rule can delete some closed (not as duplicates), unanswered
        questions 9 days after closure.

      Both remove questions that failed, so the remaining data can hold proportionally more
      answered and accepted questions, and the rates can look higher than they were. The size of
      this effect was not measured.
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
| `has_accepted_answer` | the accepted answer exists, belongs to this question and was posted after it | excludes the 331 invalid acceptances |
| `is_self_accepted` | the accepted answer's owner is the asker | separates community help from self-help |
| `is_accepted_within_30d` | a valid acceptance of an answer posted within 30 days | the dump has no acceptance date; the answer date is the proxy |
| `has_full_30d_window` | posting date + 30 days falls before the end of the dump | right-censoring |

**Columns added by Q2.** Q2 reuses the columns above and also filters on `creation_year`
(2013 to 2022) and `tag_count` (exactly one tag), with `tag_combination` as the tag itself.

**Columns added by Q3.** Attributes known at posting time; title and body are the latest version.

| Column | Rule | Why |
|---|---|---|
| `title_length`, `title_has_question_mark` | length of the title; whether it contains `?` | title qualities |
| `body_length`, `code_block_count`, `link_count`, `image_count`, `has_error_report` | from `stg_question_body_features` | body qualities, without reading `body` again |
| `asker_account_age_days` | days from account creation to posting; null if the account looks newer than the question | the asker's experience at posting time, unlike the snapshot reputation |
| `created_hour_utc`, `created_weekday` | from `created_at`, in UTC | posting time (not the asker's local time) |
| `is_edited` | `last_edited_at` is not null | selects never-edited questions, whose text is the posted version |

**Technical decisions**
- **Clustered by `creation_year`, not partitioned**, and a **`pre_hook` that drops the table
  first**. Both come from the sandbox limits; the reasons are in [cost.md](cost.md).
- **One wide table, no dimensions.** This is an analysis, not a data warehouse.
- **Tests:**
  - `question_id` unique and not null;
  - `creation_year` and `tag_combination` not null;
  - `answers_within_30d <= answer_count`;
  - `tag_combination` equals the sorted tags, whatever the source order;
  - `tests/assert_fct_questions_keeps_every_question.sql`: one fact row for every staged
    question.

## 4. Reports: one table per question view

All analytical choices live here. Each report reads `fct_questions` only.

| Question | Model | Grain |
|---|---|---|
| Q1 | `rpt_q1_tags` | one row per tag |
| Q1 | `rpt_q1_tag_combinations` | one row per exact tag combination |
| Q2 | `rpt_q2_python_dbt_by_year` | one row per tag (python, dbt) and year |
| Q3 | `rpt_q3_post_qualities` | one row per segment, year, attribute and bucket |

### Q1: `rpt_q1_tags` and `rpt_q1_tag_combinations`

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

**Tests (12, six per model, all passing):**
- minimum volume;
- rates between 0 and 1;
- community acceptance ≤ total acceptance;
- the identity;
- unique key.

### Q2: `rpt_q2_python_dbt_by_year`

| | |
|---|---|
| Population | questions whose only tag is `python` or `dbt`, 2013–2022, `has_full_30d_window` |
| Unit | one tag and one creation year: 2 tags × 10 years = 20 rows |
| Partial year | 2022 covers January to about 2022-08-26 and is flagged by `is_partial_year` |

**Steps (CTEs)**
1. `questions`: filters the population.
2. `tag_years`: every tag × every year, so years without questions still get a row.
3. `year_metrics`: counts per tag and year.
4. `year_rates`: joins the counts to `tag_years`; empty years get 0 questions and null rates.
   Computes the question-to-answer ratio, its inverse and the two acceptance rates.
5. `year_over_year`: changes against the previous year, with `lag()` per tag.
6. `final`: rounds to 4 decimals.

**Analytical choices**
- **"Only python / dbt" = exactly one tag.**
- **The last 10 years = 2013 to 2022**, with 2022 partial.
- **Question-to-answer ratio = questions / answers**, the question's wording read literally;
  answers per question is shown next to it.
- **Year-over-year change:** the ratio in percent of the previous year; the rates in
  percentage points.
- **The main acceptance metric is `community_accepted_rate`**, as in Q1.
- **dbt has no single-tag questions before 2020.** Those years stay as rows with 0 questions
  and null rates, never 0%.

**Tests (8, all passing):**
- unique tag and year;
- years between 2013 and 2022;
- answered and accepted questions ≤ total questions;
- community acceptance ≤ total acceptance;
- rates null exactly when the year has no questions;
- `tag` in python / dbt, and not null keys.

### Q3: `rpt_q3_post_qualities`

| | |
|---|---|
| Population | 2013–2022 + `has_full_30d_window`; 2022 is exactly the Q1 population (1,121,356) |
| Unit | one segment, creation year, attribute and bucket: 1,340 rows |
| Partial year | 2022 covers January to about 2022-08-26 and is flagged by `is_partial_year` |

**Steps (CTEs)**
1. `questions`: filters the population.
2. `question_segments`: each question once in `all`, and again in each robustness segment it
   belongs to (`never_edited`, `python_only`).
3. `question_buckets`: one row per question, segment and attribute, with its bucket. No `case`
   has an `else`, so an unexpected value gets a null bucket and fails a test.
4. `bucket_metrics`: counts per segment, year, attribute and bucket.
5. `final`: rates rounded to 4 decimals, plus `is_partial_year`.

**Analytical choices**
- **Attributes known at posting time only:** 11 attributes (body length, code blocks, error
  report, links, images, title length, question mark in the title, account age, tag count,
  hour, weekday). Snapshot values (score, views, current reputation, `has_owner`) are left out.
- **Fixed buckets for every year**, set on the 2013–2022 distribution
  (`queries/q3/01_attribute_distributions.sql`), so years compare bucket by bucket.
- **Segments:** `all` is the analysis. `never_edited` (text as posted) and `python_only` (as in
  Q2) are robustness subsets, never mixed into it.
- **Metrics:** the Q1 definitions; the main one is `community_accepted_rate`.
- **Empty buckets have no row:** a missing row means no observations, not a rate of zero.

**Tests (13, all passing):**
- unique segment, year, attribute and bucket;
- years between 2013 and 2022, and at least one question per row;
- answered ≤ total and community accepted ≤ answered; rates between 0 and 1;
- accepted values for `segment` and `attribute`, and not null keys;
- `tests/assert_rpt_q3_buckets_reconcile.sql`: every attribute adds up to the same population,
  `all` matches `fct_questions` and `python_only` matches the Q2 report.

## 5. Output: CSVs and the write-ups

- **`results/`:** every report exported, identical to the tables: `q1_tags.csv`,
  `q1_tag_combinations.csv`, `q2_python_dbt_by_year.csv` and `q3_post_qualities.csv`.
  `scripts/export_results.py` regenerates them for free (`list_rows`, no query).
- **`docs/question_1.md`**, **`docs/question_2.md`** and **`docs/question_3.md`:** the complete
  analyses, written from the CSVs. `scripts/q1/`, `scripts/q2/` and `scripts/q3/` recompute the derived
  figures and check the tables of the write-ups against the CSVs.
