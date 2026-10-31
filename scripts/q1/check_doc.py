"""Q1: check every table row of docs/question_1.md that names a tag or combination against the CSVs.

Purpose
    Guards the report against typos and stale numbers. For each table row whose first cell is a
    tag or a combination present in the exports, it checks:
    - the number of questions;
    - every percentage (community acceptance, answered rate or self-accepted share);
    - every 95% Wilson interval on community acceptance;
    - every count (total answers or answered questions);
    - every plain decimal (answers per question).
    Rows whose first cell is not a tag or combination in the exports (the frequency-gradient
    tables, the threshold table, the metric definitions) are skipped: their numbers come from
    queries/q1/ or from derived_statistics.py.

Inputs
    - results/q1_tags.csv and results/q1_tag_combinations.csv.
    - docs/question_1.md.

Assumptions
    - k is rebuilt as round(community_accepted_rate * n), because the CSVs hold the rate (rounded
      to 4 decimals) and not the count. The rounding error is at most 0.00005 * n questions: exact
      for combinations (n <= 5,330), up to about 9 questions for the largest tag (python,
      179,625 questions), far below the one-decimal precision of the report.
    - Tolerances match the report's rounding: 0.05 pp for percentages, 0.005 for answers per question.

Run (from the repository root, Python 3.10+, standard library only)
    python scripts/q1/check_doc.py
    Prints any mismatching row and the total of rows checked.
"""
import csv
import math
import re

BAR = chr(92) + "|"  # escaped pipe inside markdown tables


def wilson(k, n, z=1.96):
    p = k / n
    c = (p + z * z / (2 * n)) / (1 + z * z / n)
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return c - h, c + h


data = {}
for f, key in [("results/q1_tags.csv", "tag"), ("results/q1_tag_combinations.csv", "tag_combination")]:
    for r in csv.DictReader(open(f, encoding="utf-8")):
        data[r[key]] = r

checked = bad = 0
for line in open("docs/question_1.md", encoding="utf-8"):
    line = line.strip()
    if not line.startswith("| ") or "---" in line:
        continue
    cells = [c.strip().replace("\0", "|") for c in line.replace(BAR, "\0").strip("|").split("|")]
    if cells[0] not in data:
        continue
    r = data[cells[0]]
    n = int(r["total_questions"])
    k = round(float(r["community_accepted_rate"]) * n)
    lo, hi = wilson(k, n)
    errs = []
    if int(cells[1].replace(",", "")) != n:
        errs.append("n")
    for c in cells[2:]:
        m = re.match(r"([\d.]+)% ?(?:\(([\d.]+)–([\d.]+)\))?$", c)
        if m:
            v = float(m.group(1))
            cands = [float(r[x]) * 100 for x in ("community_accepted_rate", "answered_question_rate", "self_accepted_share")]
            if not any(abs(v - cv) < 0.051 for cv in cands):
                errs.append("pct " + c)
            if m.group(2) and (abs(float(m.group(2)) - lo * 100) > 0.051 or abs(float(m.group(3)) - hi * 100) > 0.051):
                errs.append("ci " + c)
        elif re.match(r"^\d{1,3}(,\d{3})*$", c) and "," in c or (re.match(r"^\d+$", c) and "." not in c):
            if int(c.replace(",", "")) not in (int(r["total_answers"]), int(r["answered_questions"])):
                errs.append("count " + c)
        elif re.match(r"^[\d.]+$", c) and abs(float(c) - float(r["answers_per_question"])) > 0.0051:
            errs.append("apq " + c)
    checked += 1
    if errs:
        bad += 1
        print("MISMATCH", cells[0], errs)
print("table rows checked:", checked, "| mismatches:", bad)
