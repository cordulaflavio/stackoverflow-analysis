"""Q3: check every table of docs/question_3.md against the exported CSV.

Purpose
    Guards the report against typos and stale numbers. It checks four tables:
    - the 2022 bucket tables (questions, share, answered and community-accepted rates);
    - "Which attributes separate most" (best-minus-worst gap, 2022 and 2013-2022 pooled);
    - the historical series (year-by-year contrasts and the overall acceptance row);
    - the robustness table (gap and margin per segment, 2022).
    Numbers quoted in the running text are not checked: derived_statistics.py prints them.

Inputs
    - results/q3_post_qualities.csv.
    - docs/question_3.md.

Assumptions
    - Rates are recomputed from the exact counts in the CSV; no rate is rebuilt from a rounded one.
    - Tolerance 0.05 pp, matching the one-decimal rounding of the report.
    - Margins: 95%, difference of two independent proportions, normal approximation.
    - The report's labels map to the CSV as written below (for example "1,000–1,999" to
      "1000-1999" and "00–05" to "00-05 UTC").

Run (from the repository root, Python 3.10+, standard library only)
    python scripts/q3/check_doc.py
    Prints any mismatching cell and the number of cells checked per table.
"""
import csv
import math

YEARS = range(2013, 2023)
TOLERANCE = 0.051
LABELS = {
    "Code blocks": "code_block_count",
    "Body length": "body_length",
    "Error report": "has_error_report",
    "Links": "link_count",
    "Images": "image_count",
    "Title length": "title_length",
    "Question mark in title": "title_has_question_mark",
    "Account age (days)": "asker_account_age_days",
    "Account age": "asker_account_age_days",
    "Tag count": "tag_count",
    "Hour": "created_hour_utc",
    "Hour (UTC)": "created_hour_utc",
    "Weekday": "created_weekday",
}
# Same order as the rows of the report tables.
HISTORICAL_CONTRASTS = [
    ("code_block_count", "2", "0"),
    ("asker_account_age_days", "31-365", "0"),
    ("body_length", "500-999", "4000+"),
    ("has_error_report", "false", "true"),
    ("title_has_question_mark", "true", "false"),
    ("image_count", "2+", "0"),
]
ROBUSTNESS_CONTRASTS = [
    ("code_block_count", "2", "0"),
    ("asker_account_age_days", "31-365", "0"),
    ("body_length", "500-999", "4000+"),
    ("has_error_report", "false", "true"),
    ("tag_count", "2", "5+"),
    ("title_length", "<40", "75+"),
    ("title_has_question_mark", "true", "false"),
    ("link_count", "0", "2+"),
    ("created_weekday", "Saturday", "Wednesday"),
    ("created_hour_utc", "18-23 UTC", "06-11 UTC"),
    ("image_count", "2+", "0"),
]

counts = {}
for r in csv.DictReader(open("results/q3_post_qualities.csv", encoding="utf-8")):
    counts[(r["segment"], int(r["creation_year"]), r["attribute"], r["bucket"])] = (
        int(r["total_questions"]), int(r["answered_questions"]), int(r["community_accepted_questions"])
    )
doc = open("docs/question_3.md", encoding="utf-8").read()


def number(text):
    return float(text.strip().strip("*").replace(",", "").replace("%", "").replace("−", "-"))


def table_rows(text):
    for line in text.splitlines():
        if line.startswith("| ") and "---" not in line:
            cells = [c.strip() for c in line.strip("|").split("|")]
            if cells[0] not in ("Attribute", "Contrast"):
                yield cells


def bucket_key(attribute, label):
    label = label.replace("–", "-").replace(",", "")
    return label + " UTC" if attribute == "created_hour_utc" else label


def rate(segment, years, attribute, bucket, which):
    n = k = 0
    for year in years:
        row = counts[(segment, year, attribute, bucket)]
        n, k = n + row[0], k + row[which]
    return k / n


