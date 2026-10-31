# Question 1: Tags, tag combinations, answers and acceptance

> *What tags on a Stack Overflow question lead to the most answers and the highest rate of
> approved answers for the current year? What tags lead to the least? How about combinations
> of tags?*

## Executive summary

- **Tags about well-scoped data and text manipulation sit at the top.** awk, jq, data.table,
  dplyr, tidyverse, sed and regex get a community-accepted answer for 59–67% of their questions
  and 1.4–2.4 answers per question. The 2022 baseline is 27% and 0.80.
- **Tags about platforms, tooling and environment setup sit at the bottom.** appium, cordova,
  facebook, aws-amplify, webview and webpack get a community-accepted answer for 6.5–8.5% of their
  questions and about 0.3–0.5 answers per question. In these tags, 30–50% of accepted answers
  were written by the asker.
- **The most answers in total go to the largest tags.** python (166,163 answers within 30 days),
  javascript (114,053) and reactjs (55,269) lead on total answers because they have the most
  questions. Their answers per question (0.82–0.93) are close to the baseline, and they rank
  185th, 222nd and 328th of 792 on community acceptance. The fewest total answers belong to tags
  just above the 500-question threshold that also get few answers per question.
- **Answers per question and community acceptance rank tags almost identically** (Spearman 0.92
  across 792 tags). Total answers behave differently: they follow tag size (Spearman 0.92 with
  the number of questions) and relate only moderately to community acceptance (0.48).
- **Tag size says little about acceptance.** The number of questions and community acceptance
  are only weakly related (Spearman 0.17).
- **Combinations repeat the same split.** Combinations such as dplyr|r, python|regex and
  pandas-based sets lead. Combinations such as android|react-native and woocommerce|wordpress
  trail. The reported combinations cover only the most common tag sets (10.8% of questions with
  2+ tags).
- **How common a question's exact tag set is goes with acceptance.** Questions whose exact tag
  set is common (200+ questions) get a community-accepted answer 40% of the time. Questions with
  a unique tag set get one 22% of the time. The gap narrows from 17.9 to 15.4 pp when questions
  with rare tags are excluded, and it is present within every tag count and among never-edited
  questions.
- All results are **associations**. The data cannot show that a tag *leads to* more answers.

## Methodology

**Data.** `bigquery-public-data.stackoverflow`, a static snapshot whose last question is dated
2022-09-25.

**"Current year" = 2022.** It is the latest year in the dump. Questions posted in the last
30 days before the snapshot had less time to be answered, so the analysis keeps only questions
with a complete 30-day observation window. That means questions created from 2022-01-01 to about
2022-08-26: **1,121,356 questions**.

**Observation window.** Every question is observed for the same 30 days after posting. Answers
and acceptances that happen later are not counted, so a January question has no advantage over
an August one. In the dump, 94.7% of first answers arrive within 30 days.

**Metric definitions.** All metrics are computed per tag or per combination.

| Metric | Definition |
|---|---|
| `total_questions` | questions in the group; the denominator of the question-level rates |
| `total_answers` | answers posted within 30 days. A question with three answers adds three |
| `answered_questions` | questions with at least one answer within 30 days. A question with five answers adds one |
| `answers_per_question` | total_answers / total_questions |
| `answered_question_rate` | answered_questions / total_questions |
| `community_accepted_rate` | questions whose accepted answer, posted within 30 days, was written by someone other than the asker, divided by total_questions. **The main acceptance metric** |
| `accepted_rate` | the same, but self-accepted answers included |
| `community_acceptance_rate_answered` | community-accepted questions / answered_questions |
| `self_accepted_share` | self-accepted questions / accepted questions |
| `median_hours_to_first_answer` | exact median, over questions answered within 30 days |

**Two readings of "most answers".** The question can be read in two ways, and both are reported:
- **Total answers:** the volume a tag receives. It depends mostly on how many questions the tag
  has.
- **Answers per question:** the volume per question, which can be compared across tags of
  different sizes. The comparison between tags relies on this metric.

Neither is the number of answered questions. A question with five answers adds five to
`total_answers` and one to `answered_questions`.

**Valid acceptance.** An acceptance counts only if the accepted answer exists, belongs to the
question and was posted after it. Profiling found 332 accepted-answer ids that fail these
checks, out of 11.8M accepted questions.

