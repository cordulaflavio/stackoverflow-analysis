"""Q3: draw the charts of docs/question_3.md from the exported CSV.

Purpose
    Writes three PNG charts to docs/images/:
    - q3_main_attributes_2022.png: community acceptance per bucket of the four attributes with
      the largest gaps (code blocks, account age, body length, error report), 2022, against the
      2022 baseline;
    - q3_attribute_gaps.png: the gap between the best and the worst bucket of each attribute,
      2022 (bar) and 2013-2022 pooled (tick);
    - q3_contrasts_by_year.png: the six contrasts of the historical series, 2013-2022, one panel
      each on a shared scale.

Inputs
    - results/q3_post_qualities.csv (exported from rpt_q3_post_qualities), segment 'all'.

Assumptions
    - Rates are recomputed from the exact counts; pooled figures add the counts of the ten years.
    - The 'unknown' account-age bucket is left out of the charts, as it is left out of every
      comparison in the report (deleted accounts, not an asker profile).
    - The contrasts are the same as in check_doc.py and derived_statistics.py.
    - Needs matplotlib (requirements.txt); the other scripts use the standard library only.

Run (from the repository root)
    python scripts/q3/charts.py
    Prints the path of each chart written.
"""
import csv
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT_DIR = "docs/images"
YEARS = list(range(2013, 2023))
NAMES = {
    "code_block_count": "Code blocks", "asker_account_age_days": "Account age (days)",
    "body_length": "Body length (characters)", "has_error_report": "Error report in prose",
    "tag_count": "Tag count", "title_length": "Title length", "title_has_question_mark": "Question mark in title",
    "created_weekday": "Weekday (UTC)", "link_count": "Links", "created_hour_utc": "Hour (UTC)",
    "image_count": "Images",
}
MAIN_ATTRIBUTES = ["code_block_count", "asker_account_age_days", "body_length", "has_error_report"]
# (attribute, first bucket, second bucket, panel title): gap = rate(first) - rate(second)
CONTRASTS = [
    ("code_block_count", "2", "0", "Code: 2 blocks vs none"),
    ("asker_account_age_days", "31-365", "0", "Account: 31–365 days vs same day"),
    ("body_length", "500-999", "4000+", "Body: 500–999 vs 4,000+ characters"),
    ("has_error_report", "false", "true", "Error report: no vs yes"),
    ("title_has_question_mark", "true", "false", "Question mark: yes vs no"),
    ("image_count", "2+", "0", "Images: 2+ vs none"),
]

# Chart palette: one validated categorical slot on a light surface, ink and hairlines.
SURFACE, INK, INK_2, MUTED, GRID, BLUE = "#fcfcfb", "#0b0b0b", "#52514e", "#898781", "#e1e0d9", "#2a78d6"

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

buckets = {}  # (year, attribute) -> list of (order, bucket, questions, community accepted)
for r in csv.DictReader(open("results/q3_post_qualities.csv", encoding="utf-8")):
    if r["segment"] == "all":
        buckets.setdefault((int(r["creation_year"]), r["attribute"]), []).append(
            (int(r["bucket_order"]), r["bucket"], int(r["total_questions"]), int(r["community_accepted_questions"])))
for rows in buckets.values():
    rows.sort()


def rate(years, attribute, bucket):
    n = k = 0
    for year in years:
        for _, b, questions, accepted in buckets[(year, attribute)]:
            if b == bucket:
                n, k = n + questions, k + accepted
    return k / n


def bucket_names(attribute):
    return [b for _, b, _, _ in buckets[(2022, attribute)] if b != "unknown"]


def label(attribute, bucket):
    if attribute == "has_error_report":
        return {"false": "no", "true": "yes"}[bucket]
    text = bucket.replace("-", "–")
    if attribute == "body_length":
        for raw, pretty in (("1000", "1,000"), ("1999", "1,999"), ("2000", "2,000"), ("3999", "3,999"), ("4000", "4,000")):
            text = text.replace(raw, pretty)
    if attribute == "asker_account_age_days":
        text = text.replace("1095", "1,095").replace("1096", "1,096")
    return text


