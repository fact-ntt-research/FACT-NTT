# Interface and counters

The public top provides AXI-Lite control and native ports synchronous to `clk`.
The transport-independent example is `examples/fact_ntt_host_sequence.py`;
C register definitions are in `examples/fact_ntt_regs.h`.

## Preload

A write is accepted on a rising edge with both `preload_valid` and
`preload_ready` high. Hold metadata and data stable until that handshake.

| Signal | Meaning |
|---|---|
| `preload_is_h` | 0 selects X; 1 selects H |
| `preload_cin` | Input-channel address, less than active Cin |
| `preload_cout` | H output-channel address, less than active Cout; ignored for X |
| `preload_idx` | Storage index, `0..R-1` |
| `preload_data` | Signed INT4/INT8 sample on a signed 19-bit port |

Ready is deasserted while a task is pending or active. Invalid coordinates or
samples outside the selected signed precision are rejected and set sticky
preload error code 4. Start may be written on the final accepted-preload cycle:
the wrapper waits for its preload pipeline to drain before starting the core.

Load every active X and H bank over all `R` entries. Write zero to H entries
`Nh..R-1`, including after shortening a filter. The frozen top selects
`DIRECT_STAGE0_FROM_LOCAL=1`, which bypasses the older load-stage mask;
changing `Nh` alone does not clear stored H entries.

## Readback and task order

Set `y_read_cout` and `y_read_idx`, assert `y_read_en`, and hold the request until
an edge with `y_read_ready` high. Then wait for `y_read_valid` and sample signed
`y_read_data`. INT4 and INT8 may have different native read latency.

Readback is enabled only after sticky done and for valid output coordinates.
It is disabled during a task and after clearing sticky status. For N=1024,
all 10-bit index values are legal; for Cout=4, all 2-bit channel values are legal.

1. Confirm IP identity, capabilities, precision, and N of the loaded build.
2. Clear sticky status and program Nh/Cin/Cout.
3. Handshake all X/H entries, including the zero-filled H tail.
4. Write start once and poll for error or done.
5. Collect `Cout*N` accepted result reads.
6. Read counters before clearing status or starting the next task.

## Register map

Registers are 32 bits; addresses below are byte offsets. Writes use `WSTRB`.

| Offset | Name | Access | Meaning |
|---:|---|---|---|
| `0x00` | `CTRL` | W | Bit 0 start when idle; bit 1 clear sticky done/preload error |
| `0x04` | `STATUS` | R | Bit 1 busy, 2 done, 3 cfg error, 4 core error, 5 preload error; bits 9:6 pending preload count |
| `0x08` | `CFG_NH` | R/W | Filter length, `1..R-1` |
| `0x0C` | `CFG_CIN` | R/W | Input channels, `1,2,4` |
| `0x10` | `CFG_COUT` | R/W | Output channels, `1,2,4` |
| `0x14` | `WALL_CYCLES` | R | Accepted-start-to-done interval |
| `0x18` | `CORE_CYCLES` | R | Scheduled arithmetic window |
| `0x1C` | `PRELOAD_EST` | R | Native preload transaction estimate |
| `0x20` | `READOUT_EST` | R | Native result-read transaction estimate |
| `0x24` | `ERROR_CODE` | R | `1=Nh`, `2=Cin`, `3=Cout`, `4=preload`, `5=engine` |
| `0x28` | `IP_ID` | R | ASCII `FACT`, `0x46414354` |
| `0x2C` | `BUILD_ID` | R | Frozen RTL build identifier `0x20260813` |
| `0x30` | `CAP0` | R | `[31:16]=R`, `[15:0]=N` |
| `0x34` | `CAP1` | R | Cout max, Cin max, lanes, precision/input width |
| `0x38` | `CAP2` | R | Capability flags, exact-linear flag, precision identifier |
| `0x3C` | `PRIME0` | R | `520193` |
| `0x40` | `PRIME1` | R | INT4: `0`; INT8: `254977` |
| `0x44`, `0x48`, `0x4C` | Reserved | R | Zero |

Configuration is sampled on an accepted start. Start while busy is ignored;
configuration writes are ignored from accepted start until completion.

## Cycle counters

Core cycles exclude native preload and external result reads. Wall cycles
measure accepted start to done, including wrapper and output-store boundaries.
Both precisions have the same counters for a given N/Cin/Cout workload.

Preload estimate is `Cin*R + Cout*Cin*R` native writes; readout estimate is
`Cout*2R` native reads. Latency in microseconds is `cycles*period_ns/1000`.

At `Nh=R-1`, the archived core/wall pairs are:

| N | Cin=Cout=1 | Cin=Cout=4 |
|---|---|---|
| 256 | 199 / 214 | 2288 / 2652 |
| 512 | 228 / 244 | 2604 / 2932 |
| 1024 | 283 / 299 | 3280 / 3608 |

The main latency rows use core cycles with Cin=Cout=1. The FIR example reports
both counters. Compare results only after accounting for their channel workload
and measurement window.
