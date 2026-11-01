"""Export every report table to results/ as CSV, with no query billed.

Purpose
    Regenerates the CSVs in results/ from the report tables built by dbt. Rows are read with the
    BigQuery API (`list_rows`, the tabledata.list method), which bills no query bytes, so an
    export costs nothing against the 1 TB monthly quota.

Inputs
    - The report tables in the dataset REPORTS_DATASET of the project GCP_PROJECT_ID.
    - Environment variables, the same ones the dbt profile reads (see profiles.yml.example):
        DBT_KEYFILE     path to the service account key, kept outside the repo
        GCP_PROJECT_ID  the GCP project that holds the output datasets

Assumptions
    - REPORTS_DATASET is the dataset dbt writes the reports to: the profile dataset `dbt_dev`
      plus the `reports` schema set in dbt_project.yml.
    - Rows are sorted by the columns listed in EXPORTS, so a re-export of an unchanged table
      gives an identical file. Booleans are written in lowercase, floats with 4 decimals (the
      report tables already round to 4), nulls as empty cells.
    - google-cloud-bigquery is installed with dbt-bigquery (requirements.txt).

Run (from the repository root)
    python scripts/export_results.py
    Prints one line per table with the number of rows written.
"""
import csv
import os
import warnings

warnings.filterwarnings("ignore", category=FutureWarning)

from google.cloud import bigquery
from google.oauth2 import service_account

REPORTS_DATASET = "dbt_dev_reports"
# table: (output file, sort columns)
EXPORTS = {
    "rpt_q1_tags": ("results/q1_tags.csv", ["rank_answers", "tag"]),
    "rpt_q1_tag_combinations": ("results/q1_tag_combinations.csv", ["rank_answers", "tag_combination"]),
    "rpt_q2_python_dbt_by_year": ("results/q2_python_dbt_by_year.csv", ["tag", "creation_year"]),
    "rpt_q3_post_qualities": (
        "results/q3_post_qualities.csv",
        ["segment", "creation_year", "attribute", "bucket_order"],
    ),
}


def fmt(value):
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, float):
        return f"{value:.4f}"
    return value


project = os.environ["GCP_PROJECT_ID"]
credentials = service_account.Credentials.from_service_account_file(os.environ["DBT_KEYFILE"])
client = bigquery.Client(project=project, credentials=credentials, location="US")

for table_name, (out_path, sort_columns) in EXPORTS.items():
    table = client.get_table(f"{project}.{REPORTS_DATASET}.{table_name}")
    rows = [dict(row.items()) for row in client.list_rows(table)]
    rows.sort(key=lambda row: tuple(row[c] for c in sort_columns))
    columns = [field.name for field in table.schema]
    with open(out_path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh, lineterminator="\n")
        writer.writerow(columns)
        for row in rows:
            writer.writerow([fmt(row[c]) for c in columns])
    print(f"{table_name}: {len(rows)} rows -> {out_path}")