def gap_with_margin(segment, attribute, first, second):
    n1, _, k1 = counts[(segment, 2022, attribute, first)]
    n2, _, k2 = counts[(segment, 2022, attribute, second)]
    p1, p2 = k1 / n1, k2 / n2
    return (p1 - p2) * 100, 1.96 * math.sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2) * 100


def best_minus_worst(attribute, years):
    buckets = {k[3] for k in counts if k[0] == "all" and k[2] == attribute and k[3] != "unknown"}
    rates = [rate("all", years, attribute, b, 2) for b in buckets]
    return (max(rates) - min(rates)) * 100


mismatches = 0


def check(label, got, expected):
    global mismatches
    if abs(got - expected) > TOLERANCE:
        mismatches += 1
        print(f"MISMATCH {label}: report {got} vs CSV {expected:.2f}")


# 1. 2022 bucket tables
part = doc.split("## 2022: post qualities and outcomes")[1].split("**Which attributes separate most.**")[0]
attribute, checked = None, 0
for cells in table_rows(part):
    attribute = LABELS[cells[0]] if cells[0] else attribute
    bucket = bucket_key(attribute, cells[1])
    n, answered, accepted = counts[("all", 2022, attribute, bucket)]
    total = sum(v[0] for k, v in counts.items() if k[:3] == ("all", 2022, attribute))
    check(f"{attribute} {bucket} questions", number(cells[2]), n)
    check(f"{attribute} {bucket} share", number(cells[3]), n / total * 100)
    check(f"{attribute} {bucket} answered", number(cells[4]), answered / n * 100)
    check(f"{attribute} {bucket} community", number(cells[5]), accepted / n * 100)
    checked += 4
print(f"2022 bucket tables: {checked} cells checked")

# 2. Best-minus-worst gaps
part = doc.split("**Which attributes separate most.**")[1].split("The answered rate")[0]
checked = 0
for cells in table_rows(part):
    attribute = LABELS[cells[0]]
    check(f"{attribute} gap 2022", number(cells[1].split()[0]), best_minus_worst(attribute, [2022]))
    check(f"{attribute} gap 2013-2022", number(cells[2].split()[0]), best_minus_worst(attribute, YEARS))
    checked += 2
print(f"attribute gaps: {checked} cells checked")

# 3. Historical series
part = doc.split("## Historical series, 2013–2022")[1].split("**Facts**")[0]
rows = list(table_rows(part))
checked = 0
for (attribute, first, second), cells in zip(HISTORICAL_CONTRASTS, rows):
    for i, year in enumerate(YEARS):
        expected = (rate("all", [year], attribute, first, 2) - rate("all", [year], attribute, second, 2)) * 100
        check(f"{attribute} {year}", number(cells[i + 1]), expected)
        checked += 1
base_cells = rows[len(HISTORICAL_CONTRASTS)]
for i, year in enumerate(YEARS):
    rows_year = [v for k, v in counts.items() if k[:3] == ("all", year, "code_block_count")]
    expected = sum(v[2] for v in rows_year) / sum(v[0] for v in rows_year) * 100
    check(f"overall community acceptance {year}", number(base_cells[i + 1]), expected)
    checked += 1
print(f"historical series: {checked} cells checked")

# 4. Robustness
part = doc.split("**2022, community-acceptance gap")[1].split("**Facts**")[0]
checked = 0
for (attribute, first, second), cells in zip(ROBUSTNESS_CONTRASTS, table_rows(part)):
    for j, segment in enumerate(("all", "never_edited", "python_only")):
        if cells[j + 1].startswith("n/a"):
            continue
        gap, margin = gap_with_margin(segment, attribute, first, second)
        reported_gap, reported_margin = (number(v) for v in cells[j + 1].split("±"))
        check(f"{attribute} {segment} gap", reported_gap, gap)
        check(f"{attribute} {segment} margin", reported_margin, margin)
        checked += 2
print(f"robustness: {checked} cells checked")

print(f"mismatches: {mismatches}")
