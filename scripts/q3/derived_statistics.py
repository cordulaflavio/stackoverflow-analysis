"""Q3: derived figures quoted in docs/question_3.md, recomputed from the exported CSV.

Purpose
    Reproduces the numbers in docs/question_3.md that are not a single cell of the export:
    the gap between the best and the worst bucket of each attribute, the year-by-year contrasts,
    the robustness gaps with their margins, the never-edited share per year and the smallest
    python-only buckets. Each output section names the report section it backs.

Inputs
    - results/q3_post_qualities.csv (exported from rpt_q3_post_qualities): one row per segment,
      creation year, attribute and bucket, with the exact counts behind both rates.

Methods and assumptions
    - Rates are recomputed from the counts (no rounding before the subtraction).
    - Pooled 2013-2022 figures add the counts of the ten years, so the larger years weigh more.
    - The 'unknown' account-age bucket is left out of the best-minus-worst gaps: it is a data
      limitation (deleted accounts), not an asker profile.
    - Margins are 95% margins of the difference between two independent proportions, normal
      approximation, as in Q2. They are rough for the small python-only buckets.
    - The population of a segment and year is the sum of the buckets of any one attribute
      (every attribute splits it completely; tests/assert_rpt_q3_buckets_reconcile.sql checks it).

Run (from the repository root, Python 3.10+, standard library only)
    python scripts/q3/derived_statistics.py
    The output is a list of labelled values, not a pass/fail check: compare each line with the
    report section it names. scripts/q3/check_doc.py checks the report tables automatically.
"""
import csv
import math
from collections import defaultdict

YEARS = range(2013, 2023)
ATTRIBUTES = [
    "code_block_count", "asker_account_age_days", "body_length", "has_error_report",
    "tag_count", "title_length", "title_has_question_mark", "created_weekday",
    "link_count", "created_hour_utc", "image_count",
]
# (attribute, first bucket, second bucket): gap = rate(first) - rate(second)
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

# counts[(segment, year, attribute, bucket)] = [questions, answered, community_accepted]
counts = {}
for r in csv.DictReader(open("results/q3_post_qualities.csv", encoding="utf-8")):
    counts[(r["segment"], int(r["creation_year"]), r["attribute"], r["bucket"])] = [
        int(r["total_questions"]), int(r["answered_questions"]), int(r["community_accepted_questions"])
    ]


def pooled(segment, attribute, bucket, years):
    total = [0, 0, 0]
    for year in years:
        for i, v in enumerate(counts.get((segment, year, attribute, bucket), [0, 0, 0])):
            total[i] += v
    return total


def community_rate(segment, attribute, bucket, years):
    n, _, accepted = pooled(segment, attribute, bucket, years)
    return accepted / n


def gap_with_margin(segment, attribute, first, second, years):
    n1, _, k1 = pooled(segment, attribute, first, years)
    n2, _, k2 = pooled(segment, attribute, second, years)
    p1, p2 = k1 / n1, k2 / n2
    margin = 1.96 * math.sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2)
    return (p1 - p2) * 100, margin * 100


def population(segment, year):
    rows = [v for k, v in counts.items() if k[0] == segment and k[1] == year and k[2] == "code_block_count"]
    return [sum(v[i] for v in rows) for i in range(3)]


def best_minus_worst(attribute, years):
    buckets = {k[3] for k in counts if k[0] == "all" and k[2] == attribute and k[3] != "unknown"}
    rates = [community_rate("all", attribute, b, years) for b in buckets]
    return (max(rates) - min(rates)) * 100


def section(title):
    print(f"\n=== {title}")


section("Methodology / 2022: populations and baselines")
for label, years in [("2022", [2022]), ("2013-2022", YEARS)]:
    n = a = c = 0
    for year in years:
        yn, ya, yc = population("all", year)
        n, a, c = n + yn, a + ya, c + yc
    print(f"{label}: {n:,} questions, answered {a / n:.1%}, community-accepted {c / n:.1%}")

section("2022: 'Which attributes separate most' (community acceptance, 'unknown' excluded)")
for attribute in ATTRIBUTES:
    print(f"  {attribute:<25} 2022 {best_minus_worst(attribute, [2022]):5.1f} pp | "
          f"2013-2022 pooled {best_minus_worst(attribute, YEARS):5.1f} pp")

section("Historical series: contrasts per year (community acceptance, pp)")
print(f"  {'contrast':<44}" + "".join(f"{y:>7}" for y in YEARS))
for attribute, first, second in HISTORICAL_CONTRASTS:
    gaps = [gap_with_margin("all", attribute, first, second, [y])[0] for y in YEARS]
    print(f"  {attribute + ' ' + first + ' vs ' + second:<44}" + "".join(f"{g:7.1f}" for g in gaps))
base = []
for year in YEARS:
    n, _, c = population("all", year)
    base.append(c / n * 100)
print(f"  {'community acceptance, all questions (%)':<44}" + "".join(f"{b:7.1f}" for b in base))
for year in (2013, 2022):
    with_code = community_rate("all", "code_block_count", "2", [year])
    no_code = community_rate("all", "code_block_count", "0", [year])
    print(f"  code 2 blocks vs none, {year}: {with_code:.1%} vs {no_code:.1%} = {with_code / no_code:.2f} times")

section("Robustness: 2022 community-acceptance gap +/- margin of the difference (pp)")
for attribute, first, second in ROBUSTNESS_CONTRASTS:
    cells = []
    for segment in ("all", "never_edited", "python_only"):
        if segment == "python_only" and attribute == "tag_count":
            cells.append("n/a (always 1 tag)")
            continue
        gap, margin = gap_with_margin(segment, attribute, first, second, [2022])
        cells.append(f"{gap:5.1f} +/- {margin:.1f}")
    print(f"  {attribute + ' ' + first + ' vs ' + second:<44} all {cells[0]} | never_edited {cells[1]} | "
          f"python_only {cells[2]}")

section("Robustness: never-edited share of all questions per year")
print("  " + ", ".join(f"{y}: {population('never_edited', y)[0] / population('all', y)[0]:.0%}" for y in YEARS))

section("Robustness: smallest python-only buckets")
small = sorted((v[0], k) for k, v in counts.items() if k[0] == "python_only")[:3]
for n, (_, year, attribute, bucket) in small:
    print(f"  {year} {attribute} {bucket}: {n} questions")
