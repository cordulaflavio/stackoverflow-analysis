"""Q2: derived figures quoted in docs/question_2.md, recomputed from the exported CSV.

Purpose
    Reproduces the numbers in docs/question_2.md that are not a single cell of the export: the
    margins of error, the python decline from 2013 to 2021 and how many of its yearly changes
    exceed their margin, the dbt changes with their margins, answers per question, the answered
    share, the pooled 2020-2022 comparison and the gaps with self-accepted answers included.
    Each output section names the report section it backs.

Inputs
    - results/q2_python_dbt_by_year.csv (exported from rpt_q2_python_dbt_by_year): one row per
      tag and creation year, with the exact counts behind every rate.

Methods and assumptions
    - Rates are recomputed from the counts (no rounding before the subtraction).
    - Pooled 2020-2022 figures add the counts of the three years.
    - Margins are 95%, normal approximation: for a single rate, 1.96 * sqrt(p(1-p)/n); for a
      difference (a year-over-year change or the python vs dbt gap), the margin of the
      difference between two independent proportions. They are rough at 31-68 dbt questions.
    - Single-rate margins are reported for community acceptance, the main rate; change margins
      for both acceptance rates, since the report's ranges cover both.
    - Not covered: the whole-year 2022 counts (12,809 python, 79 dbt) and the share of single-tag
      questions come from queries/profiling/10_python_dbt_volume.sql; the dbt tag excerpt from
      queries/q2/01_dbt_like_tags.sql.

Run (from the repository root, Python 3.10+, standard library only)
    python scripts/q2/derived_statistics.py
    The output is a list of labelled values, not a pass/fail check: compare each line with the
    report section it names. scripts/q2/check_doc.py checks the report tables automatically.
"""
import csv
import math

counts = {}
for r in csv.DictReader(open("results/q2_python_dbt_by_year.csv", encoding="utf-8")):
    counts[(r["tag"], int(r["creation_year"]))] = {
        c: int(r[c])
        for c in ("total_questions", "total_answers", "answered_questions", "accepted_questions",
                  "community_accepted_questions")
    }
PYTHON_YEARS = range(2013, 2023)
DBT_YEARS = range(2020, 2023)


def pooled(tag, years):
    return {c: sum(counts[(tag, y)][c] for y in years) for c in counts[(tag, years[0])]}


def rate(row, column="community_accepted_questions"):
    return row[column] / row["total_questions"]


def margin(row, column="community_accepted_questions"):
    p = rate(row, column)
    return 1.96 * math.sqrt(p * (1 - p) / row["total_questions"]) * 100


def margin_of_difference(first, second, column="community_accepted_questions"):
    return math.sqrt(margin(first, column) ** 2 + margin(second, column) ** 2)


def pp(value):
    return f"{value * 100:.1f}%"


print("== Margin of error, single rate (Methodology) ==")
for tag, years in (("python", PYTHON_YEARS), ("dbt", DBT_YEARS)):
    margins = [margin(counts[(tag, y)]) for y in years]
    print(f"{tag}: +/-{min(margins):.1f} to +/-{max(margins):.1f} pp")

print("\n== Margin of error, year-over-year change (Methodology) ==")
for tag, years in (("python", PYTHON_YEARS), ("dbt", DBT_YEARS)):
    for column in ("community_accepted_questions", "accepted_questions"):
        margins = [margin_of_difference(counts[(tag, y)], counts[(tag, y - 1)], column)
                   for y in years[1:]]
        print(f"{tag}, {column}: +/-{min(margins):.1f} to +/-{max(margins):.1f} pp")

print("\n== Volume (Methodology) ==")
for tag, years in (("python", PYTHON_YEARS), ("dbt", DBT_YEARS)):
    print(f"{tag}: {pooled(tag, list(years))['total_questions']:,} questions, 2013-2022")

print("\n== python, 2013-2021 (Executive summary, Only python) ==")
first, last = counts[("python", 2013)], counts[("python", 2021)]
change = (rate(last) - rate(first)) * 100
print(f"community acceptance {pp(rate(first))} -> {pp(rate(last))}: {change:.1f} pp, "
      f"{change / 8:.1f} pp per year over 8 changes")
ratio_first = first["total_questions"] / first["total_answers"]
ratio_last = last["total_questions"] / last["total_answers"]
print(f"question-to-answer ratio {ratio_first:.2f} -> {ratio_last:.2f} "
      f"({(ratio_last / ratio_first - 1) * 100:+.0f}%); answers per question "
      f"{1 / ratio_first:.2f} -> {1 / ratio_last:.2f}")
beyond = 0
for year in range(2014, 2022):
    row, previous = counts[("python", year)], counts[("python", year - 1)]
    year_change = (rate(row) - rate(previous)) * 100
    year_margin = margin_of_difference(row, previous)
    beyond += year_change < -year_margin
    print(f"  {year}: {year_change:+.1f} pp, margin +/-{year_margin:.1f}")
print(f"declines larger than their margin: {beyond} of 8")
y2013, y2020 = counts[("python", 2013)], counts[("python", 2020)]
print(f"questions 2013 -> 2020: {y2013['total_questions']:,} -> {y2020['total_questions']:,}; "
      f"answers {y2013['total_answers']:,} -> {y2020['total_answers']:,} "
      f"({(y2020['total_answers'] / y2013['total_answers'] - 1) * 100:+.0f}%)")
for year in (2013, 2021, 2022):
    print(f"answered within 30 days, {year}: {pp(rate(counts[('python', year)], 'answered_questions'))}")
for year in range(2013, 2023):
    row = counts[("python", year)]
    gap = (rate(row, "accepted_questions") - rate(row)) * 100
    print(f"  {year}: accepted incl. self minus community = {gap:.1f} pp")

print("\n== dbt changes (Only dbt) ==")
for year in (2021, 2022):
    row, previous = counts[("dbt", year)], counts[("dbt", year - 1)]
    print(f"{year}: community {(rate(row) - rate(previous)) * 100:+.1f} pp, "
          f"margin +/-{margin_of_difference(row, previous):.0f}")
y2020 = counts[("dbt", 2020)]
self_accepted = y2020["accepted_questions"] - y2020["community_accepted_questions"]
print(f"2020: {self_accepted} of {y2020['accepted_questions']} accepted answers self-accepted")

print("\n== Answers per question (python vs dbt) ==")
for tag in ("python", "dbt"):
    values = [counts[(tag, y)]["total_answers"] / counts[(tag, y)]["total_questions"] for y in DBT_YEARS]
    print(f"{tag} 2020 / 2021 / 2022: " + " / ".join(f"{v:.2f}" for v in values))

print("\n== python vs dbt gaps (python vs dbt in the same years) ==")
for column, label in (("community_accepted_questions", "community"),
                      ("accepted_questions", "incl. self-accepted")):
    for years in ([2020], [2021], [2022], list(DBT_YEARS)):
        python, dbt = pooled("python", years), pooled("dbt", years)
        gap = (rate(python, column) - rate(dbt, column)) * 100
        gap_margin = margin_of_difference(python, dbt, column)
        name = "2020-2022 pooled" if len(years) > 1 else str(years[0])
        print(f"{label}, {name}: {pp(rate(python, column))} vs {pp(rate(dbt, column))}, "
              f"gap {gap:.1f} +/- {gap_margin:.1f} pp (lower end {gap - gap_margin:.1f})")