**Why community acceptance is the main rate.** A self-accepted answer means the asker wrote the
answer they accepted. The community may still have helped, for example through comments or other
answers the asker built on, but the dump does not show that contribution. The main metric
therefore counts only accepted answers written by someone else, the outcome the question asks
about. Self-acceptance is not spread evenly: it is 30–50% of accepted answers in the
lowest-acceptance tags, against 1.5–2.9% in the highest. Mixing the two outcomes would blur the
comparison. `accepted_rate`, which includes self-accepted answers, is reported next to it, and
`rank_if_self_accepted_counted` shows the ranking under that definition.

**Grouping and minimum volume.**

| | Tags | Combinations |
|---|---|---|
| Unit | one tag | the exact tag set of a question, 2+ tags, sorted alphabetically |
| Counting | a question counts once in each of its tags | a question counts in exactly one combination |
| Example: `python`, `pandas`, `numpy` | counts in all three tags | counts only in `numpy\|pandas\|python`, not in `pandas\|python` |
| Minimum volume | 500 questions (792 tags) | 200 questions (174 combinations) |
| 95% interval half-width (Wilson) | median ±2.5 pp, max ±4.3 pp | median ±4.7 pp, max ±6.8 pp |

**Baseline (2022 population).** 0.80 answers per question, 60.6% of questions answered and
27.2% community-accepted. Among questions with 2+ tags (988,059), community acceptance is 27.0%.

## Individual tags

**Most answers per question**

| Tag | Questions | Answers / question | Answered | Community-accepted (95% CI) |
|---|---:|---:|---:|---:|
| awk | 1,117 | 2.44 | 95.7% | 66.9% (64.1–69.6) |
| sed | 941 | 2.18 | 94.0% | 61.9% (58.7–64.9) |
| grep | 543 | 1.84 | 87.5% | 52.3% (48.1–56.5) |
| java-stream | 723 | 1.74 | 92.7% | 60.2% (56.6–63.7) |
| list | 8,894 | 1.53 | 85.0% | 49.4% (48.4–50.5) |

**Fewest answers per question**

| Tag | Questions | Answers / question | Answered | Community-accepted (95% CI) |
|---|---:|---:|---:|---:|
| facebook | 857 | 0.28 | 24.0% | 6.8% (5.3–8.6) |
| google-chrome-extension | 1,782 | 0.32 | 29.0% | 9.0% (7.8–10.5) |
| soap | 754 | 0.34 | 30.8% | 8.9% (7.1–11.1) |
| proxy | 1,054 | 0.37 | 33.2% | 9.3% (7.7–11.2) |
| webview | 895 | 0.38 | 32.3% | 8.3% (6.6–10.3) |

**Most total answers**

| Tag | Questions | Total answers | Answers / question | Community-accepted (95% CI) |
|---|---:|---:|---:|---:|
| python | 179,625 | 166,163 | 0.93 | 32.5% (32.3–32.7) |
| javascript | 123,457 | 114,053 | 0.92 | 30.5% (30.2–30.7) |
| reactjs | 67,000 | 55,269 | 0.82 | 26.1% (25.8–26.4) |
| html | 44,689 | 45,347 | 1.01 | 32.0% (31.6–32.4) |
| java | 57,835 | 44,752 | 0.77 | 23.3% (23.0–23.7) |

**Fewest total answers**

| Tag | Questions | Total answers | Answers / question | Community-accepted (95% CI) |
|---|---:|---:|---:|---:|
| drag-and-drop | 506 | 202 | 0.40 | 11.5% (9.0–14.5) |
| apollo | 511 | 203 | 0.40 | 8.6% (6.5–11.4) |
| apollo-client | 531 | 205 | 0.39 | 11.3% (8.9–14.3) |
| object-detection | 541 | 210 | 0.39 | 8.9% (6.8–11.6) |
| progressive-web-apps | 511 | 222 | 0.43 | 9.0% (6.8–11.8) |

**Reading the total-answers tables.**
- **Total answers is mostly a size ranking.** Across the 792 tags it correlates at 0.92 with the
  number of questions (Spearman). The five tags with the most total answers are five of the six
  largest tags, and their answers per question are close to the 0.80 baseline.
- **The low end is bounded by the threshold.** The five tags with the fewest total answers have
  506–541 questions, just above the 500 minimum. Tags below 500 questions are not reported, so
  "fewest total answers" means the fewest among reported tags. Even so, these five also get few
  answers per question (0.39–0.43) and rank between 751st and 784th of 792 on community
  acceptance.

**Highest community acceptance**

