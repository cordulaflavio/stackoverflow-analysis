# CLAUDE.md — Take-Home Assignment: Stack Overflow Analysis

> Project conventions for Claude Code, loaded at the start of every session.
> Committed on purpose: it shows how AI was used to build this repo.

## Project Intent & Context
Take-home challenge (Newsela, Senior Analytics Engineering). It answers three questions about
Stack Overflow questions, using the public BigQuery dataset `bigquery-public-data.stackoverflow`:

- **Q1.** What tags on a Stack Overflow question lead to the most answers and the highest rate
  of approved answers for the current year? What tags lead to the least? How about
  combinations of tags?
- **Q2.** For posts which are tagged with only ‘python’ or ‘dbt’, what is the year over year change
  of question-to-answer ratio for the last 10 years? How about the rate of approved
  answers on questions for the same time period? How do posts tagged with only ‘python’
  compare to posts only tagged with ‘dbt’?
- **Q3.** Other than tags, what qualities on a post correlate with the highest rate of answer and
  approved answer? Feel free to get creative.

The submission is evaluated on:
- analytical reasoning and the ability to question one's own findings;
- the technical approach of the solutions (SQL structure, readability, performance);
- the ability to articulate assumptions, limitations and confidence levels;
- the data quality assessment and validation approach.

Local notes live in `_private/` (git-ignored).

## Language
The conversation may be in Portuguese or any other language. Everything in the repo is in English:
code, comments, YAML docs, README and commit messages.

## Roles
- **User:** makes every analytical decision.
- **Claude:** proposes and implements, and surfaces trade-offs, ambiguities and data quality
  issues. When a metric or filter is ambiguous, list the options, recommend one and wait for a
  decision; never pick a definition silently. Explain the *why*; one step at a time; keep answers short.
- **ChatGPT (external peer):** used by the user to question Claude's decisions.

### Reviewing output from ChatGPT or other AIs
1. **Critical review:** never accept a snippet or an idea because another AI suggested it. Check it
   against the code, the data and every guideline in this file (SQL, dbt, Python, analysis
   principles, cost rule).
2. **Evidence, not tone:** no praise and no dismissal. For each point, say whether it holds and why;
   if it shows that an earlier Claude decision was wrong, say so plainly.
3. **No silent rewrite:** propose the changes that hold; implement only what the user approves.

## 🛑 Critical Constraints for the AI
1. **Ask before acting:** nothing is created, changed or run without the user's explicit request.
   Propose, then wait; an unanswered proposal is not an approval.
2. **Never write incomplete code:** no placeholder comments like `# TODO: implement later` or
   `// ... rest of code`. Every change leaves the file complete and working.
3. **Simplicity first:** the minimum code that answers the question; no speculative abstractions.
4. **Do not modify existing working SQL/Python** unless explicitly asked to optimize or fix a bug in it.
   Make surgical, minimal changes, and match the existing style.
5. **Verify before claiming success:** define the check first (a test passes, a number reconciles).
   Claude runs the free checks itself (`dbt parse`, the matching `scripts/q*/check_doc.py`) and
   reports their actual output. Billed checks (`dbt build`, `dbt test`) follow the cost rule.
6. **Secrets:** never read, copy or display `~/.dbt/profiles.yml` or the service-account key file.

## Cost rule (mandatory)
- **Zero cost:** the project must never generate a bill. Limits, measured sizes and build costs:
  [docs/cost.md](docs/cost.md).
- Before running any query or billed dbt command, dry-run it, report the estimated bytes and wait
  for approval. A dry-run is not an approval.
- Select only the columns you need; never `select *` on a source table.
- Only `stg_question_body_features` reads `body`.

## Git
- Never commit without the user's explicit authorization. Claude may suggest commits and, once
  authorized, write them with a proper title and description.
- Before each commit, list the changed files for review.
- Before each commit, check the staged diff for anything that must not be public: passwords,
  tokens, keys, connection strings, personal data. If anything is found, stop and report it.
- Small, focused commits with conventional messages (`feat:`, `fix:`, `docs:`, `test:`, `chore:`).
- Commits use the identity in the local git config. End commit messages with
  `Co-Authored-By: Claude <noreply@anthropic.com>`. AI use is also described in the README
  ("How I used AI").
- One branch and one pull request per deliverable. The user creates branches and pushes.
- Never run `git push`.
- Never commit secrets, `profiles.yml`, `.env`, key files, `target/`, `logs/` or `dbt_packages/`.

