#!/usr/bin/env python3
import csv
import re
import sys
from pathlib import Path


def close(actual: float, expected: float, label: str, tolerance: float = 1e-3) -> None:
    if abs(actual - expected) > tolerance:
        raise AssertionError(f"{label}: report={actual} csv={expected}")


def parse_timing(text: str, label: str) -> tuple[float, float]:
    match = re.search(
        r"WNS\(ns\).*?\n[-\s]+\n\s*([+-]?\d+\.\d+)\s+"
        r"[+-]?\d+\.\d+\s+\d+\s+\d+\s+([+-]?\d+\.\d+)",
        text, re.MULTILINE | re.DOTALL,
    )
    if not match:
        raise AssertionError(f"could not parse {label} WNS/WHS")
    return float(match.group(1)), float(match.group(2))


def parse_value(text: str, label: str) -> float:
    match = re.search(rf"\|\s*{re.escape(label)}\s*\|\s*([0-9.]+)", text)
    if not match:
        raise AssertionError(f"could not parse {label}")
    return float(match.group(1))


def check_row(root: Path, row: dict[str, str]) -> None:
    paths = {
        key: root / row[key]
        for key in ("contract", "timing_report", "utilization_report",
                    "route_report", "drc_report", "power_report")
    }
    for label, path in paths.items():
        if not path.is_file():
            raise AssertionError(f"missing {label}: {path}")
    timing = paths["timing_report"].read_text(errors="replace")
    util = paths["utilization_report"].read_text(errors="replace")
    route = paths["route_report"].read_text(errors="replace")
    power = paths["power_report"].read_text(errors="replace")
    wns, whs = parse_timing(timing, row["name"])
    close(wns, float(row["wns_ns"]), f'{row["name"]} WNS')
    close(whs, float(row["whs_ns"]), f'{row["name"]} WHS')
    for column, report_label in (
        ("clb_luts", "CLB LUTs"),
        ("clb_registers", "CLB Registers"),
        ("dsp", "DSPs"),
        ("bram_tiles", "Block RAM Tile"),
    ):
        close(parse_value(util, report_label), float(row[column]),
              f'{row["name"]} {column}')
    route_match = re.search(
        r"# of nets with routing errors\.*\s*:\s*(\d+)\s*:", route, re.IGNORECASE
    )
    if not route_match or int(route_match.group(1)) != 0:
        raise AssertionError(f'{row["name"]} route errors are not zero')
    close(parse_value(power, "Total On-Chip Power (W)"),
          float(row["vectorless_power_w"]), f'{row["name"]} power')
    confidence = re.search(r"Confidence Level\s*\|\s*([^|]+?)\s*\|", power)
    if row["power_confidence"] != "Low" or not confidence or confidence.group(1).strip() != "Low":
        raise AssertionError(f'{row["name"]} power confidence is not Low')


def main() -> None:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    csv_path = root / "reports/implementation.csv"
    rows = list(csv.DictReader(csv_path.open(newline="", encoding="utf-8-sig")))
    expected = {("fact", "4"): 3, ("fact", "8"): 3,
                ("direct", "4"): 3, ("direct", "8"): 3,
                ("zero_pad", "4"): 3, ("zero_pad", "8"): 3}
    actual: dict[tuple[str, str], int] = {}
    for row in rows:
        check_row(root, row)
        key = (row["kind"], row["precision"])
        actual[key] = actual.get(key, 0) + 1
    if len(rows) != 18 or actual != expected:
        raise AssertionError(f"implementation matrix shape is invalid: rows={len(rows)} groups={actual}")
    fact = list(csv.DictReader(
        (root / "reports/verification/fact_matrix/results.csv").open(newline="", encoding="ascii")
    ))
    if len(fact) != 186 or any(r["Status"] != "PASS" or int(r["Mismatches"]) != 0 for r in fact):
        raise AssertionError("FACT functional matrix is not 186/186 PASS")
    zero = list(csv.DictReader(
        (root / "reports/verification/zero_pad/results.csv").open(newline="", encoding="ascii")
    ))
    if len(zero) != 54 or any(r["Status"] != "PASS" for r in zero):
        raise AssertionError("zero-padding matrix is not 54/54 PASS")
    print("EVIDENCE_AUDIT_PASS routed=18 fact_matrix=186 zero_pad_matrix=54")


if __name__ == "__main__":
    main()