| Tag | Questions | Community-accepted (95% CI) | Self-accepted share |
|---|---:|---:|---:|
| awk | 1,117 | 66.9% (64.1–69.6) | 1.5% |
| jq | 737 | 66.8% (63.3–70.1) | 2.8% |
| data.table | 607 | 66.1% (62.2–69.7) | 2.7% |
| dplyr | 3,645 | 63.6% (62.0–65.1) | 1.7% |
| tidyverse | 1,294 | 62.1% (59.5–64.7) | 1.6% |
| sed | 941 | 61.9% (58.7–64.9) | 2.7% |
| regex | 6,224 | 59.4% (58.1–60.6) | 2.9% |

**Lowest community acceptance**

| Tag | Questions | Community-accepted (95% CI) | Self-accepted share |
|---|---:|---:|---:|
| appium | 523 | 6.5% (4.7–8.9) | 33.3% |
| cordova | 621 | 6.6% (4.9–8.8) | 48.1% |
| facebook | 857 | 6.8% (5.3–8.6) | 30.1% |
| aws-amplify | 798 | 7.8% (6.1–9.8) | 49.6% |
| xampp | 581 | 8.3% (6.3–10.8) | 31.4% |
| webview | 895 | 8.3% (6.6–10.3) | 32.7% |
| webpack | 3,183 | 8.5% (7.6–9.5) | 47.6% |

Tables are sorted by the metric, but **the order inside each table is not a statistically
established ranking**: the intervals of neighbouring tags overlap. What the data supports is the
separation between the groups. The lowest lower bound among the ten highest-acceptance tags is
53.6%, and the highest upper bound among the ten lowest is 11.4%.

**Further observations**

- **The per-question metrics move together, total answers do not.** Across the 792 tags
  (Spearman):
  - answers per question and community acceptance: 0.92;
  - total answers and community acceptance: 0.48;
  - community acceptance and self-accepted share: −0.87;
  - community acceptance and median time to the first answer: −0.68.

  The two per-question rankings, answers per question and community acceptance, therefore
  identify largely the same tags at each end. The total-answers ranking mainly reflects size.
- **Two steps of acceptance.** Community acceptance = answered rate × acceptance among answered
  questions. The two steps correlate at 0.75 across tags (Pearson, on the rates; unlike the
  Spearman rank correlations above). The bottom tags lose on both: fewer
  questions get an answer, and fewer answered questions end with a community-accepted solution.
  For example, cordova is answered 34.0% of the time, and only 19.4% of its answered questions
  reach a community-accepted answer. For awk the figures are 95.7% and 69.9%.
- **Size is not success.** None of the eight largest tags is among the top 180 on community
  acceptance:
  - python 32.5% (185th);
  - javascript 30.5% (222nd);
  - reactjs 26.1% (328th);
  - java 23.3% (413th);
  - android 17.4% (609th).
- **Self-acceptance changes little at the extremes.** When self-accepted answers are counted,
  the median tag moves 19 positions. The largest moves are mid-table (cors: 479th → 246th). The top and
  bottom groups do not change.
- **Stability across thresholds.** Raising the minimum volume to 1,000 questions (419 tags) or
  2,000 questions (210 tags) keeps the same themes at both ends. The names below come from the
  2,000 cut, among its eight highest and eight lowest tags; at 1,000 the extremes are not
  identical, but they are the same kinds of tags:
  - top: dplyr, regex, beautifulsoup, dataframe, pandas;
  - bottom: webpack, ssl, nginx, gradle, google-chrome, heroku.

## Tag combinations

**Coverage.** Exact tag sets are highly fragmented:
- there are 583,276 distinct combinations among 988,059 questions with 2+ tags;
- 512,711 of these questions (52%) have a tag set no other question uses;
- the **174 combinations with 200+ questions cover 106,793 questions (10.8%)**: 119 combinations
  of 2 tags, 48 of 3 and 7 of 4.

**This report therefore describes the most common tag sets, not the typical multi-tag
question.** The 133,297 single-tag questions are not combinations and appear only in the tag
analysis.

**Why 200 questions.** The threshold trades coverage for precision.

| | 200+ (reported) | 500+ |
|---|---:|---:|
| Combinations | 174 | 50 |
| Of 2 / 3 / 4 tags | 119 / 48 / 7 | 44 / 5 / 1 |
| Questions covered | 106,793 | 68,952 |
| Share of the 988,059 questions with 2+ tags | 10.8% | 7.0% |
| Answers within 30 days | 119,265 | 81,725 |
| Median questions per combination | 351 | 912.5 |
| 95% interval half-width (Wilson), median | ±4.7 pp | ±3.1 pp |
| 95% interval half-width (Wilson), max | ±6.8 pp | ±4.3 pp |

