"""Q1: compare each tag combination with the rest of the 2+ tag population.

Purpose
    Backs the "Comparison with the rest of the population" result in docs/question_1.md:
    99 combinations significantly above the rest, 11 below, 64 not distinguishable.

Method
    A combination is a subset of the population, so comparing its interval with the population
    rate is not a test between independent groups. Each combination (n, k) is compared with the
    disjoint remainder (N - n, K - k) using a two-sided two-proportion z-test with a pooled
    standard error, and Holm step-down correction for the 174 simultaneous tests at alpha = 0.05.

Inputs
    - results/q1_tag_combinations.csv (exported from rpt_q1_tag_combinations).
    - Population totals, hard-coded below because no CSV holds them:
        N = 988,059 questions with 2+ tags (2022, complete 30-day window)
        K = 266,963 of them with a community-accepted answer within 30 days
      Both are the sums of the four frequency bands returned by
      queries/q1/06_combination_frequency_gradient.sql, shown in table A of docs/question_1.md
      ("Combination frequency gradient").

Assumptions
    - k is rebuilt as round(community_accepted_rate * n), because the CSV holds the rate (rounded
      to 4 decimals) and not the count. The assert checks the rebuilt k reproduces the rate; with
      at most 5,330 questions per combination, the rebuild is exact.
    - Questions are independent observations.

Run (from the repository root, Python 3.10+, standard library only)
    python scripts/q1/compare_with_rest.py results/q1_tag_combinations.csv
"""
import csv
import math
import sys

N_POP = 106793 + 121468 + 247087 + 512711
K_POP = 42679 + 41166 + 70268 + 112850
ALPHA = 0.05

path = sys.argv[1]
rows = list(csv.DictReader(open(path, encoding="utf-8")))


def p_two_sided(z):
    return math.erfc(abs(z) / math.sqrt(2))


tests = []
for r in rows:
    n = int(r["total_questions"])
    rate = float(r["community_accepted_rate"])
    k = round(rate * n)
    assert abs(k / n - rate) < 0.00006, r["tag_combination"]
    n_rest, k_rest = N_POP - n, K_POP - k
    p1, p2 = k / n, k_rest / n_rest
    pooled = (k + k_rest) / (n + n_rest)
    se = math.sqrt(pooled * (1 - pooled) * (1 / n + 1 / n_rest))
    z = (p1 - p2) / se
    tests.append({"combo": r["tag_combination"], "n": n, "k": k, "p": p1, "rest": p2,
                  "z": z, "pval": p_two_sided(z)})

# Holm step-down correction
m = len(tests)
ordered = sorted(tests, key=lambda t: t["pval"])
running_max = 0.0
for i, t in enumerate(ordered):
    adj = min(1.0, (m - i) * t["pval"])
    running_max = max(running_max, adj)
    t["p_holm"] = running_max

print(f"population: N={N_POP:,} K={K_POP:,} rate={K_POP / N_POP:.4f}")
print(f"rest rate range: {min(t['rest'] for t in tests):.4f} - {max(t['rest'] for t in tests):.4f}")
for label, key in [("unadjusted", "pval"), ("Holm", "p_holm")]:
    above = sum(1 for t in tests if t[key] < ALPHA and t["z"] > 0)
    below = sum(1 for t in tests if t[key] < ALPHA and t["z"] < 0)
    print(f"{label:<11} above={above} below={below} not distinguishable={m - above - below}")
print("\nsignificantly below the rest (Holm):")
for t in sorted((t for t in tests if t["p_holm"] < ALPHA and t["z"] < 0), key=lambda t: t["p"]):
    print(f"  {t['combo']:<38} n={t['n']:>5} {t['p']:.3f} vs rest {t['rest']:.4f}  p_holm={t['p_holm']:.1e}")
print("\nlost significance after Holm:")
for t in tests:
    if t["pval"] < ALPHA <= t["p_holm"]:
        print(f"  {t['combo']:<38} n={t['n']:>5} {t['p']:.3f} z={t['z']:+.2f}")
