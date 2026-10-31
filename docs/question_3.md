# Question 3: Post qualities, answers and acceptance

> *Other than tags, what qualities on a post correlate with the highest rate of answer and
> approved answer? Feel free to get creative.*

## Executive summary

- **Code is the quality most associated with success.** In 2022, questions with at least one
  code block get a community-accepted answer 28–32% of the time, against 18.1% for questions
  without code, and are answered 62–65% of the time, against 51.0%. The gap holds in every year
  from 2013 to 2022, among never-edited questions and among python-only questions.
- **Brand-new accounts do worse.** Questions from accounts created the same day get a
  community-accepted answer 20.0% of the time in 2022, against 28–29% for accounts between one
  day and three years old. Accounts older than three years do slightly worse again (27.5%).
- **Medium-length bodies do best, very long ones worst.** Bodies of 500–1,999 characters reach
  29–30%; bodies of 4,000+ characters reach 23.1%.
- **Reporting an error in prose goes with lower acceptance** (22.9% against 28.6%).
- **Smaller associations, 2–5 pp:** shorter titles, fewer tags, a question mark in the title and
  fewer links. Timing barely matters (weekends about +3 pp, hour of day about 2 pp), and images
  show no consistent association.
- All results are **associations**, computed one attribute at a time. They do not show that
  adding code or shortening a body would cause an answer.

## Methodology

**Data.** `bigquery-public-data.stackoverflow`, a static snapshot whose last question is dated
2022-09-25.

**Population.**
- Questions created from 2013 to 2022 with a complete 30-day observation window:
  **18,963,368 questions**, shown per creation year.
- **2022 is the main view.** It covers 2022-01-01 to about 2022-08-26 and is exactly the Q1
  population (1,121,356 questions), so the two analyses can be compared. Its baseline is the
  Q1 baseline: 60.6% answered, 27.2% community-accepted.
- **2013–2022 is the historical view**, with the survivorship caveats below.

**Metrics.** The Q1 definitions, per segment, year and bucket.

