"""Q2: draw the charts of docs/question_2.md from the exported CSV.

Purpose
    Writes three PNG charts to docs/images/:
    - q2_ratio_by_year.png: the question-to-answer ratio per year, python-only and dbt-only;
    - q2_acceptance_by_year.png: community acceptance per year, python-only with its 95% margin
      as a band and dbt-only with its 95% margin as error bars;
    - q2_python_changes.png: the year-over-year change of python-only community acceptance, with
      the 95% margin of each change; changes within their margin are drawn lighter.

Inputs
    - results/q2_python_dbt_by_year.csv (exported from rpt_q2_python_dbt_by_year).

Assumptions
    - Ratios and rates are recomputed from the exact counts in the CSV.
    - Margins are 95%, normal approximation, as in derived_statistics.py: for a rate,
      1.96 * sqrt(p(1-p)/n); for a change, the margin of the difference between two
      independent proportions.
    - 2022 is a partial year (January to ~2022-08-26) and is drawn with a hollow marker.
    - Needs matplotlib (requirements.txt); the other scripts use the standard library only.

Run (from the repository root)
    python scripts/q2/charts.py
    Prints the path of each chart written.
"""
import csv
import math
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT_DIR = "docs/images"
YEARS = list(range(2013, 2023))

# Chart palette: two validated categorical slots on a light surface, ink and hairlines.
SURFACE, INK, INK_2, MUTED, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#898781", "#e1e0d9"
PYTHON, DBT = "#2a78d6", "#eb6834"

plt.rcParams.update({
    "font.family": "sans-serif",
    "font.sans-serif": ["Segoe UI", "Helvetica", "Arial", "DejaVu Sans"],
    "font.size": 10,
    "axes.edgecolor": GRID,
    "axes.labelcolor": INK_2,
    "axes.titlecolor": INK,
    "xtick.color": MUTED,
    "ytick.color": MUTED,
    "figure.facecolor": SURFACE,
    "axes.facecolor": SURFACE,
    "savefig.facecolor": SURFACE,
})

counts = {}
for r in csv.DictReader(open("results/q2_python_dbt_by_year.csv", encoding="utf-8")):
    counts[(r["tag"], int(r["creation_year"]))] = {
        c: int(r[c]) for c in ("total_questions", "total_answers", "community_accepted_questions")
    }


def rate(row):
    return row["community_accepted_questions"] / row["total_questions"]


def margin(row):
    p = rate(row)
    return 1.96 * math.sqrt(p * (1 - p) / row["total_questions"])


def years_with_questions(tag):
    return [y for y in YEARS if counts[(tag, y)]["total_questions"] > 0]


