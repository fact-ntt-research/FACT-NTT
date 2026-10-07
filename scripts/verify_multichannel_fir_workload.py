#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


def sample_x(index: int, channel: int) -> int:
    if channel == 0:
        return index % 32 - 16
    if channel == 1:
        return 24 if (index // 16) & 1 else -24
    if channel == 2:
        return (index * 3) % 49 - 24
    return 31 if index % 64 == 0 else -31 if index % 64 == 1 else 0


def sample_h(index: int, channel: int, output: int) -> int:
    if output == 0:
        return (1, 2, 3, 2, 1)[index] if index < 5 else 0
    if output == 1:
        return -(channel + 1) if index == 0 else channel + 1 if index == 2 else 0
    if output == 2:
        return (1 if channel < 2 else -1) if index < 7 else 0
    return (-1 if (index + channel) & 1 else 1) if index < 8 else 0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("dump", type=Path)
    args = parser.parse_args()
    with args.dump.open(encoding="ascii") as handle:
        rows = [line for line in handle if not line.startswith("#")]
    got = {
        (int(row["cout"]), int(row["index"])): int(row["y"])
        for row in csv.DictReader(rows)
    }

    n, nx, nh = 1024, 512, 31
    compared = 0
    for output in range(4):
        expected = [0] * n
        for channel in range(4):
            for xi in range(nx):
                xv = sample_x(xi, channel)
                for hi in range(nh):
                    expected[xi + hi] += xv * sample_h(hi, channel, output)
        for index, want in enumerate(expected):
            value = got[(output, index)]
            if value != want:
                raise AssertionError(
                    f"output={output} index={index} rtl={value} direct_fir={want}"
                )
            compared += 1
    print(f"PASS workload=4x4_int8_fir_filter_bank outputs={compared} mismatches=0")


if __name__ == "__main__":
    main()
