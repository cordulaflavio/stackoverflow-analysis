"""Q1: derived statistics quoted in docs/question_1.md, recomputed from the exported CSVs.

Purpose
    Reproduces the numbers in docs/question_1.md that come from the exports rather than from a
    table cell: interval widths, the separation between top and bottom groups, rank
    correlations, threshold sensitivity, the effect of self-acceptance on ranks and the
    combination coverage. Each output line names the section of the report it backs.
    The comparison with the rest of the population (Holm) is in compare_with_rest.py.

Inputs
    - results/q1_tags.csv (792 tags with 500+ questions).
    - results/q1_tag_combinations.csv (174 combinations with 200+ questions).
    - QUESTIONS_2PLUS = 988,059, the 2022 questions with 2+ tags and a complete 30-day window,
      hard-coded because no CSV holds it. It is the sum of the four frequency bands returned by
      queries/q1/06_combination_frequency_gradient.sql (table A of docs/question_1.md).

Methods and assumptions
    - Intervals: 95% Wilson score intervals on community_accepted_rate, with
      k = round(community_accepted_rate * n), because the CSVs hold the rate (4 decimals), not
      the count. The rounding error is at most 0.00005 * n questions: exact for combinations
      (n <= 5,330), up to about 9 questions for the largest tag (python, 179,625 questions), far
      below the one-decimal precision of the report.
    - Rank correlations: Spearman, computed as the Pearson correlation of average ranks (ties
      share the mean of their positions).
    - The two steps of acceptance (answered rate and community acceptance among answered
      questions) were correlated with Pearson on the rates, as originally computed; Spearman is
      printed next to it.
    - Medians use statistics.median.

Run (from the repository root, Python 3.10+, standard library only)
    python scripts/q1/derived_statistics.py
    The output is a list of labelled values, not a pass/fail check: compare each line with the
    report section it names.
"""
import csv
import math
import statistics as st
from collections import Counter

QUESTIONS_2PLUS = 106793 + 121468 + 247087 + 512711


def wilson(k, n, z=1.96):
    p = k / n
    c = (p + z * z / (2 * n)) / (1 + z * z / n)
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return c - h, c + h


def average_ranks(xs):
    s = sorted(range(len(xs)), key=lambda i: xs[i])
    r = [0] * len(xs)
    i = 0
    while i < len(s):
        j = i
        while j + 1 < len(s) and xs[s[j + 1]] == xs[s[i]]:
            j += 1
        for t in range(i, j + 1):
            r[s[t]] = (i + j) / 2 + 1
        i = j + 1
    return r


def spearman(rows, a, b):
    return st.correlation(average_ranks([r[a] for r in rows]), average_ranks([r[b] for r in rows]))


def load(path, key):
    rows = list(csv.DictReader(open(path, encoding="utf-8")))
    for r in rows:
        r["key"] = r[key]
        for c in ("total_questions", "total_answers", "answered_questions",
                  "rank_community_accepted", "rank_if_self_accepted_counted"):
            r[c] = int(r[c])
        for c in ("answers_per_question", "answered_question_rate", "accepted_rate",
                  "community_accepted_rate", "community_acceptance_rate_answered",
                  "self_accepted_share", "median_hours_to_first_answer"):
            r[c] = float(r[c])
        r["n"] = r["total_questions"]
        r["k"] = round(r["community_accepted_rate"] * r["n"])
        r["lo"], r["hi"] = wilson(r["k"], r["n"])
        r["half_width_pp"] = (r["hi"] - r["lo"]) / 2 * 100
    return rows


def pct(x):
    return f"{x * 100:.1f}%"


def section(title):
    print(f"\n=== {title}")


def separation(rows, label):
    """Top 10 / bottom 10 by community acceptance: bounds and overlap with the first interval."""
    s = sorted(rows, key=lambda r: -r["community_accepted_rate"])
    top, bottom = s[:10], s[-10:]
    print(f"{label}: lowest lower bound among the top 10 = {pct(min(r['lo'] for r in top))}")
    print(f"{label}: highest upper bound among the bottom 10 = {pct(max(r['hi'] for r in bottom))}")
    overlap = sum(1 for r in top[1:] if r["hi"] >= top[0]["lo"])
    print(f"{label}: positions 2-10 whose interval overlaps position 1: {overlap} of 9")


def half_widths(rows, label):
    hw = [r["half_width_pp"] for r in rows]
    print(f"{label}: Wilson half-width median +/-{st.median(hw):.1f} pp, max +/-{max(hw):.1f} pp")


tags = load("results/q1_tags.csv", "tag")
combos = load("results/q1_tag_combinations.csv", "tag_combination")

# ---------------------------------------------------------------- tags
section("Tags: 'Grouping and minimum volume' and 'Statistical confidence'")
print(f"tags: {len(tags)}")
half_widths(tags, "tags")
separation(tags, "tags")

section("Tags: 'Further observations' (Spearman across tags)")
for a, b in [("answers_per_question", "community_accepted_rate"),
             ("total_answers", "community_accepted_rate"),
             ("community_accepted_rate", "self_accepted_share"),
             ("community_accepted_rate", "median_hours_to_first_answer")]:
    print(f"{a} x {b}: {spearman(tags, a, b):.2f}")