- **Coverage.** Lowering the threshold from 500 to 200:
  - multiplies the combinations by 3.5 (50 → 174);
  - adds 37,841 questions;
  - keeps sets of 3 and 4 tags, which almost disappear at 500 (5 and 1).
- **The cost is precision.** The widest interval grows from ±4.3 to ±6.8 pp. At 500 the
  combinations match the precision of the tag report, which also has a 500 minimum.
- **200 is a compromise, not a guarantee of precision.** Intervals of up to ±6.8 pp are enough to
  separate the top and bottom groups. They are not enough to order neighbouring combinations.
- **Not evaluated:** lower thresholds such as 100.

**Highest community acceptance (200+ questions)**

| Combination | Questions | Answers / question | Community-accepted (95% CI) |
|---|---:|---:|---:|
| javascript\|regex | 363 | 1.53 | 65.8% (60.8–70.5) |
| dataframe\|pandas\|pandas-groupby\|python | 201 | 1.53 | 65.2% (58.4–71.4) |
| dplyr\|r | 998 | 1.51 | 64.4% (61.4–67.3) |
| python\|regex | 573 | 1.63 | 64.0% (60.0–67.9) |
| dataframe\|pandas\|python\|python-3.x | 366 | 1.53 | 63.9% (58.9–68.7) |
| dictionary\|python | 555 | 1.80 | 57.8% (53.7–61.9) |

**Lowest community acceptance (200+ questions)**

| Combination | Questions | Answers / question | Community-accepted (95% CI) |
|---|---:|---:|---:|
| android\|react-native | 227 | 0.50 | 7.5% (4.7–11.7) |
| woocommerce\|wordpress | 288 | 0.41 | 10.4% (7.4–14.5) |
| google-chrome-extension\|javascript | 210 | 0.40 | 11.9% (8.2–17.0) |
| php\|woocommerce\|wordpress | 436 | 0.42 | 12.4% (9.6–15.8) |
| expo\|react-native | 319 | 0.55 | 12.8% (9.6–17.0) |
| python\|tensorflow | 400 | 0.53 | 16.5% (13.2–20.5) |

**Most and fewest answers per question.**
- The most: dictionary\|list\|python (2.07), arrays\|javascript\|object (2.00), list\|python
  (1.91) and arrays\|javascript (1.91).
- The fewest: google-chrome-extension\|javascript (0.40), woocommerce\|wordpress (0.41) and
  php\|woocommerce\|wordpress (0.42).
- Answers per question and community acceptance correlate at 0.87 (Spearman, 174 combinations).

**Most total answers (200+ questions)**

| Combination | Questions | Total answers | Answers / question | Community-accepted (95% CI) |
|---|---:|---:|---:|---:|
| pandas\|python | 5,330 | 7,012 | 1.32 | 53.5% (52.1–54.8) |
| css\|html | 4,313 | 6,219 | 1.44 | 41.9% (40.4–43.4) |
| dataframe\|pandas\|python | 3,949 | 5,515 | 1.40 | 57.5% (55.9–59.0) |
| javascript\|reactjs | 4,283 | 4,969 | 1.16 | 37.1% (35.7–38.6) |
| dart\|flutter | 3,810 | 4,386 | 1.15 | 38.1% (36.5–39.6) |

**Fewest total answers (200+ questions)**

| Combination | Questions | Total answers | Answers / question | Community-accepted (95% CI) |
|---|---:|---:|---:|---:|
| google-chrome-extension\|javascript | 210 | 83 | 0.40 | 11.9% (8.2–17.0) |
| visual-studio-code\|vscode-extensions | 207 | 105 | 0.51 | 18.8% (14.1–24.7) |
| android\|react-native | 227 | 113 | 0.50 | 7.5% (4.7–11.7) |
| pyqt5\|python | 238 | 113 | 0.47 | 23.1% (18.2–28.9) |
| woocommerce\|wordpress | 288 | 119 | 0.41 | 10.4% (7.4–14.5) |

- **As with tags, total answers follow size.** Across the 174 combinations, total answers
  correlate at 0.86 with the number of questions and at 0.56 with community acceptance
  (Spearman).
- **The low end is bounded by the threshold.** The five combinations with the fewest total
  answers have 207–288 questions, close to the 200 minimum.

