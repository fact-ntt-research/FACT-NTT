#!/usr/bin/env python3
"""Check retained frozen source hashes and the public top's reference closure.

This lexical audit follows module/package references across all generate branches.
It is not elaboration or a claim that every branch exists in each configuration.
"""
import csv
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOP = 'rtl/unified/ntt46_fact_lean_ip_unified_axi_lite_core.sv'


def records(name):
    with (ROOT / 'reports' / name).open(encoding='utf-8-sig', newline='') as f:
        return {r['path']: r['sha256'] for r in csv.DictReader(f)}


def audit():
    active = records('source_manifest.csv')
    assert len(active) == 51, 'Expected 51 frozen FACT sources'
    texts = {}
    for path in (ROOT / 'rtl').rglob('*.sv'):
        name = path.relative_to(ROOT).as_posix()
        assert name in active, f'Unexpected source: {name}'
        assert hashlib.sha256(path.read_bytes()).hexdigest() == active[name], name
        texts[name] = re.sub(r'/\*.*?\*/|//[^\n]*', '',
                             path.read_text(encoding='utf-8-sig'), flags=re.S)
    assert set(texts) == set(active), 'Missing active source'
    definitions = {}
    for name, text in texts.items():
        for symbol in re.findall(r'\b(?:module|package)\s+(\w+)', text):
            assert symbol not in definitions, f'Duplicate definition: {symbol}'
            definitions[symbol] = name
    edges = {name: sorted({definitions[s] for s in re.findall(r'\b\w+\b', text)
                          if s in definitions and definitions[s] != name})
             for name, text in texts.items()}
    seen, todo = set(), [TOP]
    while todo:
        name = todo.pop()
        if name not in seen:
            seen.add(name)
            todo.extend(edges[name])
    assert seen == set(active), f'Unreferenced RTL: {sorted(set(active)-seen)}'
    print('SOURCE_CLOSURE_PASS files=51 frozen_bytes=unchanged')
    return edges


if __name__ == '__main__':
    graph = audit()
    out = ROOT / 'build' / 'audit'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'source_reference_graph.json').write_text(json.dumps(graph, indent=2))
