"""Q2: check every table of docs/question_2.md against the exported CSV.

Purpose
    Guards the report against typos and stale numbers. It checks three tables:
    - "Only python" (questions, answers, ratio, rates and their year-over-year changes);
    - "Only dbt" (the same, plus answered questions);
    - "python vs dbt in the same years" (questions, ratios, community acceptance and the gap
      with its margin, per year and pooled 2020-2022).
    Numbers quoted in the running text are not checked: derived_statistics.py prints them.

Inputs
    - results/q2_python_dbt_by_year.csv.
    - docs/question_2.md.

Assumptions
    - Ratios, rates and changes are recomputed from the exact counts in the CSV; no value is
      rebuilt from a rounded one.
    - Tolerances match the rounding of the report: 0.005 for ratios (2 decimals), 0.05 for
      percentages and percentage points (1 decimal).
    - Ratio change: relative change in %; rate change: difference in percentage points.
    - Margins: 95%, difference of two independent proportions, normal approximation.
    - The "2013-2019" row of the dbt table (no questions) and empty change cells are skipped.

Run (from the repository root, Python 3.10+, standard library only)
    python scripts/q2/check_doc.py
    Prints any mismatching cell and the number of cells checked per table.
"""
import csv
import math

RATIO_TOLERANCE = 0.0051
PCT_TOLERANCE = 0.051

counts = {}
for r in csv.DictReader(open("results/q2_python_dbt_by_year.csv", encoding="utf-8")):
    counts[(r["tag"], int(r["creation_year"]))] = {
        c: int(r[c])
        for c in ("total_questions", "total_answers", "answered_questions", "accepted_questions",
                  "community_accepted_questions")
    }
doc = open("docs/question_2.md", encoding="utf-8").read()


def number(text):
    return float(text.strip().strip("*").replace(",", "").replace("%", "").replace("−", "-"))


def table_rows(text):
    for line in text.splitlines():
        if line.startswith("| ") and "---" not in line:
            cells = [c.strip() for c in line.strip("|").split("|")]
            if cells[0] != "Year":
                yield cells


def pooled(tag, years):
    return {c: sum(counts[(tag, y)][c] for y in years) for c in counts[(tag, years[0])]}


def ratio(row):
    return row["total_questions"] / row["total_answers"]


def rate(row, column):
    return row[column] / row["total_questions"]


mismatches = 0


def check(label, got, expected, tolerance=PCT_TOLERANCE):
    global mismatches
    if abs(got - expected) > tolerance:
        mismatches += 1
        print(f"MISMATCH {label}: report {got} vs CSV {expected:.4f}")


def check_year_table(tag, part, has_answered):
    checked = 0
    for cells in table_rows(part):
        if "–" in cells[0]:
            continue
        year = int(cells[0][:4])
        row, previous = counts[(tag, year)], counts.get((tag, year - 1))
        values = cells[1:]
        check(f"{tag} {year} questions", number(values.pop(0)), row["total_questions"], 0)
        check(f"{tag} {year} answers", number(values.pop(0)), row["total_answers"], 0)
        checked += 2
        if has_answered:
            check(f"{tag} {year} answered", number(values.pop(0)), row["answered_questions"], 0)
            checked += 1
        ratio_cell, ratio_change_cell, community_cell, community_change_cell, accepted_cell, \
            accepted_change_cell = values
        check(f"{tag} {year} ratio", number(ratio_cell), ratio(row), RATIO_TOLERANCE)
        check(f"{tag} {year} community", number(community_cell),
              rate(row, "community_accepted_questions") * 100)
        check(f"{tag} {year} accepted", number(accepted_cell), rate(row, "accepted_questions") * 100)
        checked += 3
        if ratio_change_cell:
            check(f"{tag} {year} ratio change", number(ratio_change_cell),
                  (ratio(row) / ratio(previous) - 1) * 100)
            check(f"{tag} {year} community change", number(community_change_cell),
                  (rate(row, "community_accepted_questions")
                   - rate(previous, "community_accepted_questions")) * 100)
            check(f"{tag} {year} accepted change", number(accepted_change_cell),
                  (rate(row, "accepted_questions") - rate(previous, "accepted_questions")) * 100)
            checked += 3
    print(f"only {tag}: {checked} cells checked")


# 1. Only python
check_year_table("python", doc.split("## Only python")[1].split("**Facts**")[0], has_answered=False)

# 2. Only dbt
check_year_table("dbt", doc.split("## Only dbt")[1].split("**Facts**")[0], has_answered=True)

# 3. python vs dbt in the same years
part = doc.split("## python vs dbt in the same years")[1].split("**Facts**")[0]
checked = 0
for cells in table_rows(part):
    years = [2020, 2021, 2022] if "pooled" in cells[0] else [int(cells[0][:4])]
    python, dbt = pooled("python", years), pooled("dbt", years)
    label = cells[0]
    for j, (python_expected, dbt_expected, tolerance) in enumerate([
        (python["total_questions"], dbt["total_questions"], 0),
        (ratio(python), ratio(dbt), RATIO_TOLERANCE),
        (rate(python, "community_accepted_questions") * 100,
         rate(dbt, "community_accepted_questions") * 100, PCT_TOLERANCE),
    ]):
        python_cell, dbt_cell = cells[j + 1].split(" / ")
        check(f"{label} python column {j + 1}", number(python_cell), python_expected, tolerance)
        check(f"{label} dbt column {j + 1}", number(dbt_cell), dbt_expected, tolerance)
        checked += 2
    p1, n1 = rate(python, "community_accepted_questions"), python["total_questions"]
    p2, n2 = rate(dbt, "community_accepted_questions"), dbt["total_questions"]
    reported_gap, reported_margin = (number(v) for v in cells[4].split("±"))
    check(f"{label} gap", reported_gap, (p1 - p2) * 100)
    check(f"{label} margin", reported_margin,
          1.96 * math.sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2) * 100)
    checked += 2
print(f"python vs dbt: {checked} cells checked")

print(f"mismatches: {mismatches}")
