#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path


def read_output(path: Path) -> dict[tuple[int, int], int]:
    with path.open(encoding="ascii") as handle:
        rows = [line for line in handle if not line.startswith("#")]
    values: dict[tuple[int, int], int] = {}
    for row in csv.DictReader(rows):
        values[(int(row["cout"]), int(row["index"]))] = int(row["y"])
    return values


def read_core_cycles(path: Path) -> int:
    text = path.read_text(errors="replace")
    matches = re.findall(r"int8_valid_task PASS .*?core_compute_cycles=(\d+)", text)
    if not matches:
        raise AssertionError(f"missing core cycle marker in {path}")
    return int(matches[-1])


def check_precision(root: Path, precision: int) -> list[dict[str, object]]:
    singles = []
    for channel in range(4):
        singles.append(
            read_output(
                root
                / f"p{precision}_n1024_c1o1_b{channel}"
                / "fact_output.csv"
            )
        )

    results = []
    single_cycles = [
        read_core_cycles(root / f"p{precision}_n1024_c1o1_b{channel}" / "xsim.log")
        for channel in range(4)
    ]
    for cin in (1, 2, 4):
        fused_dir = root / f"p{precision}_n1024_c{cin}o1_b0"
        fused_cycles = read_core_cycles(fused_dir / "xsim.log")
        fused = read_output(
            fused_dir / "fact_output.csv"
        )
        for key, got in fused.items():
            repeated = sum(single[key] for single in singles[:cin])
            if got != repeated:
                raise AssertionError(
                    f"INT{precision} Cin={cin} {key}: fused={got}, repeated={repeated}"
                )
        repeated_cycles = sum(single_cycles[:cin])
        saving = 100.0 * (repeated_cycles - fused_cycles) / repeated_cycles
        results.append(
            {
                "Precision": precision,
                "N": 1024,
                "Cin": cin,
                "Cout": 1,
                "FusedCoreCycles": fused_cycles,
                "RepeatedSingleChannelCoreCycles": repeated_cycles,
                "CycleSavingPercent": f"{saving:.3f}",
                "ComparedOutputs": len(fused),
                "Mismatches": 0,
            }
        )
    return results


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("xsim_root", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    rows = check_precision(args.xsim_root, 4) + check_precision(args.xsim_root, 8)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    for row in rows:
        print(
            f"PASS INT{row['Precision']} Cin={row['Cin']} "
            f"fused={row['FusedCoreCycles']} repeated={row['RepeatedSingleChannelCoreCycles']} "
            f"saving={row['CycleSavingPercent']}% outputs={row['ComparedOutputs']}"
        )


if __name__ == "__main__":
    main()