**Comparison with the rest of the population.**
- **Method.** Each combination is a subset of the population, so it is compared with the
  disjoint remainder of the 2+ tag population: a two-proportion z-test, with Holm correction for
  174 tests at α = 0.05.
- **Result.**
  - **99 combinations** have a community acceptance rate significantly above the remainder;
  - **11** are significantly below;
  - **64** are not distinguishable from it.
- **The 11 below** are android\|react-native, woocommerce\|wordpress,
  google-chrome-extension\|javascript, php\|woocommerce\|wordpress, expo\|react-native,
  android\|android-studio, jupyter-notebook\|python, android\|flutter, python\|tensorflow,
  php\|wordpress and android\|java.

**Within one language.** The 45 python combinations range from 15.0% (jupyter-notebook\|python)
to 65.2% (dataframe\|pandas\|pandas-groupby\|python) in community acceptance. The python tag as a
whole is at 32.5%. The language alone says little; the subject of the question matters more.

**Sensitivity to the minimum volume (200 vs 500).**
- **The top is stable.** With 500+ questions (50 combinations), the leaders are the same kind of
  tag sets: dplyr\|r, python\|regex, dictionary\|python, dataframe\|pandas\|python, ggplot2\|r,
  dataframe\|r, arrays\|javascript and pandas\|python, between 52% and 64%.
- **The bottom is not.** None of the ten lowest combinations at 200+ has 500 questions. At 500+,
  the lowest are:
  - php\|wordpress, 18.2% (15.3–21.6);
  - android\|java, 20.7% (18.3–23.4);
  - mysql\|php, 26.8% (23.3–30.7);
  - and several combinations close to or above the baseline, such as excel\|vba at 32.1%.
- **The lowest rates (7–17%) only appear among combinations with 200–499 questions.** This is
  consistent with the frequency gradient below. Statements about "the worst combinations" must
  name the popularity range they refer to.

## Combination frequency gradient

**Definition.**
- The frequency of a combination is the number of questions in the population (2022, complete
  30-day window, 2+ tags) with exactly that tag set.
- The rate is the community acceptance rate within 30 days.
- Each question belongs to exactly one frequency band. The bands below add up to the full
  2+ tag population (988,059).

**A. Full population**

| Combination used by | Questions | Community-accepted | Rate |
|---|---:|---:|---:|
| 200+ questions | 106,793 | 42,679 | 40.0% |
| 20–199 | 121,468 | 41,166 | 33.9% |
| 2–19 | 247,087 | 70,268 | 28.4% |
| 1 question (unique) | 512,711 | 112,850 | 22.0% |

**B. Controls (community acceptance rate)**

| Control | 200+ | 20–199 | 2–19 | Unique | Gap |
|---|---:|---:|---:|---:|---:|
| Full population | 40.0% | 33.9% | 28.4% | 22.0% | 17.9 pp |
| Only frequent tags¹ (399,375 questions) | 40.0% | 34.1% | 29.2% | 24.6% | 15.4 pp |
| Only frequent tags, 2 tags | 38.9% | 32.0% | 25.0% | 18.5% | 20.5 pp |
| Only frequent tags, 3 tags | 43.1% | 35.3% | 29.4% | 23.5% | 19.6 pp |
| Only frequent tags, 4 tags | 46.8% | 39.1% | 32.6% | 25.6% | 21.2 pp |
| Never-edited questions² | 38.6% | 31.9% | 25.8% | 19.4% | 19.2 pp |
| Edited questions² | 41.4% | 36.0% | 31.5% | 25.2% | 16.2 pp |

¹ Questions whose tags all belong to the 792 tags with 500+ questions. A combination fixes the
tag set, so this filter keeps or drops whole combinations and their frequency is unchanged.
² Tags are the current ones. In never-edited questions they are the tags chosen at posting time.
Gaps are computed from unrounded rates (for example, 39.96% − 22.01% = 17.9 pp).

**Question counts behind table B**

| Control | 200+ | 20–199 | 2–19 | Unique |
|---|---:|---:|---:|---:|
| Only frequent tags | 106,793 | 93,961 | 107,822 | 90,799 |
| Only frequent tags, 2 tags | 82,422 | 48,845 | 30,978 | 7,902 |
| Only frequent tags, 3 tags | 21,966 | 33,912 | 45,614 | 27,709 |
| Only frequent tags, 4 tags | 2,405 | 9,241 | 22,109 | 30,332 |
| Never-edited | 53,678 | 63,555 | 134,666 | 285,855 |
| Edited | 53,115 | 57,913 | 112,421 | 226,856 |

