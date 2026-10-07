# Paper evidence

Paths below are relative to the repository root. Published values come from
the named CSVs and their linked records.

## Paper map

The links below point to the corresponding sources and archived records.

| Paper component | Source | Interpretation |
|---|---|---|
| Sections II-III; Figures 1-2 | [RTL](../rtl/), [ROM](../rom/), [architecture](ARCHITECTURE.md) | Full linear reconstruction, shared direct/coset datapaths, channel fusion, dual-prime INT8 |
| Table I | [implementation.csv](../reports/implementation.csv) | 18 routes: six FACT, six direct MAC, six compact zero-pad |
| Figure 3(a) | [runtime_schedule.csv](paper/evidence/runtime_schedule.csv), [fact_routed.csv](paper/evidence/fact_routed.csv) | N=1024 channel matrix; cycles times archived period |
| Figure 3(b) | [fusion_ablation.csv](paper/evidence/fusion_ablation.csv), [ablation records](../reports/verification/ablation/) | Same RTL and counter: fused 283/464/820 versus repeated 283/566/1132 cycles |
| Figure 3(c) | [fact_routed.csv](paper/evidence/fact_routed.csv), [parallel_zero_pad.csv](paper/evidence/parallel_zero_pad.csv) | Routed resource ratios |
| Parallel comparator discussion | [reports](../reports/parallel_zero_pad/), [comparator](../baselines/parallel_zero_pad/) | Separate full-length INT4 comparator |
| Correctness matrix | [results.csv](../reports/verification/fact_matrix/results.csv) and linked dumps | 186 cases: 162 matrix and 24 signed-pattern stress cases |
| INT8 four-by-four FIR | [FIR records](../reports/verification/fir/) | 4096 coefficients; 3280 core / 3608 wall cycles |
| Table II context | [external_context.csv](paper/evidence/external_context.csv) | Published results with different devices and output contracts |

The three vector PDFs under `docs/paper/figures/` match the accompanying manuscript.
The nine input CSVs retain their frozen contents. `docs/paper/ASSET_SHA256.csv`
pins distributed figure, data, and plotting files.

## Implementation results

The canonical 18-row CSV covers FACT, direct MAC, and complete compact
zero-padding NTT at INT4/INT8 and N=256/512/1024. Each row links timing,
utilization, route-status, DRC, vectorless-power, and build-contract records
under `reports/routes/`. The scope is normal non-OOC implementation on
`xczu9eg-ffvb1156-2-e`, with zero route errors and nonnegative WNS and WHS.
Public copies redact only environment-specific report headers. The original FACT
route source-list hashes are preserved in `reports/routes/rtl_sources_sha256.csv`;
`reports/source_manifest.csv` describes the distributed dependency set. The
archived input manifests are provenance records, not compile lists for new runs.

Core cycles exclude native preload and external readback. At N=1024 and
Cin=Cout=1, 283 cycles at 4.125 ns gives INT4 latency 1.167375 us; 283 cycles
at 5.000 ns gives INT8 latency 1.415 us. Setup slack at these points is
+0.046 ns and +0.111 ns, respectively.

The Cin=4 fusion reduction is 27.6%, rounded from 1132 to 820 core cycles.
This compares repeated and fused schedules on the same RTL. Figure 3(c) gives
resource context for the parallel zero-pad comparator, not a cross-architecture
latency speedup.

The direct core instantiates four input-channel products and implements one
output channel. Its core cycles are equal for Cin=1/2/4; Cout=4 latency is four
sequential tasks on the same routed core, rather than a separately routed
four-output design. The compact zero-pad baseline includes forward transforms,
channel accumulation, inverse transforms, and the full linear output.

## Verification records

| Evidence | Location |
|---|---|
| FACT: 186 PASS cases | [results.csv](../reports/verification/fact_matrix/results.csv) |
| FACT protocol logs | [protocol/](../reports/verification/protocol/) |
| Direct-baseline checks | [direct/](../reports/verification/direct/) |
| Compact zero-pad: 54 PASS cases | [results.csv](../reports/verification/zero_pad/results.csv) |
| Parameter and ROM audit | [parameter_audit/](../reports/verification/parameter_audit/) |
| Input-channel fusion | [cin_fusion.csv](../reports/verification/ablation/cin_fusion.csv) |
| Four-channel FIR | [fir_python_check.log](../reports/verification/fir/fir_python_check.log) |

FACT and compact zero-pad outputs were compared coefficient by coefficient
with direct signed-integer convolution in the testbenches and independently
in Python. Retained output vectors permit checking the archived results without
Vivado. The FACT simulation and Python logs are collected in `simulation.log` and
`crosscheck.log` beside `results.csv`. Each section is labelled
`p<precision>_n<N>_nh<Nh>_c<Cin>o<Cout>_pat<pattern>`, using the case fields in
the result index. Tool housekeeping and duplicate records are omitted. Log
encoding is normalized to UTF-8; local path prefixes are redacted without
changing the measurement and check text.

`python scripts/check_paper_alignment.py` checks frozen sources, asset hashes,
archived route values, and paper/data links. `python scripts/verify_archived_outputs.py`
recomputes the 186 FACT and 54 compact zero-pad outputs. Neither invokes Vivado.
The older parallel comparator's provenance qualification is in
[`baselines/parallel_zero_pad/README.md`](../baselines/parallel_zero_pad/README.md).
