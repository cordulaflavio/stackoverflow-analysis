# Cost

The project runs in a BigQuery sandbox with no billing account, so it can never generate a bill.
This page holds the limits it must respect, what the source costs to read, the decisions that
follow from both, and the measured cost of each build.

## Sandbox limits

| Limit | Value | Consequence |
|---|---|---|
| Queried bytes | 1 TB per month | every query is dry-run first, and the profile caps each query |
| Storage | 10 GB | the source is read in place, never copied |
| Table expiration | 60 days after each build (dataset default) | a table must be rebuilt within 60 days of its last build |
| Partition expiration | 60 days after the partition boundary | old-dated partitions would expire at once (see `fct_questions` below) |

## What the source costs to read

- BigQuery bills the bytes of the **columns** a query reads; a `limit` does not reduce them. Only a
  filter on a clustering or partitioning column can skip blocks. A dry-run is free and returns
  the estimate before anything runs.
- **`body` is 36 of the 40 GB of `posts_questions`** (`queries/profiling/01_table_metadata.sql`).
  Every other column of the table adds up to about 4 GB.

## Decisions

- **No ingestion.** dbt reads `bigquery-public-data.stackoverflow` in place. A copy would use a
  large part of the 10 GB storage and add nothing, because the snapshot is static.
- **`body` is read once.** `stg_question_body_features` is the only model that selects it. It is a
  table, built once with `dbt build --select tag:heavy`, and stores five numbers per question
  (0.94 GB). Routine runs skip it with `--exclude tag:heavy`.
- **Staging models are views.** They cost no storage; each query on them reads only the source
  columns it needs.
- **`fct_questions` is clustered by `creation_year`, not partitioned.**
  - **What clustering does:** a filter on `creation_year` lets BigQuery skip the blocks of other
    years. The 2022 report `rpt_q1_tags` is billed about 0.07 GB (72 MB in the dbt run results).
  - **Why not partitioning:**
    - **Size.** The table is 5.5 GB, about 0.4 GB per year on average. BigQuery suggests
      clustering instead of partitioning when partitions would hold less than approximately
      10 GB. This is a guideline, not a hard limit.
    - **Sandbox.** Partitions expire 60 days after the partition boundary. A table partitioned by
      question date would expire every partition from 2008 to 2022 immediately.
  - **Integer-range partitioning** on `creation_year` has no partition expiration, but it brings
    no benefit over clustering at this size.
- **`fct_questions` drops itself before a rebuild** (`pre_hook`). During a rebuild the old and the
  new table coexist, and together they exceed the 10 GB storage. The cost: if a build fails, the
  table is missing until the next successful build.
- **Each query is capped.** `maximum_bytes_billed` in the profile (50 GB in
  `profiles.yml.example`) makes any query that would read more fail before it runs. The largest
  build, the body features, reads about 36 GB.
- **Exports are free.** CSVs in `results/` are read from finished tables through the BigQuery API
  (`list_rows`), which bills no query bytes.

## Measured costs

Billed bytes come from the dbt run results or the BigQuery job, except where marked as a dry-run
estimate; storage comes from table metadata.

| Step | Billed | Stored |
|---|---|---|
| Profiling queries `queries/profiling/01–11` | about 9.7 GB in total | none |
| `stg_question_body_features` (one build) | 36.16 GB | 0.94 GB |
| `fct_questions` | about 6 GB per build | 5.5 GB |
| `rpt_q1_tags` + `rpt_q1_tag_combinations` | about 0.15 GB per build (dry-run estimate) | small |
| `rpt_q2_python_dbt_by_year` | about 1.07 GB per build | small |
| `rpt_q3_post_qualities` | about 2.45 GB per build (estimated, not measured) | small |

Total storage is about 6.5 GB, almost all of it `fct_questions` and the body features.
