"""Q1: draw the charts of docs/question_1.md from the exported CSVs.

Purpose
    Writes four PNG charts to docs/images/:
    - q1_tag_extremes.png: the 10 highest and 10 lowest tags by community acceptance, with
      95% Wilson intervals and the 2022 baseline;
    - q1_tag_scatter.png: the 792 tags, community acceptance against answers per question and
      against tag size, with the Spearman correlation of each pair;
    - q1_combination_extremes.png: the same as the first chart for the 174 combinations;
    - q1_frequency_gradient.png: community acceptance by how common a question's exact tag
      set is, with 95% Wilson intervals.

Inputs
    - results/q1_tags.csv and results/q1_tag_combinations.csv.
    - The frequency-gradient counts and the 2+ tag baseline, written below: no CSV holds them.
      They come from queries/q1/06_combination_frequency_gradient.sql (table A of the report).

Assumptions
    - The number of community-accepted questions is rebuilt as rate x questions, as in
      derived_statistics.py (the CSVs hold the rounded rate, not the count).
    - Spearman correlations use average ranks for ties, as in derived_statistics.py.
    - Needs matplotlib (requirements.txt); the other scripts use the standard library only.

Run (from the repository root)
    python scripts/q1/charts.py
    Prints the path of each chart written.
"""
import csv
import math
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT_DIR = "docs/images"
BASELINE_ALL = 0.272  # 2022 population, queries/q1/01_population_baseline.sql
BASELINE_2PLUS = 0.270  # 2022 questions with 2+ tags, same query
# Combination used by N questions: (label, questions, community-accepted questions)
GRADIENT = [
    ("200+", 106_793, 42_679),
    ("20–199", 121_468, 41_166),
    ("2–19", 247_087, 70_268),
    ("1 (unique)", 512_711, 112_850),
]
# Highlighted tags and their label offsets in points (python, javascript and reactjs sit close).
HIGHLIGHT = {"python": (6, 6), "javascript": (6, -4), "reactjs": (6, -13), "awk": (6, 4), "cordova": (6, 4)}

# Chart palette: two validated categorical slots on a light surface, ink and hairlines.
SURFACE, INK, INK_2, MUTED, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#898781", "#e1e0d9"
TOP, BOTTOM = "#2a78d6", "#eb6834"

plt.rcParams.update({
    "font.family": "sans-serif",
    "font.sans-serif": ["Segoe UI", "Helvetica", "Arial", "DejaVu Sans"],
    "font.size": 10,
    "axes.edgecolor": GRID,
    "axes.labelcolor": INK_2,
    "axes.titlecolor": INK,
    "xtick.color": MUTED,
    "ytick.color": INK_2,
    "figure.facecolor": SURFACE,
    "axes.facecolor": SURFACE,
    "savefig.facecolor": SURFACE,
})


def read(path, key):
    rows = []
    for r in csv.DictReader(open(path, encoding="utf-8")):
        n = int(r["total_questions"])
        rate = float(r["community_accepted_rate"])
        rows.append({
            "label": r[key],
            "n": n,
            "k": round(rate * n),
            "rate": rate,
            "apq": float(r["answers_per_question"]),
        })
    return rows


def wilson(k, n, z=1.96):
    p, d = k / n, 1 + z * z / n
    centre = (p + z * z / (2 * n)) / d
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return centre - half, centre + half


def ranks(values):
    order = sorted(range(len(values)), key=lambda i: values[i])
    result, i = [0.0] * len(values), 0
    while i < len(order):
        j = i
        while j + 1 < len(order) and values[order[j + 1]] == values[order[i]]:
            j += 1
        for m in range(i, j + 1):
            result[order[m]] = (i + j) / 2 + 1
        i = j + 1
    return result


def spearman(x, y):
    rx, ry = ranks(x), ranks(y)
    mx, my = sum(rx) / len(rx), sum(ry) / len(ry)
    sxy = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    return sxy / math.sqrt(sum((a - mx) ** 2 for a in rx) * sum((b - my) ** 2 for b in ry))


def clean_axes(ax, grid_axis):
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.grid(axis=grid_axis, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(length=0)


def percent_axis(axis):
    axis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: f"{v:.0%}"))


def save(fig, name):
    path = os.path.join(OUT_DIR, name)
    fig.savefig(path, dpi=200, bbox_inches="tight", pad_inches=0.25)
    plt.close(fig)
    print(path)


