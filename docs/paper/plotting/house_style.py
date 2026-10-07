"""Shared house style for FACT-NTT paper figures (matplotlib).

One restrained pastel family across all four figures: blue = primary/data,
orange = signal/contrast, teal = hero/CRT, purple = control, gray = neutral.
Editable SVG text (svg.fonttype='none') + embedded TrueType PDF (pdf.fonttype=42).
"""
import matplotlib as mpl
mpl.use("Agg")
import matplotlib.pyplot as plt

# ---- IEEE column geometry (inches) ----
COL_W = 3.5          # single column
FULL_W = 7.16        # double column (full width)

# ---- pastel house palette (fill / line / dark text variants) ----
C = {
    "blue_fill":   "#D6E7F5", "blue_line":   "#3F7FB5", "blue_dark":   "#23597F",
    "green_fill":  "#D8EBD2", "green_line":  "#5DA058", "green_dark":  "#3C7A38",
    "orange_fill": "#FBDDC4", "orange_line": "#D9803F", "orange_dark": "#A85A22",
    "teal_fill":   "#C7E6DF", "teal_line":   "#3AA395", "teal_dark":   "#1F7064",
    "purple_fill": "#E3D6EE", "purple_line": "#8F66B3", "purple_dark": "#5E3E80",
    "yellow_fill": "#F8F0CF", "yellow_line": "#C2A23F",
    "gray_fill":   "#ECECEC", "gray_line":   "#8C8C8C", "gray_dark":   "#5A5A5A",
    "ink":         "#222222", "muted": "#6E6E6E",
}

def apply_style(font_size=7.2):
    plt.rcParams.update({
        "font.family": "sans-serif",
        "font.sans-serif": ["Arial", "Helvetica", "DejaVu Sans"],
        "svg.fonttype": "none",      # editable <text> in SVG
        "pdf.fonttype": 42,          # embedded TrueType in PDF
        "ps.fonttype": 42,
        "font.size": font_size,
        "axes.titlesize": font_size + 0.8,
        "axes.labelsize": font_size,
        "xtick.labelsize": font_size - 0.4,
        "ytick.labelsize": font_size - 0.4,
        "legend.fontsize": font_size - 0.4,
        "axes.spines.right": False,
        "axes.spines.top": False,
        "axes.linewidth": 0.7,
        "xtick.major.width": 0.7,
        "ytick.major.width": 0.7,
        "xtick.major.size": 2.5,
        "ytick.major.size": 2.5,
        "legend.frameon": False,
        "axes.axisbelow": True,
        "figure.dpi": 120,
    })

def save_all(fig, stem, dpi_png=220):
    """Write editable SVG + LaTeX PDF + a PNG preview."""
    fig.savefig(stem + ".svg", bbox_inches="tight")
    fig.savefig(stem + ".pdf", bbox_inches="tight")
    fig.savefig(stem + ".png", dpi=dpi_png, bbox_inches="tight")
    plt.close(fig)
