# Paper figures and data

[Figure 1](figures/figure1.pdf), [Figure 2](figures/figure2.pdf), and
[Figure 3](figures/figure3.pdf) are the accompanying manuscript's vector figures. Figure 3 also has an editable SVG and PNG preview. Figures 1-2
are supplied as vector PDFs; their diagram-authoring sources are not included.
The manuscript and minimal Overleaf files are separate submission deliverables.

Figure 3(a) shows the runtime channel matrix, (b) repeated versus fused
input-channel schedules on identical RTL, and (c) normalized routed resources.
Panel (b) uses raw cycles. The full-length parallel zero-pad comparator provides
resource context in (c).

To regenerate Figure 3 from the repository root, use Python 3.12+:

```powershell
python -m pip install -r docs/paper/plotting/requirements.txt
python docs/paper/plotting/fig3.py
```

PDF/SVG/PNG exports and `figure_data_validation.json` go to `build/figures/`.
The supplied exports remain unchanged. The reviewed rendering uses Arial;
fallback fonts may change glyph geometry. The PDF has embedded fonts.

All input data are the nine CSVs in `evidence/`. [Paper evidence](../EVIDENCE.md)
maps panels and tables to original reports. `ASSET_SHA256.csv` checks the
distributed figures, data, plotting code, and requirements. Update the asset
and release manifests after changing those files.
