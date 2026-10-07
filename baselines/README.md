# Same-Platform Baselines

These baselines compute the same operation as FACT: exact ordinary signed-
integer linear convolution with `N/2` input samples, `Nh < N/2` filter taps,
and `N` output coefficients per output channel. They are local references,
not claims about the best possible direct-convolution or NTT architecture.

## Direct spatial convolution

`direct/` contains a four-input-channel, `PAR=4` multiply-accumulate datapath.
It implements one output channel in hardware. The published `Cout=4` cycle
count is four measured single-output tasks scheduled on that same core; area
is therefore unchanged. Input channels are spatially instantiated, so the
measured task cycles do not change for `Cin={1,2,4}`.

## Compact zero-pad NTT (Table I)

`zero_pad/` contains a complete length-`N` radix-2 reference flow. It performs
all required forward transforms, frequency-domain multiply-accumulation, one
inverse transform per output channel, and full-length readout. INT4 uses one
prime. INT8 runs the two prime instances concurrently and applies Prime CRT.

The zero-padding implementation is deliberately compact and sequential. A
latency ratio against it demonstrates the consequence of the FACT schedule at
these stated local design points; it is not a universal speedup claim over
optimized NTT accelerators.

See [Reproduction](../docs/REPRODUCIBILITY.md#baselines-and-workloads) for
commands and [Paper evidence](../docs/EVIDENCE.md) for measurement scope.

## Parallel zero-pad NTT (Section IV and Figure 3(c))

`parallel_zero_pad/` contains the separate N=1024, p520, INT4 comparator with
Cin=1/2/4 and Cout=1. Its source, testbench, ROMs, short simulation entry point,
and optional implementation flow are included. Start with that directory's
[README](parallel_zero_pad/README.md); its archived-source provenance differs
from the manifest-pinned FACT core.