section("Tags: 'Reading the total-answers tables' and 'Executive summary'")
print(f"total_answers x total_questions (Spearman): {spearman(tags, 'total_answers', 'total_questions'):.2f}")
print(f"total_questions x community_accepted_rate (Spearman): "
      f"{spearman(tags, 'total_questions', 'community_accepted_rate'):.2f}")
fewest = sorted(tags, key=lambda r: r["total_answers"])[:5]
print("fewest total answers: questions "
      f"{min(r['n'] for r in fewest)}-{max(r['n'] for r in fewest)}, answers per question "
      f"{min(r['answers_per_question'] for r in fewest):.2f}-{max(r['answers_per_question'] for r in fewest):.2f}, "
      f"community-acceptance rank {min(r['rank_community_accepted'] for r in fewest)}-"
      f"{max(r['rank_community_accepted'] for r in fewest)} of {len(tags)}")

section("Tags: 'Two steps of acceptance'")
a = [r["answered_question_rate"] for r in tags]
b = [r["community_acceptance_rate_answered"] for r in tags]
print(f"answered rate x community acceptance among answered: Pearson {st.correlation(a, b):.2f}, "
      f"Spearman {spearman(tags, 'answered_question_rate', 'community_acceptance_rate_answered'):.2f}")

section("Tags: 'Size is not success' (largest tags)")
for r in sorted(tags, key=lambda r: -r["n"])[:8]:
    print(f"  {r['key']:<12} n={r['n']:>7,} community {pct(r['community_accepted_rate'])} "
          f"rank {r['rank_community_accepted']}")

section("Tags: 'Self-acceptance changes little at the extremes'")
moves = [abs(r["rank_community_accepted"] - r["rank_if_self_accepted_counted"]) for r in tags]
print(f"rank move when self-accepted answers count: median {st.median(moves)}, max {max(moves)}")
for r in sorted(tags, key=lambda r: -abs(r["rank_community_accepted"] - r["rank_if_self_accepted_counted"]))[:5]:
    print(f"  {r['key']:<22} {r['rank_community_accepted']} -> {r['rank_if_self_accepted_counted']}")

section("Tags: 'Stability across thresholds'")
for threshold in (1000, 2000):
    sub = [r for r in tags if r["n"] >= threshold]
    s = sorted(sub, key=lambda r: -r["community_accepted_rate"])
    print(f">= {threshold}: {len(sub)} tags")
    print(f"  top 8:    {[r['key'] for r in s[:8]]}")
    print(f"  bottom 8: {[r['key'] for r in s[::-1][:8]]}")

# ---------------------------------------------------------------- combinations
section("Combinations: 'Coverage'")
covered = sum(r["n"] for r in combos)
print(f"combinations: {len(combos)}, questions covered: {covered:,} "
      f"({covered / QUESTIONS_2PLUS * 100:.1f}% of {QUESTIONS_2PLUS:,} questions with 2+ tags)")
print(f"by tag count: {dict(sorted(Counter(int(r['tag_count']) for r in combos).items()))}")

section("Combinations: 'Why 200 questions' (200+ vs 500+)")
for threshold in (200, 500):
    sub = [r for r in combos if r["n"] >= threshold]
    hw = [r["half_width_pp"] for r in sub]
    q = sum(r["n"] for r in sub)
    print(f"{threshold}+: combinations {len(sub)}, by tag count "
          f"{dict(sorted(Counter(int(r['tag_count']) for r in sub).items()))}, questions {q:,} "
          f"({q / QUESTIONS_2PLUS * 100:.1f}%), answers {sum(r['total_answers'] for r in sub):,}, "
          f"median questions {st.median(r['n'] for r in sub)}, half-width median +/-{st.median(hw):.1f} pp, "
          f"max +/-{max(hw):.1f} pp")

section("Combinations: 'Grouping and minimum volume' and 'Statistical confidence'")
half_widths(combos, "combinations")
separation(combos, "combinations")

section("Combinations: Spearman across the 174 combinations")
for x, y in [("answers_per_question", "community_accepted_rate"),
             ("total_answers", "total_questions"),
             ("total_answers", "community_accepted_rate")]:
    print(f"{x} x {y}: {spearman(combos, x, y):.2f}")

section("Combinations: 'Sensitivity to the minimum volume (200 vs 500)'")
s200 = sorted(combos, key=lambda r: -r["community_accepted_rate"])
print(f"of the 10 lowest at 200+, combinations with 500+ questions: {sum(1 for r in s200[-10:] if r['n'] >= 500)}")
c500 = sorted((r for r in combos if r["n"] >= 500), key=lambda r: -r["community_accepted_rate"])
print("500+ top 6:", [(r["key"], pct(r["community_accepted_rate"])) for r in c500[:6]])
print("500+ bottom 4:", [(r["key"], pct(r["community_accepted_rate"]), pct(r["lo"]), pct(r["hi"]))
                         for r in c500[::-1][:4]])

section("Combinations: 'Within one language' (python)")
py = [r for r in combos if "python" in r["key"].split("|")]
low = min(py, key=lambda r: r["community_accepted_rate"])
high = max(py, key=lambda r: r["community_accepted_rate"])
python_tag = next(r for r in tags if r["key"] == "python")
print(f"python combinations: {len(py)}, from {pct(low['community_accepted_rate'])} ({low['key']}) "
      f"to {pct(high['community_accepted_rate'])} ({high['key']}); python tag "
      f"{pct(python_tag['community_accepted_rate'])}")
