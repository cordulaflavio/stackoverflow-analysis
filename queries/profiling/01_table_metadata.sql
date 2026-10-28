-- Size and freshness of every table in the dataset.
-- __TABLES__ is catalog metadata: it scans no table data, so it is free.
select
    table_id,
    row_count,
    round(size_bytes / pow(10, 9), 2) as size_gb,
    date(timestamp_millis(last_modified_time)) as last_modified_date
from `bigquery-public-data.stackoverflow.__TABLES__`
order by size_bytes desc