def clean_axes(ax):
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.grid(axis="y", color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(length=0)
    ax.set_xticks(YEARS, [str(y) if y < 2022 else "2022\n(partial)" for y in YEARS])


def markers(ax, xs, ys, color):
    # Full years filled, the partial 2022 hollow.
    for x, y in zip(xs, ys):
        partial = x == 2022
        ax.scatter([x], [y], s=40, zorder=3, color=SURFACE if partial else color,
                   edgecolors=color if partial else SURFACE, linewidths=1.8)


def end_label(ax, x, y, text):
    ax.annotate(text, (x, y), xytext=(10, 0), textcoords="offset points", va="center",
                fontsize=9.5, color=INK, fontweight="semibold")


def save(fig, name):
    path = os.path.join(OUT_DIR, name)
    fig.savefig(path, dpi=200, bbox_inches="tight", pad_inches=0.25)
    plt.close(fig)
    print(path)


def ratio_chart():
    fig, ax = plt.subplots(figsize=(8, 4.4), layout="constrained")
    for tag, color in (("python", PYTHON), ("dbt", DBT)):
        xs = years_with_questions(tag)
        ys = [counts[(tag, y)]["total_questions"] / counts[(tag, y)]["total_answers"] for y in xs]
        ax.plot(xs, ys, color=color, linewidth=2, solid_capstyle="round", solid_joinstyle="round")
        markers(ax, xs, ys, color)
        end_label(ax, xs[-1], ys[-1], f"{tag}-only {ys[-1]:.2f}")
    ax.set_ylim(0, 1.2)
    ax.set_xlim(2012.6, 2023.2)
    ax.set_ylabel("Questions per answer within 30 days")
    clean_axes(ax)
    fig.suptitle("Question-to-answer ratio: higher means fewer answers for each question",
                 x=0.02, ha="left", fontsize=12, fontweight="semibold", color=INK)
    save(fig, "q2_ratio_by_year.png")


def acceptance_chart():
    fig, ax = plt.subplots(figsize=(8, 4.6), layout="constrained")
    xs = years_with_questions("python")
    rows = [counts[("python", y)] for y in xs]
    ys = [rate(r) for r in rows]
    ax.fill_between(xs, [y - margin(r) for y, r in zip(ys, rows)], [y + margin(r) for y, r in zip(ys, rows)],
                    color=PYTHON, alpha=0.15, linewidth=0)
    ax.plot(xs, ys, color=PYTHON, linewidth=2)
    markers(ax, xs, ys, PYTHON)
    end_label(ax, xs[-1], ys[-1], f"python-only {ys[-1]:.1%}")

    xs = years_with_questions("dbt")
    rows = [counts[("dbt", y)] for y in xs]
    ys = [rate(r) for r in rows]
    ax.errorbar(xs, ys, yerr=[margin(r) for r in rows], fmt="none", ecolor=DBT, elinewidth=2,
                capsize=5, capthick=2, alpha=0.6)
    ax.plot(xs, ys, color=DBT, linewidth=2)
    markers(ax, xs, ys, DBT)
    end_label(ax, xs[-1], ys[-1], f"dbt-only {ys[-1]:.1%}")

    ax.set_ylim(0, 0.75)
    ax.set_xlim(2012.6, 2023.4)
    ax.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: f"{v:.0%}"))
    ax.set_ylabel("Community-accepted answer within 30 days")
    clean_axes(ax)
    fig.suptitle("Community acceptance per year, with 95% margins (band: python-only; bars: dbt-only)",
                 x=0.02, ha="left", fontsize=12, fontweight="semibold", color=INK)
    save(fig, "q2_acceptance_by_year.png")


def changes_chart():
    fig, ax = plt.subplots(figsize=(8, 4.2), layout="constrained")
    for year in YEARS[1:]:
        before, after = counts[("python", year - 1)], counts[("python", year)]
        change = (rate(after) - rate(before)) * 100
        change_margin = math.sqrt(margin(before) ** 2 + margin(after) ** 2) * 100
        beyond = abs(change) > change_margin
        ax.bar(year, change, width=0.5, color=PYTHON, alpha=1 if beyond else 0.4)
        ax.plot([year, year], [change - change_margin, change + change_margin], color=INK, linewidth=1.2)
        label_y = change - change_margin - 0.25 if change < 0 else change + change_margin + 0.25
        ax.text(year, label_y, f"{change:+.1f}".replace("-", "−"), ha="center",
                va="top" if change < 0 else "bottom", fontsize=9.5, color=INK, fontweight="semibold")
    ax.axhline(0, color=INK_2, linewidth=1)
    ax.set_ylim(-8.5, 2)
    ax.set_xlim(2013.4, 2022.6)
    ax.set_ylabel("Change from the previous year (pp)")
    clean_axes(ax)
    ax.set_xticks(YEARS[1:], [str(y) if y < 2022 else "2022\n(partial)" for y in YEARS[1:]])
    fig.suptitle("python-only: yearly change in community acceptance (lighter bars: within the 95% margin)",
                 x=0.02, ha="left", fontsize=12, fontweight="semibold", color=INK)
    save(fig, "q2_python_changes.png")


os.makedirs(OUT_DIR, exist_ok=True)
ratio_chart()
acceptance_chart()
changes_chart()