def extremes(rows, baseline, baseline_label, title, name):
    ordered = sorted(rows, key=lambda r: r["rate"], reverse=True)
    groups = [(ordered[:10], TOP), (ordered[-10:], BOTTOM)]
    fig, ax = plt.subplots(figsize=(8, 7), layout="constrained")
    y, ticks, labels = 0, [], []
    for group, color in groups:
        for r in group:
            lo, hi = wilson(r["k"], r["n"])
            ax.plot([lo, hi], [y, y], color=color, linewidth=2, alpha=0.5, solid_capstyle="round")
            ax.scatter([r["rate"]], [y], s=42, color=color, edgecolors=SURFACE, linewidths=1.5, zorder=3)
            ticks.append(y)
            labels.append(f"{r['label']}  ({r['n']:,})")
            y += 1
        y += 0.8
    ax.axvline(baseline, color=INK_2, linewidth=1.2)
    ax.text(baseline + 0.008, y - 1.2, baseline_label, color=INK_2, fontsize=9)
    ax.set_yticks(ticks, labels)
    ax.invert_yaxis()
    ax.set_xlim(0, 0.8)
    percent_axis(ax.xaxis)
    ax.set_xlabel("Community-accepted answer within 30 days (dot) and 95% Wilson interval (line)")
    clean_axes(ax, "x")
    fig.suptitle(title, x=0.02, ha="left", fontsize=12, fontweight="semibold", color=INK)
    save(fig, name)


def scatter(tags):
    rates = [r["rate"] for r in tags]
    panels = [
        ("apq", "Answers per question", False),
        ("n", "Questions in the tag (log scale)", True),
    ]
    fig, axes = plt.subplots(1, 2, figsize=(10, 4.6), sharey=True)
    for ax, (field, xlabel, log) in zip(axes, panels):
        xs = [r[field] for r in tags]
        rho = spearman([math.log10(v) for v in xs] if log else xs, rates)
        ax.scatter(xs, rates, s=10, color=TOP, alpha=0.35, linewidths=0)
        for r in tags:
            if r["label"] in HIGHLIGHT:
                ax.scatter([r[field]], [r["rate"]], s=36, color=BOTTOM, edgecolors=SURFACE, linewidths=1.5, zorder=3)
                dx, dy = HIGHLIGHT[r["label"]]
                # Labels of points near the right edge go to the left of the point.
                right_edge = log and r[field] > 50_000
                ax.annotate(r["label"], (r[field], r["rate"]), xytext=(-dx if right_edge else dx, dy),
                            textcoords="offset points", ha="right" if right_edge else "left",
                            fontsize=9, color=INK, fontweight="semibold")
        if log:
            ax.set_xscale("log")
            ax.xaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(
                lambda v, _: f"{v / 1000:g}K" if v >= 1000 else f"{v:g}"))
        ax.set_xlabel(xlabel)
        ax.set_title(f"Spearman {rho:.2f}", loc="left", fontsize=10.5, color=INK_2)
        clean_axes(ax, "both")
    percent_axis(axes[0].yaxis)
    axes[0].set_ylabel("Community-accepted answer within 30 days")
    fig.suptitle("792 tags: acceptance moves with answers per question, not with tag size",
                 x=0.07, ha="left", fontsize=12, fontweight="semibold", color=INK)
    save(fig, "q1_tag_scatter.png")


def gradient():
    fig, ax = plt.subplots(figsize=(8, 4.4))
    for i, (label, n, k) in enumerate(GRADIENT):
        rate = k / n
        lo, hi = wilson(k, n)
        ax.bar(i, rate, width=0.5, color=TOP)
        ax.plot([i, i], [lo, hi], color=INK, linewidth=1.2)
        ax.text(i, rate + 0.012, f"{rate:.1%}", ha="center", color=INK, fontweight="semibold")
    ax.axhline(BASELINE_2PLUS, color=INK_2, linewidth=1.2)
    ax.text(len(GRADIENT) - 0.55, BASELINE_2PLUS + 0.008, "2+ tag baseline: 27.0%", ha="right", color=INK_2, fontsize=9)
    ax.set_xticks(range(len(GRADIENT)), [f"{g[0]}\n{g[1]:,} questions" for g in GRADIENT])
    ax.set_ylim(0, 0.45)
    percent_axis(ax.yaxis)
    ax.set_xlabel("Exact tag set used by this many 2022 questions")
    ax.set_ylabel("Community-accepted answer within 30 days")
    clean_axes(ax, "y")
    ax.set_title("The more common a question's exact tag set, the more often it gets an accepted answer",
                 loc="left", fontsize=12, fontweight="semibold", pad=12)
    save(fig, "q1_frequency_gradient.png")


os.makedirs(OUT_DIR, exist_ok=True)
tags = read("results/q1_tags.csv", "tag")
combos = read("results/q1_tag_combinations.csv", "tag_combination")
extremes(tags, BASELINE_ALL, "2022 baseline: 27.2%",
         "Highest and lowest community acceptance, tags with 500+ questions (2022)", "q1_tag_extremes.png")
scatter(tags)
extremes(combos, BASELINE_2PLUS, "2+ tag baseline: 27.0%",
         "Highest and lowest community acceptance, combinations with 200+ questions (2022)",
         "q1_combination_extremes.png")
gradient()