def clean_axes(ax, grid_axis):
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.grid(axis=grid_axis, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(length=0)


def save(fig, name):
    path = os.path.join(OUT_DIR, name)
    fig.savefig(path, dpi=200, bbox_inches="tight", pad_inches=0.25)
    plt.close(fig)
    print(path)


def main_attributes():
    baseline = sum(k for *_, k in buckets[(2022, "code_block_count")]) / sum(
        n for _, _, n, _ in buckets[(2022, "code_block_count")])
    fig, axes = plt.subplots(2, 2, figsize=(9, 6.4), sharey=True, layout="constrained")
    for ax, attribute in zip(axes.flat, MAIN_ATTRIBUTES):
        names = bucket_names(attribute)
        rates = [rate([2022], attribute, b) for b in names]
        ax.bar(range(len(names)), rates, width=0.55, color=BLUE)
        for i, value in enumerate(rates):
            ax.text(i, value + 0.008, f"{value:.1%}", ha="center", fontsize=8.5, color=INK, fontweight="semibold")
        ax.axhline(baseline, color=INK_2, linewidth=1.1)
        ax.set_xticks(range(len(names)), [label(attribute, b) for b in names], fontsize=8.5)
        ax.set_title(NAMES[attribute], loc="left", fontsize=10.5, fontweight="semibold")
        ax.set_ylim(0, 0.4)
        ax.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: f"{v:.0%}"))
        clean_axes(ax, "y")
    # The "yes" bar of the error-report panel sits below the baseline, leaving room for its label.
    axes[1][1].text(1, baseline + 0.012, f"2022 baseline: {baseline:.1%}", ha="center", fontsize=8.5, color=INK_2)
    fig.supylabel("Community-accepted answer within 30 days", fontsize=10, color=INK_2)
    fig.suptitle("2022: community acceptance by bucket, the four attributes with the largest gaps",
                 x=0.02, ha="left", fontsize=12, fontweight="semibold", color=INK)
    save(fig, "q3_main_attributes_2022.png")


def gap(attribute, years):
    rates = [rate(years, attribute, b) for b in bucket_names(attribute)]
    return (max(rates) - min(rates)) * 100


def attribute_gaps():
    rows = sorted(((a, gap(a, [2022]), gap(a, YEARS)) for a in NAMES), key=lambda r: r[1])
    fig, ax = plt.subplots(figsize=(8, 4.8), layout="constrained")
    for i, (attribute, g2022, pooled) in enumerate(rows):
        ax.barh(i, g2022, height=0.5, color=BLUE)
        ax.plot([pooled, pooled], [i - 0.33, i + 0.33], color=INK, linewidth=2)
        # The 2022 value sits inside its bar, so it is never read as the pooled tick's value; when
        # the tick falls where the label would be, the label moves just past the bar end.
        if g2022 - 1.1 < pooled < g2022:
            ax.text(g2022 + 0.2, i, f"{g2022:.1f}", va="center", fontsize=9, color=INK, fontweight="semibold")
        else:
            ax.text(g2022 - 0.2, i, f"{g2022:.1f}", ha="right", va="center", fontsize=9, color="#ffffff",
                    fontweight="semibold")
    ax.set_yticks(range(len(rows)), [NAMES[a] for a, _, _ in rows], color=INK_2)
    ax.set_xlim(0, 16)
    ax.set_xlabel("Best bucket minus worst bucket, community acceptance (pp)")
    clean_axes(ax, "x")
    fig.suptitle("Gap between the best and the worst bucket: 2022 (bar) and 2013–2022 pooled (tick)",
                 x=0.02, ha="left", fontsize=12, fontweight="semibold", color=INK)
    save(fig, "q3_attribute_gaps.png")


def contrasts_by_year():
    fig, axes = plt.subplots(2, 3, figsize=(10, 5.6), sharey=True, sharex=True, layout="constrained")
    for ax, (attribute, first, second, title) in zip(axes.flat, CONTRASTS):
        values = [(rate([y], attribute, first) - rate([y], attribute, second)) * 100 for y in YEARS]
        ax.axhline(0, color=INK_2, linewidth=1)
        ax.plot(YEARS, values, color=BLUE, linewidth=2)
        ax.scatter([YEARS[0], YEARS[-1]], [values[0], values[-1]], s=30, color=BLUE, edgecolors=SURFACE,
                   linewidths=1.5, zorder=3)
        ax.annotate(f"{values[0]:.1f}".replace("-", "−"), (YEARS[0], values[0]), xytext=(0, 8),
                    textcoords="offset points", ha="center", fontsize=8.5, color=INK_2)
        ax.annotate(f"{values[-1]:.1f}".replace("-", "−"), (YEARS[-1], values[-1]), xytext=(0, 8),
                    textcoords="offset points", ha="center", fontsize=8.5, color=INK, fontweight="semibold")
        ax.set_title(title, loc="left", fontsize=10, fontweight="semibold")
        ax.set_ylim(-4, 16)
        ax.set_xticks([2013, 2016, 2019, 2022])
        clean_axes(ax, "y")
    fig.supylabel("Gap in community acceptance (pp)", fontsize=10, color=INK_2)
    fig.suptitle("The contrasts year by year, 2013–2022: same direction every year except images",
                 x=0.02, ha="left", fontsize=12, fontweight="semibold", color=INK)
    save(fig, "q3_contrasts_by_year.png")


os.makedirs(OUT_DIR, exist_ok=True)
main_attributes()
attribute_gaps()
contrasts_by_year()
