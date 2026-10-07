#!/usr/bin/env python3
"""Independently check a public FACT output dump.

The checker rebuilds deterministic X/H samples from CSV metadata and computes
ordinary signed-integer linear convolution directly. It does not call the RTL,
an NTT model, or the SystemVerilog testbench golden array.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path


MASK32 = 0xFFFFFFFF


def u32(value: int) -> int:
    return value & MASK32


def bounded_hash(idx: int, ch: int, co: int, salt: int, bound: int) -> int:
    pos_bound = bound - 1
    v = u32(
        0x4D595DF4
        ^ u32(idx * 1103515245)
        ^ u32(ch * 2654435761)
        ^ u32((co + 1) * 1597334677)
        ^ u32(salt * 2246822519)
    )
    v = u32((v ^ (v >> 16)) * 2246822519)
    v = u32((v ^ (v >> 13)) * 3266489917)
    v = u32(v ^ (v >> 16))
    return int(v % (bound + pos_bound + 1)) - bound


def sample_x(idx: int, ch: int, pid: int, r: int, bound: int) -> int:
    pos_bound = bound - 1
    span = bound + pos_bound + 1
    if pid == 0:
        return ((idx * 5 + ch * 3 + 7) % span) - bound
    if pid == 1:
        return pos_bound
    if pid == 2:
        return -bound
    if pid == 3:
        return -bound if ((idx + ch) & 1) else pos_bound
    if pid == 4:
        return (ch + 1) if idx == (17 if ch else 0) else 0
    if pid == 5:
        return (-bound if ((idx + ch) & 1) else pos_bound) if (idx >= r - 8 or idx < 3) else 0
    return bounded_hash(idx, ch, 0, 17 + pid * 193, bound)


def sample_h(idx: int, ch: int, co: int, pid: int, r: int, bound: int) -> int:
    pos_bound = bound - 1
    span = bound + pos_bound + 1
    if pid == 0:
        return ((idx * 7 + ch * 11 + co * 13 + 5) % span) - bound
    if pid == 1:
        return pos_bound
    if pid == 2:
        return -bound
    if pid == 3:
        return pos_bound if (idx & 1) else -bound
    if pid == 4:
        return (ch + 1 + co) if idx == 0 else 0
    if pid == 5:
        return (pos_bound if ((idx + ch + co) & 1) else -bound) if (idx < 4 or idx >= r - 8) else 0
    return bounded_hash(idx, ch, co, 91 + pid * 389, bound)


def parse_header(line: str) -> dict[str, int]:
    if not line.startswith("#"):
        raise ValueError("first line must be a metadata comment")
    pairs = dict(re.findall(r"([A-Z0-9_]+)=(-?\d+)", line))
    required = ["R", "N", "LANES", "CIN", "COUT", "NH", "PATTERN", "BOUND"]
    missing = [key for key in required if key not in pairs]
    if missing:
        raise ValueError(f"missing metadata keys: {missing}")
    return {key: int(value) for key, value in pairs.items()}


def read_dump(path: Path) -> tuple[dict[str, int], dict[tuple[int, int], int]]:
    with path.open("r", newline="") as stream:
        meta = parse_header(stream.readline().strip())
        rows: dict[tuple[int, int], int] = {}
        for row in csv.DictReader(stream):
            key = (int(row["cout"]), int(row["index"]))
            if key in rows:
                raise ValueError(f"duplicate output row: {key}")
            rows[key] = int(row["y"])
    return meta, rows


def build_expected(meta: dict[str, int]) -> dict[tuple[int, int], int]:
    r = meta["R"]
    n = meta["N"]
    cin = meta["CIN"]
    cout = meta["COUT"]
    nh = meta["NH"]
    pattern = meta["PATTERN"]
    bound = meta["BOUND"]

    if n != 2 * r:
        raise ValueError(f"metadata N={n} does not equal 2R={2 * r}")
    if cin not in (1, 2, 4) or cout not in (1, 2, 4):
        raise ValueError(f"unsupported channel metadata Cin={cin}, Cout={cout}")
    if not (1 <= nh < r):
        raise ValueError(f"invalid Nh={nh} for R={r}")
    if not (1 <= bound <= 128):
        raise ValueError(f"invalid signed sample bound={bound}")

    expected: dict[tuple[int, int], int] = {}
    for co in range(cout):
        acc = [0] * n
        for ch in range(cin):
            xs = [sample_x(i, ch, pattern, r, bound) for i in range(r)]
            hs = [sample_h(j, ch, co, pattern, r, bound) for j in range(nh)]
            for i, x_value in enumerate(xs):
                if x_value == 0:
                    continue
                for j, h_value in enumerate(hs):
                    if h_value != 0:
                        acc[i + j] += x_value * h_value
        for idx, value in enumerate(acc):
            expected[(co, idx)] = value
    return expected


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, type=Path, help="RTL output CSV dump")
    parser.add_argument("--report", type=Path, help="optional Markdown report")
    args = parser.parse_args(argv)

    meta, actual = read_dump(args.csv)
    expected = build_expected(meta)
    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))
    mismatches = [
        (co, idx, actual[(co, idx)], expected[(co, idx)])
        for co, idx in sorted(set(expected) & set(actual))
        if actual[(co, idx)] != expected[(co, idx)]
    ]
    passed = not missing and not extra and not mismatches

    lines = [
        "# FACT Lean-IP Independent Python Cross-Check",
        "",
        f"CSV: `{args.csv}`",
        "",
        "## Metadata",
        "",
        "| Field | Value |",
        "|---|---:|",
    ]
    for key in ["R", "N", "LANES", "CIN", "COUT", "NH", "PATTERN", "BOUND"]:
        lines.append(f"| `{key}` | {meta[key]} |")
    lines.extend([
        "",
        "## Verdict",
        "",
        f"- Overall: {'PASS' if passed else 'FAIL'}",
        f"- Expected rows: {len(expected)}",
        f"- Actual rows: {len(actual)}",
        f"- Missing rows: {len(missing)}",
        f"- Extra rows: {len(extra)}",
        f"- Mismatches: {len(mismatches)}",
    ])
    if mismatches:
        lines.extend(["", "First mismatches:", ""])
        for co, idx, got, wanted in mismatches[:16]:
            lines.append(f"- cout={co}, index={idx}: got {got}, expected {wanted}")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"FACT Lean-IP INT8 independent Python cross-check: {'PASS' if passed else 'FAIL'}")
    print(f"rows expected={len(expected)} actual={len(actual)} mismatches={len(mismatches)}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
