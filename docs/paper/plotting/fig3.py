"""Figure 3: runtime map, same-RTL channel fusion, and routed resources.

All values come from the accompanying frozen evidence CSVs. Latency uses
integer cycles and the original clock period, not rounded frequency labels.
The fusion panel compares schedules on unchanged RTL under the same
core-counter definition. No cross-architecture time ratio is plotted.
"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LinearSegmentedColormap, Normalize
from matplotlib.patches import Patch

from house_style import C, FULL_W, apply_style, save_all

# Reuse the heatmap's dark blue and light teal; gray denotes the baseline.
SERIES = {
    "INT4": {"line": "#173F58", "fill": "#315F75"},
    "INT8": {"line": "#448E92", "fill": "#A9CED0"},
    "baseline": {"line": "#747474", "fill": "#CDCDCD"},
}

HERE = Path(__file__).resolve()
OUTPUT = HERE.parents[3] / "build" / "figures"
OUTPUT.mkdir(parents=True, exist_ok=True)
EVIDENCE = HERE.parents[1] / "evidence"
BASELINE_CSV = EVIDENCE / "parallel_zero_pad.csv"


def read_csv(name: str) -> list[dict[str, str]]:
    with (EVIDENCE / name).open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def read_csv_path(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def select(rows: list[dict[str, str]], **criteria: str) -> dict[str, str]:
    matches = [
        row for row in rows
        if all(str(row[key]) == str(value) for key, value in criteria.items())
    ]
    if len(matches) != 1:
        raise RuntimeError(f"Expected one row for {criteria}; found {len(matches)}")
    return matches[0]


schedule = read_csv("runtime_schedule.csv")
routed = read_csv("fact_routed.csv")
baseline = read_csv_path(BASELINE_CSV)
fusion = read_csv("fusion_ablation.csv")

channels = (1, 2, 4)
period_ns = {
    precision: float(select(routed, Precision=precision, N="1024")["PeriodNs"])
    for precision in ("INT4", "INT8")
}

latency = {}
for precision in ("INT4", "INT8"):
    latency[precision] = np.array([
        [
            int(select(schedule, N="1024", Cin=str(ci), Cout=str(co))["CoreCycles"])
            * period_ns[precision] / 1000.0
            for co in channels
        ]
        for ci in channels
    ])

fact_cycles = np.array([
    int(select(schedule, N="1024", Cin=str(ci), Cout="1")["CoreCycles"])
    for ci in channels
])
baseline_rows = [select(baseline, N="1024", Cin=str(ci), Cout="1")
                 for ci in channels]
fused_cycles = {}
separate_cycles = {}
for precision in ("4", "8"):
    selected = [select(fusion, Precision=precision, N="1024", Cin=str(ci), Cout="1")
                for ci in channels]
    fused_cycles[precision] = np.array([int(row["FusedCoreCycles"]) for row in selected])
    separate_cycles[precision] = np.array([
        int(row["RepeatedSingleChannelCoreCycles"]) for row in selected
    ])
    assert all(row["Mismatches"] == "0" for row in selected)
    assert all(row["ComparedOutputs"] == "1024" for row in selected)
    for row in selected:
        saving = 100 * (1 - int(row["FusedCoreCycles"]) /
                        int(row["RepeatedSingleChannelCoreCycles"]))
        assert abs(saving - float(row["CycleSavingPercent"])) < 0.00051
assert np.array_equal(fused_cycles["4"], fused_cycles["8"])
assert np.array_equal(separate_cycles["4"], separate_cycles["8"])
assert np.array_equal(fused_cycles["4"], fact_cycles)
assert separate_cycles["4"].tolist() == [283, 566, 1132]
saving_percent = 100 * (1 - fused_cycles["4"] / separate_cycles["4"])

resource_keys = ("CLBLUTs", "CLBRegisters", "DSPs", "BRAMTiles")
resource_count = {}
for precision in ("INT4", "INT8"):
    row = select(routed, Precision=precision, N="1024")
    resource_count[precision] = np.array(
        [float(row[key]) for key in resource_keys]
    )

# Resource comparisons do not mix the different internal timing windows.
relative_cost = {
    precision: resource_count[precision] / resource_count["INT4"]
    for precision in ("INT4", "INT8")
}
parallel_cost = np.array([
    *[float(baseline_rows[0][key]) for key in ("TotalCLBLUT", "FF", "DSP", "BRAM")],
])
parallel_relative_cost = parallel_cost / resource_count["INT4"]
assert np.all(parallel_relative_cost > 0) and np.all(parallel_relative_cost <= 2)
assert parallel_cost.tolist() == [161375, 74446, 482, 511]

assert all(row["Mismatches"] == "0" for row in schedule)
assert fact_cycles.tolist() == [283, 464, 820]
assert all(row["RouteErrors"] == "0" for row in baseline_rows)
assert np.allclose(relative_cost["INT4"], np.ones(4))
assert 1.95 < relative_cost["INT8"][0] < 2.05

apply_style(font_size=7.7)
plt.rcParams.update({
    "axes.titleweight": "bold",
    "axes.titlepad": 4.0,
    "axes.labelsize": 8.7,
    "axes.labelweight": "semibold",
    "axes.linewidth": 0.75,
    "xtick.labelsize": 7.7,
    "ytick.labelsize": 7.7,
    "legend.handlelength": 1.35,
})

fig = plt.figure(figsize=(FULL_W, 2.64), facecolor="white")
outer = fig.add_gridspec(
    1, 3, width_ratios=[1.29, 1.25, 1.23],
    left=0.055, right=0.992, top=0.855, bottom=0.20, wspace=0.32,
)

# (a) Two compact 3x3 maps preserve the natural Ci x Co matrix.
heat_grid = outer[0, 0].subgridspec(
    2, 2, height_ratios=[1.0, 0.075], hspace=0.28, wspace=0.16,
)
ax_a4 = fig.add_subplot(heat_grid[0, 0])
ax_a8 = fig.add_subplot(heat_grid[0, 1])
cax = fig.add_subplot(heat_grid[1, :])

heat_cmap = LinearSegmentedColormap.from_list(
    "fact_runtime_latency",
    ["#E6F1F4", "#B7D8DD", "#78B7BC", "#3E929A", "#256B78", "#173F58"],
)
heat_norm = Normalize(vmin=0.0, vmax=17.0)
for axis, precision in ((ax_a4, "INT4"), (ax_a8, "INT8")):
    image = axis.pcolormesh(
        np.arange(4) - 0.5, np.arange(4) - 0.5, latency[precision],
        cmap=heat_cmap, norm=heat_norm, shading="flat", rasterized=False,
    )
    axis.set_xlim(-0.5, 2.5)
    axis.set_ylim(2.5, -0.5)
    axis.set_aspect("equal")
    precision_color = SERIES[precision]["line"]
    axis.set_title(precision, fontsize=8.0, color=precision_color, pad=2.4)
    axis.set_xticks(np.arange(3), ["1", "2", "4"])
    axis.set_yticks(np.arange(3), ["1", "2", "4"])
    axis.tick_params(length=0, pad=2.0)
    for tick_label in (*axis.get_xticklabels(), *axis.get_yticklabels()):
        tick_label.set_fontweight("semibold")
    for spine in axis.spines.values():
        spine.set_visible(False)
ax_a8.set_yticklabels([])
ax_a4.set_ylabel(r"input channels $C_i$")
heat_center = (ax_a4.get_position().x0 + ax_a8.get_position().x1) / 2
fig.text(heat_center, ax_a4.get_position().y0 - 0.075,
         r"output channels $C_o$", ha="center", va="top",
         fontsize=8.5, fontweight="semibold")
colorbar = fig.colorbar(image, cax=cax, orientation="horizontal")
colorbar.solids.set_rasterized(False)
colorbar.solids.set_edgecolor("face")
colorbar.set_ticks([0, 4, 8, 12, 16])
colorbar.set_label("core latency (µs)", labelpad=6.0,
                   fontsize=8.7, fontweight="bold")
colorbar.outline.set_linewidth(0.55)
colorbar.ax.tick_params(length=2.0, width=0.55, pad=1.5, labelsize=7.4)
for tick_label in colorbar.ax.get_xticklabels():
    tick_label.set_fontweight("semibold")

# (b) Same-RTL channel fusion. The two precisions have identical core counts.
ax_b = fig.add_subplot(outer[0, 1])
x_b = np.arange(3)
bar_width = 0.32
baseline_color = SERIES["baseline"]["line"]
for offset, values, key, label in (
    (-bar_width/2, separate_cycles["4"], "baseline", "Separate runs"),
    (bar_width/2, fused_cycles["4"], "INT4", "Fused"),
):
    bars=ax_b.bar(
        x_b+offset, values, bar_width,
        color=SERIES[key]["fill"], edgecolor=SERIES[key]["line"],
        linewidth=0.85, label=label, zorder=3,
    )
    ax_b.bar_label(
        bars, labels=[str(v) for v in values], padding=2.5,
        fontsize=7.0, fontweight="semibold")
ax_b.set_xlabel(r"input channels $C_i$")
ax_b.set_ylabel("core cycles", fontsize=9.0,
                fontweight="bold", labelpad=4.0, color=C["ink"])
ax_b.set_xticks(x_b, ["1", "2", "4"])
ax_b.set_ylim(0, 1450)
ax_b.set_yticks([0, 300, 600, 900, 1200])
for guide in (300, 600, 900):
    ax_b.axhline(guide, color=C["gray_line"], linewidth=0.38, alpha=0.42, zorder=0)
# Reduction percentages are reported in the manuscript, not on the bars.
ax_b.legend(loc="upper left",frameon=False,borderaxespad=0.2,
            prop={"size":7.2,"weight":"bold"},labelspacing=0.25)
for label in (*ax_b.get_xticklabels(), *ax_b.get_yticklabels()):
    label.set_fontweight("semibold")

# (c) Each resource is separately normalized to the FACT INT4 count.
ax_c=fig.add_subplot(outer[0,2])
x_c=np.arange(4)
resource_width=0.25
for offset, values, key in (
    (-resource_width,relative_cost["INT4"],"INT4"),
    (0,relative_cost["INT8"],"INT8"),
    (resource_width,parallel_relative_cost,"baseline"),
):
    ax_c.bar(x_c+offset,values,resource_width,color=SERIES[key]["fill"],
             edgecolor=SERIES[key]["line"],linewidth=0.8,zorder=3)
ax_c.set_xticks(x_c,["LUT","FF","DSP","BRAM"])
ax_c.set_ylabel("relative resources",fontsize=8.7,fontweight="bold",labelpad=3.0)
ax_c.set_ylim(0,2.15)
ax_c.set_yticks([0,0.5,1.0,1.5,2.0],["0","0.5×","1.0×","1.5×","2.0×"])
for guide in (0.5,1.0,1.5,2.0):
    ax_c.axhline(guide,color=C["gray_line"],linewidth=0.38,alpha=0.42,zorder=0)
for label in (*ax_c.get_xticklabels(),*ax_c.get_yticklabels()):
    label.set_fontweight("semibold")
c_center=(ax_c.get_position().x0+ax_c.get_position().x1)/2
handles=[Patch(facecolor=SERIES[k]["fill"],edgecolor=SERIES[k]["line"])
         for k in ("INT4","INT8","baseline")]
fig.legend(handles[:2],["FACT INT4","FACT INT8"],ncol=2,
           loc="center",bbox_to_anchor=(c_center,0.105),
           bbox_transform=fig.transFigure,frameon=False,handlelength=1.3,
           columnspacing=0.8,prop={"size":7.2,"weight":"semibold"})
fig.legend(handles[2:],["Parallel zero-pad NTT (INT4)"],
           loc="center",bbox_to_anchor=(c_center,0.038),
           bbox_transform=fig.transFigure,frameon=False,handlelength=1.3,
           prop={"size":7.2,"weight":"semibold"})

# Anchor each heading to its panel allocation, not to the inner plotting axes.
# This keeps heatmap, bar-chart, and resource-panel headings on one left grid.
panel_lefts = [outer[0, i].get_position(fig).x0 for i in range(3)]
for panel_left, title in zip(
    panel_lefts,
    ("(a) Runtime latency", "(b) Channel fusion", "(c) Routed resources"),
):
    fig.text(
        panel_left, 0.955, title,
        ha="left", va="top", fontsize=9.0,
        fontweight="bold", color=C["ink"],
    )

fig.canvas.draw()
save_all(fig, str(OUTPUT / "figure3"), dpi_png=600)
print("Figure 3 generated from paper-aligned evidence snapshots.")

report = {
    "channels": list(channels),
    "fact_latency_us": {k:v.tolist() for k,v in latency.items()},
    "fusion": {
        "separate_core_cycles": separate_cycles["4"].tolist(),
        "fused_core_cycles": fused_cycles["4"].tolist(),
        "cycle_saving_percent": saving_percent.tolist(),
        "identical_INT4_INT8_counts": True,
        "same_RTL_same_counter_definition": True,
    },
    "resources": {
        "labels": ["LUT","FF","DSP","BRAM"],
        "FACT_INT4": resource_count["INT4"].tolist(),
        "FACT_INT8": resource_count["INT8"].tolist(),
        "parallel_INT4": parallel_cost.tolist(),
        "ratios_to_FACT_INT4": {
            "FACT_INT4": relative_cost["INT4"].tolist(),
            "FACT_INT8": relative_cost["INT8"].tolist(),
            "parallel_INT4": parallel_relative_cost.tolist()
        }
    },
    "cross_architecture_time_plotted": False
}
(OUTPUT/"figure_data_validation.json").write_text(
    json.dumps(report,indent=2),encoding="utf-8")
