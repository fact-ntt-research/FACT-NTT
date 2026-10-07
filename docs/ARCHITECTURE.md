# Architecture and configuration

FACT decomposes a length-`2R` linear convolution into direct and coset residue
paths over `z^R-1` and `z^R+1`. For each output channel, spectral products are
accumulated across active input channels before the shared inverse schedule.
Polynomial CRT reconstructs the low and high halves of the full product.

INT4 uses prime 520193. INT8 runs two instances of the same FACT residue engine
concurrently over primes 520193 and 254977, then applies prime CRT during native
result readback. Both builds retain the same core-cycle schedule. The parallel
INT8 implementation uses more resources to preserve latency.

## Build parameters

| Parameter | Supported values | Meaning |
|---|---|---|
| `PRECISION` | 4, 8 | Signed input precision |
| `R` | 128, 256, 512 | Residue-transform length |
| `N` | `2*R` | Derived output tile length |
| `LANES` | 8, 8, 16 | Width corresponding to the three `R` values |
| `CIN_MAX`, `COUT_MAX` | 4 | Compiled channel capacity |

Precision, transform size, lane count, prime set, and ROM selection are fixed
when building the design. Address widths, stage counts, storage depths, and
schedule lengths follow these choices; they are not independent public modes.

## Runtime tasks

Program `Nh`, `Cin`, and `Cout` through AXI-Lite. Valid filter lengths are
`1..R-1`; each channel count must be 1, 2, or 4. Channel count 3 is rejected.
The output contains `Cout*N` signed coefficients, including zeros beyond
`R+Nh-1` in each output tile.

Load all `R` entries of every active X and H bank before starting. For H, write
zero at indices `Nh..R-1`. The frozen direct-stage-0 path does not clear or
mask stale H tails when `Nh` changes. The host example zero-fills each task.
See [Interface](INTERFACE.md) for the handshakes and register map.

## Implementation scope

The supplied integration boundary is AXI-Lite control plus synchronous native
operand and result ports. Physical data transport is supplied by the enclosing
system. [Evidence](EVIDENCE.md) defines the reported workloads and timing scope;
the published clock points depend on the supplied device, tool version, and
implementation flow.

## Source organization

The 51 FACT RTL files form the public top's transitive module/package reference
closure across supported generate branches. `rtl/p520/` and `rtl/p254/` contain
the two prime-specialized datapaths; `rtl/common/` contains prime reconstruction
and `rtl/unified/` the public wrappers. Internal module identifiers are retained
to preserve source dependencies. The ROM set includes compatibility tables used
by the parameter audit.

`scripts/fact_sources.ps1` supplies the ordered compile list.
`reports/source_manifest.csv` pins the distributed HDL hashes.
`python scripts/audit_source_closure.py` checks hashes, unique definitions and
reference reachability. The comparators in `baselines/` have separate compile
lists and testbenches.
