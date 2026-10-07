#!/usr/bin/env python3
"""Independent direct-convolution check for the p520 zero-padding baseline."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path


def parse_header(line: str) -> dict[str, int]:
    pairs = dict(re.findall(r"([A-Z]+)=(-?\d+)", line))
    required = ["N", "NX", "NH", "CIN", "PATTERN", "PRIME"]
    missing = [key for key in required if key not in pairs]
    if not line.startswith("#") or missing:
        raise ValueError(f"invalid metadata header; missing={missing}")
    return {key: int(value) for key, value in pairs.items()}


def sample_x(idx: int, ch: int, pattern: int, nx: int) -> int:
    if pattern == 0:
        return ((idx * 5 + ch * 3 + 7) % 16) - 8
    if pattern == 1:
        return 7
    if pattern == 2:
        return -8
    if pattern == 3:
        return -8 if ((idx + ch) & 1) else 7
    if pattern == 4:
        return (ch + 1) if idx == (17 if ch else 0) else 0
    if pattern == 5:
        return (-8 if ((idx + ch) & 1) else 7) if (idx >= nx - 8 or idx < 3) else 0
    return ((idx * 13 + ch * 29 + 5) % 16) - 8


def sample_h(idx: int, ch: int, pattern: int, nx: int) -> int:
    if pattern == 0:
        return ((idx * 7 + ch * 11 + 5) % 16) - 8
    if pattern == 1:
        return 7
    if pattern == 2:
        return -8
    if pattern == 3:
        return 7 if (idx & 1) else -8
    if pattern == 4:
        return (ch + 1) if idx == 0 else 0
    if pattern == 5:
        return (7 if ((idx + ch) & 1) else -8) if (idx < 4 or idx >= nx - 8) else 0
    return ((idx * 19 + ch * 31 + 9) % 16) - 8


def expected_output(meta: dict[str, int]) -> list[int]:
    n, nx, nh, cin = meta["N"], meta["NX"], meta["NH"], meta["CIN"]
    pattern = meta["PATTERN"]
    if n != 2 * nx or n != 1024 or meta["PRIME"] != 520193:
        raise ValueError(f"unexpected baseline contract: {meta}")
    if cin not in (1, 2, 4) or not (1 <= nh < nx):
        raise ValueError(f"invalid runtime configuration: Cin={cin}, Nh={nh}")
    expected = [0] * n
    for ch in range(cin):
        xs = [sample_x(i, ch, pattern, nx) for i in range(nx)]
        hs = [sample_h(j, ch, pattern, nx) for j in range(nh)]
        for i, x_value in enumerate(xs):
            if x_value == 0:
                continue
            for j, h_value in enumerate(hs):
                if h_value != 0:
                    expected[i + j] += x_value * h_value
    return expected


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args(argv)

    with args.csv.open("r", newline="") as stream:
        meta = parse_header(stream.readline().strip())
        actual: dict[int, int] = {}
        for row in csv.DictReader(stream):
            index = int(row["index"])
            if index in actual:
                raise ValueError(f"duplicate index={index}")
            actual[index] = int(row["y"])

    expected = expected_output(meta)
    missing = [index for index in range(meta["N"]) if index not in actual]
    extra = sorted(set(actual) - set(range(meta["N"])))
    mismatches = [
        (index, actual[index], expected[index])
        for index in range(meta["N"])
        if index in actual and actual[index] != expected[index]
    ]
    passed = not missing and not extra and not mismatches
    lines = [
        "# p520 Zero-Padded N=1024 Baseline Independent Check",
        "",
        f"CSV: `{args.csv}`",
        "",
        "| Field | Value |",
        "|---|---:|",
    ]
    for key in ["N", "NX", "NH", "CIN", "PATTERN", "PRIME"]:
        lines.append(f"| `{key}` | {meta[key]} |")
    lines.extend([
        "",
        f"- Overall: {'PASS' if passed else 'FAIL'}",
        f"- Expected rows: {len(expected)}",
        f"- Actual rows: {len(actual)}",
        f"- Missing rows: {len(missing)}",
        f"- Extra rows: {len(extra)}",
        f"- Mismatches: {len(mismatches)}",
    ])
    for index, got, wanted in mismatches[:16]:
        lines.append(f"- index={index}: got {got}, expected {wanted}")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"p520 zero-pad independent check: {'PASS' if passed else 'FAIL'}")
    print(f"rows={len(actual)} mismatches={len(mismatches)}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
