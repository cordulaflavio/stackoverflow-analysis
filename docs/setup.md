# Setup

How to reproduce the analysis. There are two levels:

- **No setup:** every answer is in `results/` (CSV) and `docs/question_N.md`. The model SQL is in
  `models/`, and the scripts in `scripts/q1/`, `scripts/q2/` and `scripts/q3/` need only Python
  and the CSVs.
- **Full rebuild:** dbt builds every table from the public dataset into your own BigQuery
  project. The steps below.

## Prerequisites

- **Python 3.11** (the scripts in `scripts/q1/`, `scripts/q2/` and `scripts/q3/` also run on 3.10+).
- **A GCP project with BigQuery.** A sandbox project, with no billing account, is enough: the
  full rebuild fits in the free quota ([cost.md](cost.md)).
- **A service account** in that project with the roles BigQuery Job User and BigQuery Data
  Editor, and a JSON key kept **outside the repo**. Reading
  `bigquery-public-data.stackoverflow` needs no extra role.

## 1. Python environment

```
python -m venv .venv
.venv\Scripts\activate.bat          # cmd;  bash: source .venv/bin/activate
pip install -r requirements.txt     # dbt-core and dbt-bigquery, pinned
```

## 2. dbt profile

1. Copy the `stackoverflow_analysis:` block of `profiles.yml.example` into `~/.dbt/profiles.yml`
   (create the file if it does not exist). The real profile never goes into the repo.
2. Set two environment variables (dbt does not read `.env` files):

   | Variable | Value |
   |---|---|
   | `DBT_KEYFILE` | path to the service account key |
   | `GCP_PROJECT_ID` | the project that runs the queries and holds the output datasets |

   ```
   set DBT_KEYFILE=C:\path\to\key.json             # cmd
   $env:DBT_KEYFILE = "C:\path\to\key.json"        # PowerShell
   export DBT_KEYFILE="$HOME/path/to/key.json"     # bash
   ```
3. Check the connection and install the dbt packages:

   ```
   dbt debug
   dbt deps
   ```

The profile caps every query at 50 GB (`maximum_bytes_billed`): a query that would read more
fails before it runs.

## 3. Build

Output datasets are created in location `US`, the same as the source: `dbt_dev_staging`,
`dbt_dev_marts` and `dbt_dev_reports`.

```
dbt build --select tag:heavy        # once: the body features table, reads `body` (about 36 GB)
dbt build --exclude tag:heavy       # everything else, with every test
```

The body features table is built once and reused; routine rebuilds skip it. The billed size of
each step is in [cost.md](cost.md).

**Sandbox expiration:** in a sandbox project every table expires 60 days after its last build.
After that, run the two builds again.

## 4. Export and check

```
python scripts/export_results.py    # rewrites results/*.csv from the report tables (no query billed)
python scripts/q1/check_doc.py      # checks the tables of docs/question_1.md against the CSVs
python scripts/q2/check_doc.py      # same for docs/question_2.md
python scripts/q3/check_doc.py      # same for docs/question_3.md
```

`export_results.py` reads the same `DBT_KEYFILE` and `GCP_PROJECT_ID` as the dbt profile. The
source is a static snapshot, so a rebuild should export the same CSVs as the committed ones;
`git diff results/` shows any difference.