**Facts**
- **The gradient is monotonic in every cut.**
- **Excluding rare tags narrows the gap from 17.9 to 15.4 pp.** The filter keeps only questions
  whose tags all have 500+ questions. The gap shrinks by 2.5 pp and remains large. Rare tags are
  common in unique combinations: 82% of unique-combination questions contain one (90,799 of
  512,711 contain none).
- **The gradient also appears among never-edited questions** (19.2 pp). Editors moving answered
  questions into common tag sets therefore cannot be its only source.
- **More tags go with higher acceptance inside every band.** For example, unique combinations
  reach 18.5% with 2 tags and 25.6% with 4. Across all combinations the relation looks negative
  only because more tags make a combination rarer (Simpson's paradox).

**Inference (not tested).** A common tag set signals a standard problem in a popular stack,
which many people can answer. An unusual set of individually common tags signals a mix of
technologies that few people master together.

## Statistical confidence

- **Intervals.** They are 95% Wilson score intervals on `community_accepted_rate`, computed from
  the exported counts. Wilson keeps reasonable coverage near 0% and 100%, where the normal
  approximation fails.
- **What the intervals support:**
  - the separation between the top and bottom groups, for tags and for combinations;
  - differences between a group and the remainder of the population, with Holm correction.
- **What they do not support:** the exact order inside the top or bottom ten.
  - Among the ten highest-acceptance combinations, the intervals of positions 2 to 10 all
    overlap the interval of position 1.
  - Among the ten highest-acceptance tags, 5 of the 9 overlap the first.
- **Answers per question** is an average, not a proportion, so Wilson does not apply to it. The
  distance between the groups (2.44 vs 0.28 answers per question) is far larger than any
  plausible sampling noise at these volumes. No interval was computed for it.
- **Total answers** are reported as observed counts. No interval was computed for them.

## Limitations

1. **Association, not causation.** A tag marks the kind of problem; it does not cause the
   outcome. Other factors may explain part of the pattern and were not controlled for:
   - asker experience;
   - question quality;
   - the size and culture of each community. The R tags, for instance, have a small and very
     active answering community.
2. **The thematic reading is an interpretation.** "Data and text manipulation at the top,
   platform and setup at the bottom" summarises the extremes. It was not derived from a
   systematic classification of all 792 tags.
3. **Coverage of combinations.** The combination results describe the 174 most common tag sets
   (10.8% of questions with 2+ tags). They do not generalise to the 583,276 combinations that
   exist, and the frequency gradient shows that rarer combinations do worse.
4. **Minimum volumes are judgement calls.** 500 and 200 are compromises between coverage and
   precision, not guarantees of precision (see "Why 200 questions"). The top groups are stable
   between 200 and 500, but the lowest combinations depend on the threshold. Lower thresholds
   such as 100 were not evaluated. The threshold also bounds the "fewest total answers"
   rankings, which include only tags and combinations above it.
5. **Excluded questions.** A question whose tags all have fewer than 500 questions appears in no
   tag row. The number of such questions was not measured.
6. **Self-answers count as answers.** `answered_questions` includes questions answered only by
   the asker. This inflates the answered rate and lowers the acceptance rate among answered
   questions, most likely in the bottom tags, where self-acceptance is high. The size of this
   effect was not measured.
7. **Acceptance date is approximated.** The dump has no acceptance date, so the accepted answer's
   posting date is used. An answer posted on day 10 and accepted on day 40 counts as accepted
   within 30 days.
8. **Deleted questions are absent.** Stack Overflow removes some unanswered, low-scored questions.
   If this happens more in some tags, their rates are biased upward. The dump cannot measure it.
9. **Current tags.** Tags can be edited after posting. The never-edited control addresses this for
   the frequency gradient, but not for the tag and combination rankings.
10. **Partial year.** "2022" covers January to late August, not the full calendar year.

## Reproducibility

- **Models.**
  - `models/reports/rpt_q1_tags.sql` and `models/reports/rpt_q1_tag_combinations.sql`, built on
    `models/marts/fct_questions.sql`;
  - column definitions in `models/reports/_reports_models.yml`.
- **Exports.** `results/q1_tags.csv` and `results/q1_tag_combinations.csv`.
- **Derived figures.** The Wilson intervals, the comparison with the remainder of the population
  and the threshold sensitivity are computed from these exports.