## Build, Run & Test Commands
Run from the repository root with the virtual environment active (`.venv\Scripts\activate.bat` in cmd).
Full setup (profile, environment variables, build order): [docs/setup.md](docs/setup.md).

```
pip install -r requirements.txt     # dbt-core and dbt-bigquery, pinned
dbt deps                            # dbt_utils (packages.yml)
dbt debug                           # checks the profile and the connection
dbt parse                           # validates the project without querying BigQuery
dbt compile --select <model>        # writes the plain SQL to target/compiled/ without running it
dbt build --select <model>          # builds a model and runs its tests (billed)
dbt test --select <model>           # runs a model's tests only (billed)
python scripts/export_results.py    # exports every report table to results/ (free)
python scripts/q1/check_doc.py      # checks a question doc against its CSV (also scripts/q2/, scripts/q3/)
```
- Billed commands follow the cost rule above.
- `stg_question_body_features` (tag `heavy`) reads `body`. Add `--exclude tag:heavy` to any wider
  selection unless its rebuild is explicitly requested.

## Code Style & Architecture Guidelines
Strict constraints and patterns to follow when modifying this codebase.
- **Language & Frameworks:** BigQuery Standard SQL in dbt models (dbt-core 1.12, dbt-bigquery,
  dbt_utils); Python 3.11 in the virtual environment.
- **Pipeline:** source, read in place (no ingestion) → `stg_*` views → `fct_questions`, one row per
  question → one or more `rpt_q<N>_*` tables per question → CSV in `results/` → write-up in
  `docs/question_N.md`. Folder layout: [docs/architecture.md](docs/architecture.md).
- **SQL style:**
  - One CTE per logical step, named after what it contains; the final `select` reads from a named CTE.
  - Lowercase keywords, snake_case names, explicit column lists, explicit join types.
  - Rates use `safe_divide` and are always shown next to their denominator, so volume can be judged.
  - Report tables list counts first, then rates; rates are rounded to 4 decimals in a final CTE,
    after ranking, so rounding never creates ties.
  - Comments explain *why* (a definition, a filter, a caveat), not *what*.
  - Timestamps are UTC; derive years with `extract(year from ...)`.

## dbt Architecture Guidelines
- **Layers:** staging → marts → reports, with no intermediate layer: logic used by a single model
  stays in a CTE inside it.
- **Materialization:** staging as views, except `stg_question_body_features` (a table, the only
  model that reads `body`); marts and reports as tables.
- **`fct_questions`:** do not partition it, and keep its `pre_hook` (reasons in [docs/cost.md](docs/cost.md)).
- **Location:** output datasets stay in `US`, the same as the source.
- **Sources** are declared in `sources.yml`. No freshness check: the source is a static snapshot,
  and the singular test `assert_source_snapshot_unchanged` fails if it is ever refreshed.
- **Docs:** every model has a YAML entry with a description and column docs.
- **Tests:**
  - Primary keys get `unique` + `not_null`; foreign keys get `relationships`. Orphans found in the
    public dump use `severity: warn`, and the YAML documents how many.
  - Generic test parameters go under `arguments:`; the deprecated form is an error (`dbt_project.yml`).
  - Cross-table consistency checks are singular tests in `tests/`.

## Python & Data Engineering Guidelines
- Scripts in `scripts/q<N>/` use the standard library only and read only the CSVs in `results/`;
  they never query BigQuery. The one exception to the standard library is `charts.py`, which uses
  matplotlib (pinned in `requirements.txt`) and writes PNGs to `docs/images/`.
- Each script opens with a docstring: Purpose, Inputs, Assumptions (or Methods and assumptions), Run.
- Rates are recomputed from the exact counts, never from a rounded rate.
- CSV exports go through `scripts/export_results.py`, which reads finished tables with the BigQuery
  API (`list_rows`, free); never export through a query.
- Every query behind a finding is saved, commented, in `queries/<topic>/`.

## Analysis principles
- **Profile before modeling:** date ranges, nulls, duplicates and cross-table consistency. Record the findings.
- **Respect what is already known:** data issues in [docs/data_quality.md](docs/data_quality.md);
  platform rules (deletion, acceptance, editing) in [docs/stackoverflow_rules.md](docs/stackoverflow_rules.md).
- Every metric has a written definition: numerator, denominator, grain and filters.
- Apply and state a minimum-volume threshold before ranking anything.
- Watch for **right-censoring** (recent questions had less time to get answers) and **survivorship**
  (deleted posts are not in the dump).
- Separate attributes known **at posting time** from those observed **later** (score, views, current
  reputation). Correlation is not causation.
- Every result states its assumptions, limitations and confidence level.