| Metric | Definition |
|---|---|
| `total_questions` | questions in the bucket; the denominator of both rates |
| `answered_question_rate` | questions with at least one answer within 30 days (the asker's own answers included) / total_questions |
| `community_accepted_rate` | questions whose accepted answer was posted within 30 days (the acceptance itself may be later) and written by someone other than the asker / total_questions. **The main metric** |

The numerators are stored as counts in the export, so every rate can be recomputed exactly.

**Attributes.** Only qualities known at posting time. Snapshot values are left out: score,
views, comments, favorites, edits and current reputation are observed later and are partly
caused by the answers themselves. `has_owner` is also left out, because an asker can delete the
account after posting.

| Attribute | Buckets | Note |
|---|---|---|
| `body_length` | <500, 500–999, 1,000–1,999, 2,000–3,999, 4,000+ | visible characters, code included |
| `code_block_count` | 0, 1, 2, 3+ | `<pre>` blocks; inline code not counted |
| `has_error_report` | false, true | "error", "exception" or "traceback" outside code blocks |
| `link_count` | 0, 1, 2+ | |
| `image_count` | 0, 1, 2+ | |
| `title_length` | <40, 40–49, 50–59, 60–74, 75+ | characters |
| `title_has_question_mark` | false, true | |
| `asker_account_age_days` | 0, 1–30, 31–365, 366–1,095, 1,096+, unknown | days from account creation to the question |
| `tag_count` | 1, 2, 3, 4, 5+ | the number of tags, not the tags themselves |
| `created_hour_utc` | 00–05, 06–11, 12–17, 18–23 | **UTC**, not the asker's local time |
| `created_weekday` | Sunday to Saturday | UTC day |

**Fixed bucket limits.** The limits are the same for every year. They were set once, on the
2013–2022 distribution (`queries/q3/01_attribute_distributions.sql`), close to round quintiles.
Limits recomputed per year would hide the changes between years inside the buckets.

**"unknown" account age is not an asker profile.** It holds questions whose owner deleted the
account (almost all of them) or whose account appears to be created after the question. It has
the highest rates of all buckets (43.8% community-accepted in 2022), the same effect found for
ownerless questions in `data_quality.md`: acceptances made before the deletion remain. It is
shown but left out of every comparison.

**Reading the numbers.**
- **Volume makes almost every difference statistically clear.** The smallest 2022 bucket has
  9,892 questions; the 95% margin of a difference between two 2022 buckets is ±0.2–0.6 pp
  (normal approximation, from the exported counts). What matters is the size of a gap, not
  whether it exists.
- **One attribute at a time.** Attributes overlap and are not controlled for each other: code
  also lengthens the body, and error reports often come with code.

## 2022: post qualities and outcomes

**Content of the body**

| Attribute | Bucket | Questions | Share | Answered | Community-accepted |
|---|---|---:|---:|---:|---:|
| Code blocks | 0 | 281,241 | 25.1% | 51.0% | 18.1% |
| | 1 | 378,442 | 33.7% | 62.1% | 28.1% |
| | 2 | 244,348 | 21.8% | 65.0% | 31.6% |
| | 3+ | 217,325 | 19.4% | 65.4% | 32.4% |
| Body length | <500 | 257,027 | 22.9% | 58.7% | 23.7% |
| | 500–999 | 313,502 | 28.0% | 62.4% | 29.1% |
| | 1,000–1,999 | 301,129 | 26.9% | 62.3% | 29.5% |
| | 2,000–3,999 | 165,981 | 14.8% | 59.5% | 26.9% |
| | 4,000+ | 83,717 | 7.5% | 55.5% | 23.1% |
| Error report | false | 838,713 | 74.8% | 61.8% | 28.6% |
| | true | 282,643 | 25.2% | 57.1% | 22.9% |
| Links | 0 | 801,142 | 71.4% | 61.5% | 27.7% |
| | 1 | 204,732 | 18.3% | 58.6% | 26.4% |
| | 2+ | 115,482 | 10.3% | 57.6% | 25.3% |
| Images | 0 | 989,436 | 88.2% | 60.3% | 27.0% |
| | 1 | 88,664 | 7.9% | 62.5% | 28.5% |
| | 2+ | 43,256 | 3.9% | 62.2% | 28.6% |

**Title, asker and tags**

| Attribute | Bucket | Questions | Share | Answered | Community-accepted |
|---|---|---:|---:|---:|---:|
| Title length | <40 | 175,241 | 15.6% | 62.6% | 28.5% |
| | 40–49 | 215,854 | 19.2% | 61.8% | 28.2% |
| | 50–59 | 220,210 | 19.6% | 61.1% | 27.8% |
| | 60–74 | 245,375 | 21.9% | 60.3% | 27.3% |
| | 75+ | 264,676 | 23.6% | 58.1% | 24.8% |
| Question mark in title | false | 855,438 | 76.3% | 59.7% | 26.4% |
| | true | 265,918 | 23.7% | 63.4% | 29.8% |
| Account age (days) | 0 | 148,503 | 13.2% | 55.4% | 20.0% |
| | 1–30 | 89,152 | 8.0% | 63.0% | 28.0% |
| | 31–365 | 215,568 | 19.2% | 62.6% | 28.8% |
| | 366–1,095 | 218,169 | 19.5% | 61.4% | 28.9% |
| | 1,096+ | 440,072 | 39.2% | 60.2% | 27.5% |
| | unknown | 9,892 | 0.9% | 74.1% | 43.8% |
| Tag count | 1 | 133,297 | 11.9% | 61.7% | 28.5% |
| | 2 | 281,221 | 25.1% | 62.5% | 29.1% |
| | 3 | 309,877 | 27.6% | 60.5% | 27.3% |
| | 4 | 219,914 | 19.6% | 59.5% | 25.8% |
| | 5+ | 177,047 | 15.8% | 58.4% | 24.6% |

**Timing (UTC)**

| Attribute | Bucket | Questions | Share | Answered | Community-accepted |
|---|---|---:|---:|---:|---:|
| Hour | 00–05 | 158,190 | 14.1% | 61.5% | 27.3% |
| | 06–11 | 325,810 | 29.1% | 59.5% | 26.2% |
| | 12–17 | 383,055 | 34.2% | 60.0% | 27.1% |
| | 18–23 | 254,301 | 22.7% | 62.3% | 28.5% |
| Weekday | Sunday | 103,927 | 9.3% | 63.0% | 29.2% |
| | Monday | 174,024 | 15.5% | 60.0% | 26.8% |
| | Tuesday | 189,682 | 16.9% | 60.0% | 26.8% |
| | Wednesday | 193,874 | 17.3% | 59.9% | 26.7% |
| | Thursday | 192,187 | 17.1% | 59.5% | 26.3% |
| | Friday | 166,469 | 14.8% | 60.6% | 27.0% |
| | Saturday | 101,193 | 9.0% | 63.5% | 29.4% |

**Which attributes separate most.** The gap between the best and the worst bucket of each
attribute in community acceptance ("unknown" excluded):

| Attribute | 2022 | 2013–2022 pooled |
|---|---:|---:|
| Code blocks | 14.3 pp | 11.5 pp |
| Account age | 8.9 pp | 11.4 pp |
| Body length | 6.3 pp | 9.5 pp |
| Error report | 5.7 pp | 7.0 pp |
| Tag count | 4.5 pp | 5.9 pp |
| Title length | 3.7 pp | 6.9 pp |
| Question mark in title | 3.4 pp | 3.7 pp |
| Weekday | 3.1 pp | 2.5 pp |
| Links | 2.4 pp | 5.2 pp |
| Hour (UTC) | 2.3 pp | 2.8 pp |
| Images | 1.6 pp | 2.4 pp |

The answered rate ranks the attributes in nearly the same order.

**Facts**
- **Code: the step is from none to some.** One code block lifts community acceptance from 18.1%
  to 28.1%; a second one to 31.6%; three or more add little (32.4%).
- **Account age is not monotonic.** Same-day accounts are lowest (20.0%), accounts from one
  day to three years old are highest (28.0–28.9%), and accounts older than three years are a
  little lower (27.5%). The pooled 2013–2022 data show the same shape more strongly (32.0%,
  then 42.0–43.4%, then 39.4%).
- **Body length is an inverted U.** Short bodies (<500 characters) and very long ones (4,000+)
  both trail the medium range by about 6 pp.
- **Error reports and code point in opposite directions.** Code goes with higher acceptance,
  error reports written in prose with lower acceptance.
- **Weekend questions do slightly better** (29.2–29.4% against 26.3–27.0% on weekdays), and
  so do evening questions in UTC (28.5% at 18–23, against 26.2% at 06–11).

**Inference (not tested).** Code makes a problem reproducible, and a body of medium length
gives enough context without burying the question. A same-day account often belongs to a first
question from someone new to the site. Weekend and evening questions may face less competition
for answerers' attention. None of these explanations was tested.

## Historical series, 2013–2022

The same contrasts, year by year, in community acceptance (percentage points):

| Contrast | 2013 | 2014 | 2015 | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Code: 2 blocks vs none | 10.3 | 11.0 | 11.5 | 12.0 | 12.3 | 12.9 | 12.1 | 12.3 | 12.9 | 13.5 |
| Account: 31–365 days vs same day | 13.1 | 10.3 | 10.5 | 10.4 | 10.1 | 9.9 | 9.7 | 10.3 | 10.5 | 8.7 |
| Body: 500–999 vs 4,000+ | 10.1 | 9.9 | 9.3 | 9.3 | 8.9 | 8.6 | 8.8 | 8.1 | 7.5 | 5.9 |
| Error report: no vs yes | 5.9 | 6.1 | 5.9 | 6.2 | 6.3 | 6.7 | 6.8 | 7.4 | 7.2 | 5.7 |
| Question mark: yes vs no | 5.3 | 4.9 | 4.6 | 4.4 | 4.3 | 3.8 | 3.2 | 3.5 | 3.3 | 3.4 |
| Images: 2+ vs none | −2.0 | −2.5 | −1.7 | −1.4 | −1.2 | −0.8 | 0.1 | −0.4 | 0.4 | 1.6 |
| *Community acceptance, all questions* | *49.9%* | *46.8%* | *43.6%* | *41.7%* | *40.5%* | *39.4%* | *38.9%* | *38.6%* | *34.9%* | *27.2%* |

**Facts**
- **The code gap widened while acceptance fell.** It grew from 10.3 to 13.5 pp as overall
  community acceptance fell from 49.9% to 27.2%. In relative terms the change is larger: two
  code blocks went with 1.24 times the rate of no code in 2013 (54.1% against 43.8%) and 1.75
  times in 2022 (31.6% against 18.1%).
- **The body-length gap narrowed** from 10.1 to 5.9 pp, and the question-mark gap from 5.3 to
  3.4 pp.
- **The account-age and error-report gaps stayed in a band** (about 9–13 and 6–7 pp).
- **Images changed sign:** slightly negative until 2018, slightly positive from 2020. The cause
  was not measured.

**Why the series needs caution.** The changes mix real shifts with three effects that cannot be
separated with this data:
1. **Survivorship.** Stack Overflow deleted, after about one year, unanswered questions that met
   its cleanup criteria (score of 0 or less, few views, at most one comment, among others; see
   `stackoverflow_rules.md`). Questions created before about September 2021 had passed that
   rule, for different lengths of time; later ones had not. If deleted questions concentrate in
   some buckets, those buckets lose their unanswered questions in older years, and the gaps
   between buckets can shrink or grow for that reason alone. *Plausible, not measured.*
2. **Acceptance date.** The accepted answer's posting date is used. Older questions had more time
   for an answer posted within 30 days to be accepted.
3. **Edits accumulate with age.** The body and title are the latest version, and older questions
   had more time to be edited.

The series therefore shows that the main associations **persist in direction** across ten years,
not how much they changed.

## Robustness

Two subsets of the population, never mixed into it and not representative of it:
- **never_edited:** questions never edited, so the title and body are the posted text. An edit of
  the tags alone also counts as an edit. The share of never-edited questions rises from 43–45%
  (2013–2019) to 55% (2022), because older questions had more time to be edited: the segment is a
  different selection each year.
- **python_only:** questions whose only tag is `python`, as in Q2. It removes the mix of topics
  (a python question is compared with other python questions). Small: 11,157 questions in 2022.

**2022, community-acceptance gap ± margin of the difference (pp)**

| Contrast | All | Never edited | Python only |
|---|---:|---:|---:|
| Code: 2 blocks vs none | 13.5 ± 0.2 | 13.3 ± 0.3 | 15.7 ± 2.9 |
| Account: 31–365 days vs same day | 8.7 ± 0.3 | 9.6 ± 0.4 | 9.3 ± 2.4 |
| Body: 500–999 vs 4,000+ | 5.9 ± 0.3 | 6.2 ± 0.5 | 13.4 ± 4.9 |
| Error report: no vs yes | 5.7 ± 0.2 | 4.7 ± 0.2 | 9.5 ± 2.0 |
| Tag count: 2 vs 5+ | 4.5 ± 0.3 | 5.7 ± 0.3 | n/a (always 1 tag) |
| Title: <40 vs 75+ | 3.7 ± 0.3 | 3.5 ± 0.3 | 1.8 ± 2.8 |
| Question mark: yes vs no | 3.4 ± 0.2 | 3.0 ± 0.3 | 3.4 ± 2.0 |
| Links: none vs 2+ | 2.4 ± 0.3 | 2.4 ± 0.4 | 5.3 ± 5.2 |
| Weekday: Saturday vs Wednesday | 2.7 ± 0.3 | 2.8 ± 0.5 | 3.5 ± 3.4 |
| Hour: 18–23 vs 06–11 UTC | 2.3 ± 0.2 | 2.3 ± 0.3 | 1.5 ± 2.5 |
| Images: 2+ vs none | 1.6 ± 0.4 | 1.7 ± 0.6 | 1.3 ± 9.2 |

**Facts**
- **Never edited: every direction holds**, with similar sizes. The text features are therefore
  not an artefact of edits made after the answers. The image sign change also appears here.
- **Python only: code, account age, error report and body length hold, and are larger.** The
  question mark holds at the same size. Title length, links, weekday, hour and images are within
  the margin in 2022. Some python-only buckets are tiny in single years (as few as 4 questions
  with 2+ images), so its yearly values are noisy.
- **Reading:** the four main associations survive both checks. The weaker ones may partly reflect
  the mix of topics, since they fade within a single tag.

## Confidence

- **Code, new accounts, very long bodies, error reports: high** for the direction in 2022. Large
  gaps with narrow margins, the same direction in every year, and both robustness checks agree.
- **Title length, tag count, question mark, links, timing: moderate to low.** Small gaps that
  fade within python-only questions.
- **Images: none.** Small and changing sign.
- **Size of the historical changes: low.** Survivorship, the acceptance-date proxy and edits
  overlap with any real change.

## Limitations

1. **Association, not causation.** Askers who include code may also be more experienced or ask
   about different problems. Nothing here shows that changing a post would change its outcome.
2. **One attribute at a time.** Attributes overlap (code lengthens the body; error reports often
   come with code) and were not modelled jointly.
3. **Survivorship.** Deleted questions are absent. Questions younger than about one year at the
   snapshot (late 2021 and 2022) may still include future deletions. Its effect on rates and on
   gaps between buckets was not measured, and it may differ by attribute and by year.
4. **Acceptance date is approximated.** A question counts as accepted when its accepted answer
   was posted within 30 days; the acceptance itself may have happened later. Older questions had
   more time for it.
5. **Text is the latest version.** Body and title features describe the post as it ended up; the
   never-edited check addresses this for the main associations.
6. **Error detection is a heuristic.** It looks for three words outside code blocks; a 20-question
   check on a sample put its precision at about 90%.
7. **UTC time.** Hour and weekday are in UTC, not the asker's local time.
8. **Self-answers count as answers.** As in Q1, `answered_question_rate` includes questions
   answered only by the asker.
9. **Partial year.** "2022" covers January to late August.

## Reproducibility

- **Model.** `models/reports/rpt_q3_post_qualities.sql`, built on `models/marts/fct_questions.sql`;
  column definitions and tests in `models/reports/_reports_models.yml`, reconciliation test in
  `tests/assert_rpt_q3_buckets_reconcile.sql`.
- **Export.** `results/q3_post_qualities.csv` (1,340 rows: segment × year × attribute × bucket).
- **Bucket limits.** `queries/q3/01_attribute_distributions.sql`.
- **Derived figures.** Two scripts in `scripts/q3/` read only the export; they run no query and
  need no dbt. Run them from the repository root with Python 3.10+ (standard library only):
  - `derived_statistics.py` prints the derived figures: populations and baselines, the
    best-minus-worst gaps, the yearly contrasts and code ratios, the robustness gaps with their
    margins, the never-edited share per year and the smallest python-only buckets. It prints
    labelled values to compare with this report; it is not a pass/fail check.
    Run `python scripts/q3/derived_statistics.py`.
  - `check_doc.py` checks every table of this report against the export: the 2022 buckets, the
    attribute gaps, the historical series and the robustness table. Numbers quoted in the running
    text are not checked by it. Run `python scripts/q3/check_doc.py`.
- **What the scripts do not cover.** The bucket limits come from the SQL in
  `queries/q3/01_attribute_distributions.sql`, and the counts themselves from the model; both read
  the project's BigQuery tables.
