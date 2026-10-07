#!/usr/bin/env python3
"""Check frozen assets and report-to-paper links without running Vivado."""
import csv
import hashlib
import json
import sys
from decimal import Decimal
from pathlib import Path

sys.dont_write_bytecode = True
from audit_release_evidence import main as audit_reports


ROOT = Path(__file__).resolve().parents[1]


def rows(relative):
    with (ROOT / relative).open(encoding='utf-8-sig', newline='') as handle:
        return list(csv.DictReader(handle))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, label):
    if not condition:
        raise AssertionError(label)


def main():
    frozen = rows('reports/source_manifest.csv')
    require(len(frozen) == 51, 'Expected 51 retained frozen FACT source entries')
    for row in frozen:
        require(sha(ROOT / row['path']) == row['sha256'], row['path'])
    from audit_source_closure import audit as audit_sources
    audit_sources()
    assets = rows('docs/paper/ASSET_SHA256.csv')
    for row in assets:
        path = ROOT / row['Path']
        require(path.stat().st_size == int(row['Length']), row['Path'])
        require(sha(path) == row['SHA256'], row['Path'])
    audit_reports()
    routes = {(r['kind'], r['precision'], r['N']): r
              for r in rows('reports/implementation.csv')}
    fields = {
        'fact_routed.csv': ('fact', {'PeriodNs':'period_ns', 'WNSNs':'wns_ns',
            'WHSNs':'whs_ns', 'CLBLUTs':'clb_luts', 'CLBRegisters':'clb_registers',
            'DSPs':'dsp', 'BRAMTiles':'bram_tiles', 'PowerW':'vectorless_power_w'}),
        'direct_mac.csv': ('direct', {'PeriodNs':'period_ns', 'WNS':'wns_ns',
            'WHS':'whs_ns', 'LUT':'clb_luts', 'FF':'clb_registers',
            'DSP':'dsp', 'BRAM':'bram_tiles', 'PowerW':'vectorless_power_w'}),
        'compact_zero_pad.csv': ('zero_pad', {'PeriodNs':'period_ns', 'WNS':'wns_ns',
            'WHS':'whs_ns', 'LUT':'clb_luts', 'FF':'clb_registers',
            'DSP':'dsp', 'BRAM':'bram_tiles', 'PowerW':'vectorless_power_w'}),
    }
    comparisons = 0
    for name, (kind, mapping) in fields.items():
        for paper in rows('docs/paper/evidence/' + name):
            report = routes[(kind, paper['Precision'].replace('INT', ''), paper['N'])]
            for field, original in mapping.items():
                require(Decimal(paper[field]) == Decimal(report[original]), f'{name}: {field}')
                comparisons += 1
    tests = rows('reports/verification/fact_matrix/results.csv')
    for paper in rows('docs/paper/evidence/runtime_schedule.csv'):
        for precision in ('4', '8'):
            matches = [r for r in tests if r['Precision'] == precision
                       and all(r[k] == paper[k] for k in ('N', 'Cin', 'Cout'))]
            require(matches and all(r['Status'] == 'PASS' and r['Mismatches'] == '0'
                                    and r['CoreCycles'] == paper['CoreCycles'] for r in matches),
                    'Runtime schedule mismatch')
            comparisons += 1
    archived = {r['Cin']: r for r in rows('reports/parallel_zero_pad/runtime.csv')}
    for paper in rows('docs/paper/evidence/parallel_zero_pad.csv'):
        for field, value in paper.items():
            require(value == archived[paper['Cin']][field], 'Parallel comparator: ' + field)
            comparisons += 1
    for row in archived.values():
        for field in ('TimingReport', 'UtilReport', 'RouteReport', 'FunctionalMatrix', 'PowerReport'):
            require((ROOT / row[field]).is_file(), 'Missing comparator evidence: ' + row[field])
    from verify_cin_fusion_ablation import check_precision
    fused = { (str(r['Precision']), str(r['Cin'])): r
              for precision in (4, 8)
              for r in check_precision(ROOT / 'reports/verification/ablation', precision) }
    for paper in rows('docs/paper/evidence/fusion_ablation.csv'):
        original = fused[(paper['Precision'], paper['Cin'])]
        for field in paper:
            require(Decimal(paper[field]) == Decimal(str(original[field])), 'Fusion: ' + field)
            comparisons += 1
    print(json.dumps(dict(status='PASS', frozen_FACT_sources=len(frozen),
                         frozen_paper_assets=len(assets), evidence_comparisons=comparisons,
                         archived_FACT_cases=len(tests),
                         fresh_FACT_simulation=False, fresh_implementation=False), indent=2))


if __name__ == '__main__':
    main()
