#!/usr/bin/env python3
"""Recompute archived outputs; no Vivado or third-party Python packages needed."""
import csv
import importlib.util
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from check_fact_output import read_dump, build_expected

ROOT = Path(__file__).resolve().parents[1]


def main():
    with (ROOT / 'reports/verification/fact_matrix/results.csv').open(
            encoding='utf-8-sig', newline='') as f:
        cases = list(csv.DictReader(f))
    assert len(cases) == 186
    outputs = 0
    for row in cases:
        path = ROOT / row['Dump'].replace('\\', '/')
        meta, actual = read_dump(path)
        assert actual == build_expected(meta), f'Coefficient mismatch: {path.name}'
        assert len(actual) == int(row['ComparedOutputs'])
        outputs += len(actual)
    spec = importlib.util.spec_from_file_location(
        'zero_checker', ROOT / 'baselines/zero_pad/verify_zero_pad_vector_dumps.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    zero_files = sorted((ROOT / 'reports/verification/zero_pad').rglob(
        'vectors_n*_int*_c*o*.csv'))
    assert len(zero_files) == 54, 'Missing compact zero-pad vectors'
    zero_outputs = 0
    for path in zero_files:
        n, _, _, cout = module.verify(path)
        zero_outputs += n * cout
    result = {'status': 'PASS', 'FACT_cases': len(cases), 'FACT_outputs': outputs,
              'compact_zero_pad_cases': len(zero_files),
              'compact_zero_pad_outputs': zero_outputs,
              'mismatches': 0, 'fresh_RTL_simulation': False}
    out = ROOT / 'build/audit'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'archived_output_recheck.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
