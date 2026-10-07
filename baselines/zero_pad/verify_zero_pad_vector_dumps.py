#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


def verify(path: Path) -> tuple[int, int, int, int]:
    stem = path.stem
    fields = stem.split("_")
    n = int(fields[1][1:])
    precision = int(fields[2][3:])
    cin_count, cout_count = (int(v) for v in fields[3][1:].split("o"))
    nx = n // 2
    x = [[0] * nx for _ in range(cin_count)]
    h_rows: dict[tuple[int, int], dict[int, int]] = {}
    y = [[None] * n for _ in range(cout_count)]

    with path.open(newline="", encoding="ascii") as handle:
        for row in csv.DictReader(handle):
            kind = row["kind"]
            cout = int(row["cout"])
            cin = int(row["cin"])
            index = int(row["index"])
            value = int(row["value"])
            if kind == "x":
                x[cin][index] = value
            elif kind == "h":
                h_rows.setdefault((cout, cin), {})[index] = value
            elif kind == "y":
                y[cout][index] = value
            else:
                raise ValueError(f"{path}: unknown row kind {kind!r}")

    for cout in range(cout_count):
        expected = [0] * n
        for cin in range(cin_count):
            h_map = h_rows[(cout, cin)]
            for xi, xv in enumerate(x[cin]):
                for hi, hv in h_map.items():
                    expected[xi + hi] += xv * hv
        for index, (got, want) in enumerate(zip(y[cout], expected)):
            if got is None:
                raise AssertionError(f"{path}: missing y[{cout}][{index}]")
            if got != want:
                raise AssertionError(
                    f"{path}: y[{cout}][{index}]={got}, direct convolution={want}"
                )
    return n, precision, cin_count, cout_count


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    paths = sorted(args.directory.glob("vectors_n*_int*_c*o*.csv"))
    if not paths:
        raise SystemExit(f"no vector dumps found in {args.directory}")
    for path in paths:
        n, precision, cin_count, cout_count = verify(path)
        print(f"PASS N={n} INT{precision} Cin={cin_count} Cout={cout_count} {path}")
    print(f"PASS files={len(paths)} independent_direct_convolution=pointwise")


if __name__ == "__main__":
    main()
