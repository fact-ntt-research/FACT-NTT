# Reproduction

## Environment and archive checks

Use Windows PowerShell 5.1 or 7 and Python 3.10+. Fresh simulation and routing
require AMD Vivado 2024.2; the supplied target is `xczu9eg-ffvb1156-2-e`.
Set `VIVADO_BIN` to Vivado's `bin` directory and `PYTHON` to a working Python
executable, add them to PATH, or use the explicit script options.

Extract to a writable directory with a short ASCII path. From the repository
root, verify the release before running tools:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify_manifest.ps1
python scripts/check_paper_alignment.py
python scripts/verify_archived_outputs.py
```

These commands need no Vivado or third-party Python packages. They check the
file manifest, frozen assets, 18 archived route rows, and the outputs of 186 FACT
and 54 compact zero-pad cases. New results are written under ignored `build/`.

## FACT simulation

The shortest six-build matrix is:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_submission_matrix.ps1 -Quick
```

Expect six PASS rows in `build/submission_matrix/results.csv`: INT4/INT8 with
N=256/512/1024 and 199/228/283 core cycles. Omit `-Quick` for the 186-case matrix.
The SystemVerilog testbench compares every result with direct signed-integer
convolution. `run_python_crosscheck.ps1` exports results for an independent
Python check; its default covers INT4/INT8 at N=256 and Cin=Cout=4. Add `-Full`
to that command for all six build points.

The combined entry point is:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_reproduction.ps1
```

Its default runs manifest/report/parameter checks, host-sequence checks,
INT4/INT8 output and protocol cases, direct-baseline cases, and the 12-case
compact zero-pad key matrix. Add `-Full` for the full FACT/zero-pad matrices,
all six protocol and direct cases, fusion, FIR, and nine parallel-comparator
cases. Add `-RunImplementation` to repeat the six FACT routes as well.

Protocol cases cover capability registers, AXI-Lite byte strobes, illegal
configuration, repeated start, back-to-back tasks, reset recovery, and readback.
The parameter audit checks primes, roots, inverses, CRT constants, and ROMs.
`run_seeded_random_regression.ps1` is an optional additional regression entry.

## Baselines and workloads

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_direct_baseline.ps1 -Precision 8 -N 256 -Cin 4
powershell -ExecutionPolicy Bypass -File scripts/run_zero_pad_baseline.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_cin_fusion_ablation.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_fir_workload.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_parallel_zero_pad.ps1
```

The zero-pad default checks Cin/Cout=1/1 and 4/4 for each of six builds;
`-Full` covers all 54 legal size/precision/channel combinations. Its independent
checker is `baselines/zero_pad/verify_zero_pad_vector_dumps.py`.
Fusion compares fused and repeated single-channel FACT tasks. FIR checks
4,096 coefficients for the four-input/four-output INT8 workload.

The separate parallel zero-pad comparator is INT4, N=1024, Cout=1. Its default
uses Cin=4, Nh=511, pattern=6; Cin=1/2/4 gives 332/554/998 core cycles.
Its nine archived cases and optional implementation sequence are documented in
[`baselines/parallel_zero_pad/README.md`](../baselines/parallel_zero_pad/README.md).

## Routed implementation

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_implementation.ps1 -Precision 8 -N 256
powershell -ExecutionPolicy Bypass -File scripts/run_baseline_implementation.ps1 -Baseline direct -Precision 8 -N 256
powershell -ExecutionPolicy Bypass -File scripts/run_baseline_implementation.ps1 -Baseline zero_pad -Precision 8 -N 256
```

These perform normal non-OOC synthesis, placement, routing, and report
generation with default periods matching the archived rows. Accept a routed
run only with zero route errors and nonnegative WNS and WHS.
For all 18 FACT/direct/compact-zero-pad points:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_full_implementation_matrix.ps1 -Resume
```

This sequential matrix resumes a build only when source and script hashes
match its passing build contract. New FACT reports go under `build/vivado/`
and baseline reports under `build/baselines/implementation/`.

Use Vivado 2024.2 for comparisons with the routed paper results. A native Linux
flow has not been validated. Route results may vary with version, machine, and
directives; compare the exact timing scope, route status,
and resource counts rather than expecting byte-identical checkpoints.

## Figures and troubleshooting

Figure 3 plotting is optional and uses Python 3.12+ with separately pinned
dependencies. Commands and input data are in [`paper/README.md`](paper/README.md).

Missing-tool errors require correcting the executable path. Compiler errors,
missing ROMs, coefficient mismatches, negative timing margins, or absent PASS
markers are failed checks. Preserve generated logs when reporting an issue.
Tool projects, DCPs, waveform databases, and simulator housekeeping directories
are excluded from the archive and regenerated under `build/`.
