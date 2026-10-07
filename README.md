# FACT-NTT

A configurable FPGA IP for exact multichannel signed-integer linear convolution.
FACT-NTT reconstructs the full linear product from cyclic and negacyclic residues
and accumulates input-channel products before inverse transforms.

## Configuration

| Setting | Supported values |
|---|---|
| Build-time precision | INT4 or INT8 |
| Build-time output length `N=2R` | 256, 512, 1024 |
| Corresponding `LANES` | 8, 8, 16 |
| Runtime filter length `Nh` | 1 through `R-1` |
| Runtime `Cin`, `Cout` | 1, 2, 4 |

The supplied flow uses Windows PowerShell 5.1 or 7, Python 3.10+, and AMD
Vivado 2024.2 with `xczu9eg-ffvb1156-2-e` device support. Install Vivado separately.

## Quick start

From the repository root, check the distributed files and paper evidence:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify_manifest.ps1
python scripts/check_paper_alignment.py
python scripts/verify_archived_outputs.py
```

These checks require no Vivado or third-party Python packages. They verify file
hashes, report/data consistency, and the archived outputs of 186 FACT and 54
compact zero-pad cases. For a short fresh simulation, set `VIVADO_BIN` and run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim.ps1 -Precision 4 -N 256 -DumpCsv
python scripts/check_fact_output.py --csv build/xsim/p4_n256_c1o1_b0/fact_output.csv
```

[Reproduction](docs/REPRODUCIBILITY.md) gives the complete suite, baseline and
routing commands. New outputs go under ignored `build/`.

## Integration and contents

The public top is
[`ntt46_fact_lean_ip_unified_axi_lite_core.sv`](rtl/unified/ntt46_fact_lean_ip_unified_axi_lite_core.sv).
Start with [Interface](docs/INTERFACE.md) and the
[host example](examples/fact_ntt_host_sequence.py).
Preload all `R` entries of every active H bank, zeroing the tail beyond `Nh`.

| Directory | Contents |
|---|---|
| [rtl/](rtl/), [rom/](rom/) | FACT RTL and parameter tables |
| [tb/](tb/), [examples/](examples/) | End-to-end testbench, host example and C register definitions |
| [scripts/](scripts/) | Verification, implementation and evidence checks |
| [baselines/](baselines/) | Direct MAC, compact zero-pad NTT and parallel zero-pad comparator |
| [docs/](docs/) | Architecture, interface, reproduction and evidence map |
| [docs/paper/](docs/paper/) | Paper figures, input data and Figure 3 plotting code |
| [reports/](reports/) | Selected route reports, result vectors and indexed verification logs |

[Architecture](docs/ARCHITECTURE.md) explains the datapaths and configuration.
[Evidence](docs/EVIDENCE.md) maps the paper's results to the retained records.
The results are RTL simulation and routed implementation results, without board
measurements. Core latency excludes preload and external readback; power is a
vectorless Vivado estimate with Low confidence.

Use [CITATION.cff](CITATION.cff) to cite this work. The source license is
[Apache-2.0](LICENSE).
