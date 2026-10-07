#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import math
import re
from dataclasses import dataclass
from pathlib import Path


TWIDDLES_PER_LANE = 3


@dataclass(frozen=True)
class PrimeDomain:
    name: str
    params_path: Path
    rom_root: Path


@dataclass(frozen=True)
class StageInfo:
    stage: int
    radix: int
    length: int
    batches: int
    addr_base: int


def parse_sv_int(expr: str) -> int:
    text = expr.strip()
    m = re.match(r"(?:(\d+)'([dDhHbB]))?([0-9a-fA-F_xXzZ]+)$", text)
    if not m:
        raise ValueError(f"cannot parse SV integer expression: {expr!r}")
    base_ch = (m.group(2) or "d").lower()
    raw = m.group(3).replace("_", "")
    if "x" in raw.lower() or "z" in raw.lower():
        raise ValueError(f"unknown-valued SV integer expression: {expr!r}")
    base = {"d": 10, "h": 16, "b": 2}[base_ch]
    return int(raw, base)


def parse_params(path: Path) -> dict[str, int]:
    constants: dict[str, int] = {}
    pattern = re.compile(r"localparam\s+[^=]*?\b(MREC_[A-Za-z0-9_]+)\s*=\s*([^;]+);")
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("//", 1)[0].strip()
        m = pattern.search(line)
        if not m:
            continue
        name, expr = m.group(1), m.group(2).strip()
        try:
            constants[name] = parse_sv_int(expr)
        except ValueError:
            pass
    return constants


def is_prime(n: int) -> bool:
    if n < 2:
        return False
    if n % 2 == 0:
        return n == 2
    d = 3
    while d * d <= n:
        if n % d == 0:
            return False
        d += 2
    return True


def stage_infos(r: int, lanes: int) -> list[StageInfo]:
    if r <= 0 or (r & (r - 1)) != 0:
        raise ValueError(f"R={r} is not a power of two")
    exp = int(math.log2(r))
    stages: list[tuple[int, int]] = []
    length = r
    if exp & 1:
        stages.append((2, length))
        length //= 2
    while length > 1:
        stages.append((4, length))
        length //= 4

    out: list[StageInfo] = []
    addr = 0
    for stage, (radix, length) in enumerate(stages):
        butterflies = r // radix
        batches = butterflies // lanes
        if batches * lanes != butterflies:
            raise ValueError(f"R={r} radix{radix} not divisible by LANES={lanes}")
        out.append(StageInfo(stage=stage, radix=radix, length=length, batches=batches, addr_base=addr))
        addr += batches
    return out


def pack_word(values: list[int], data_w: int) -> str:
    word = 0
    for index, value in enumerate(values):
        if not 0 <= value < (1 << data_w):
            raise ValueError(f"value {value} out of {data_w}-bit range")
        word |= value << (index * data_w)
    hex_digits = ((len(values) * data_w) + 3) // 4
    return f"{word:0{hex_digits}X}"


def build_twiddle_words(
    p: int,
    data_w: int,
    roots: dict[int, int],
    inv_roots: dict[int, int],
    r: int,
    lanes: int,
    inverse: bool,
    coset_untwist: bool = False,
) -> list[str]:
    root = inv_roots[r] if inverse else roots[r]
    psi_inv = inv_roots[2 * r] if inverse and coset_untwist else None
    coset_high_ratio = pow(psi_inv, r // 2, p) if psi_inv is not None else None
    words: list[str] = []
    for info in stage_infos(r, lanes):
        if info.radix == 2:
            half = info.length // 2
            step = r // info.length
            for batch in range(info.batches):
                packed: list[int] = []
                for lane in range(lanes):
                    butterfly_index = batch * lanes + lane
                    offset = butterfly_index % half
                    w1 = pow(root, step * offset, p)
                    if inverse and coset_untwist and info.stage == 0:
                        low_scale = pow(psi_inv, offset, p)
                        packed.extend([(w1 * low_scale) % p, low_scale, coset_high_ratio])
                    else:
                        packed.extend([w1, 1, 1])
                words.append(pack_word(packed, data_w))
        else:
            quarter = info.length // 4
            step = r // info.length
            for batch in range(info.batches):
                packed = []
                for lane in range(lanes):
                    butterfly_index = batch * lanes + lane
                    offset = butterfly_index % quarter
                    for factor in (1, 2, 3):
                        packed.append(pow(root, factor * step * offset, p))
                words.append(pack_word(packed, data_w))
    return words


def build_fact_psi_words(
    p: int,
    data_w: int,
    roots: dict[int, int],
    inv_roots: dict[int, int],
    r: int,
    word_lanes: int,
    inverse: bool,
) -> list[str]:
    root = inv_roots[2 * r] if inverse else roots[2 * r]
    words: list[str] = []
    for word_idx in range(r // word_lanes):
        packed = [pow(root, word_idx * word_lanes + lane, p) for lane in range(word_lanes)]
        words.append(pack_word(packed, data_w))
    return words


def read_mem_words(path: Path) -> list[str]:
    return [line.strip().upper() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def add(rows: list[dict[str, str]], domain: str, check: str, status: str, detail: str, evidence: Path | str) -> None:
    rows.append(
        {
            "domain": domain,
            "check": check,
            "status": status,
            "detail": detail,
            "evidence": str(evidence),
        }
    )


def audit_domain(root: Path, domain: PrimeDomain, rows: list[dict[str, str]]) -> None:
    params = parse_params(domain.params_path)
    p = params["MREC_P"]
    data_w = params["MREC_DATA_W"]
    pseudo_c = params["MREC_PSEUDO_C"]
    mu = params.get("MREC_MU")
    roots = {n: params[f"MREC_OMEGA_{n}"] for n in (128, 256, 512, 1024)}
    inv_roots = {n: params[f"MREC_OMEGA_INV_{n}"] for n in (128, 256, 512, 1024)}
    ninv = {n: params[f"MREC_NINV_{n}"] for n in (128, 256, 512, 1024)}

    add(rows, domain.name, "prime", "PASS" if is_prime(p) else "FAIL", f"p={p}", domain.params_path)
    expected_c = (1 << data_w) - p
    add(
        rows,
        domain.name,
        "pseudo_mersenne_c",
        "PASS" if pseudo_c == expected_c else "FAIL",
        f"PSEUDO_C={pseudo_c}, expected 2^{data_w}-p={expected_c}",
        domain.params_path,
    )
    if mu is not None:
        barrett_floor = (1 << (2 * data_w)) // p
        status = "PASS" if mu == barrett_floor else "INFO"
        add(
            rows,
            domain.name,
            "mu_reference",
            status,
            f"MREC_MU={mu}, floor(2^(2*DATA_W)/p)={barrett_floor}; active arith packages use pseudo-Mersenne folding",
            domain.params_path,
        )

    j = params["MREC_J"]
    j_inv = params["MREC_J_INV"]
    add(rows, domain.name, "j_inverse", "PASS" if (j * j_inv) % p == 1 else "FAIL", f"J*J_INV mod p={(j*j_inv)%p}", domain.params_path)
    add(rows, domain.name, "j_square_minus_one", "PASS" if (j * j) % p == p - 1 else "FAIL", f"J^2 mod p={(j*j)%p}, p-1={p-1}", domain.params_path)
    add(rows, domain.name, "inv2", "PASS" if (2 * params["MREC_INV2"]) % p == 1 else "FAIL", f"2*INV2 mod p={(2*params['MREC_INV2'])%p}", domain.params_path)
    add(rows, domain.name, "inv4", "PASS" if (4 * params["MREC_INV4"]) % p == 1 else "FAIL", f"4*INV4 mod p={(4*params['MREC_INV4'])%p}", domain.params_path)

    for n in (128, 256, 512, 1024):
        omega = roots[n]
        omega_inv = inv_roots[n]
        root_ok = pow(omega, n, p) == 1 and pow(omega, n // 2, p) != 1
        inv_ok = (omega * omega_inv) % p == 1
        ninv_ok = (n * ninv[n]) % p == 1
        add(rows, domain.name, f"omega_order_{n}", "PASS" if root_ok else "FAIL", f"omega={omega}, omega^N={pow(omega,n,p)}, omega^(N/2)={pow(omega,n//2,p)}", domain.params_path)
        add(rows, domain.name, f"omega_inverse_{n}", "PASS" if inv_ok else "FAIL", f"omega*omega_inv mod p={(omega*omega_inv)%p}", domain.params_path)
        add(rows, domain.name, f"ninv_{n}", "PASS" if ninv_ok else "FAIL", f"N*NINV mod p={(n*ninv[n])%p}", domain.params_path)

    manifest = domain.rom_root / "zest_schedule" / "zest_radix24_manifest.json"
    if manifest.exists():
        data = json.loads(manifest.read_text(encoding="utf-8"))
        add(rows, domain.name, "rom_manifest_exists", "PASS", f"files={len(data.get('files', {}))}", manifest)
    else:
        add(rows, domain.name, "rom_manifest_exists", "FAIL", "missing zest_radix24_manifest.json", manifest)

    for r in (128, 256, 512):
        for lanes in (4, 8, 16):
            lane_suffix = "" if lanes == 16 else f"_l{lanes}"
            for inverse in (False, True):
                suffix = "inv" if inverse else "fwd"
                expected = build_twiddle_words(p, data_w, roots, inv_roots, r, lanes, inverse)
                path = domain.rom_root / "zest_schedule" / f"zest_radix24_twiddle_{suffix}_r{r}{lane_suffix}.mem"
                if path.exists():
                    got = read_mem_words(path)
                    status = "PASS" if got == expected else "FAIL"
                    add(rows, domain.name, f"twiddle_{suffix}_r{r}_l{lanes}", status, f"depth={len(got)}, expected_depth={len(expected)}", path)
                else:
                    add(rows, domain.name, f"twiddle_{suffix}_r{r}_l{lanes}", "FAIL", "missing ROM", path)
                if inverse:
                    expected_coset = build_twiddle_words(p, data_w, roots, inv_roots, r, lanes, True, coset_untwist=True)
                    cpath = domain.rom_root / "zest_schedule" / f"zest_radix24_twiddle_inv_coset_r{r}{lane_suffix}.mem"
                    if cpath.exists():
                        got = read_mem_words(cpath)
                        status = "PASS" if got == expected_coset else "FAIL"
                        add(rows, domain.name, f"twiddle_inv_coset_r{r}_l{lanes}", status, f"depth={len(got)}, expected_depth={len(expected_coset)}", cpath)
                    else:
                        add(rows, domain.name, f"twiddle_inv_coset_r{r}_l{lanes}", "FAIL", "missing ROM", cpath)
            for word_lanes in (lanes, 2 * lanes):
                for inverse in (False, True):
                    suffix = "psi_inv" if inverse else "psi"
                    expected = build_fact_psi_words(p, data_w, roots, inv_roots, r, word_lanes, inverse)
                    path = domain.rom_root / "fact" / f"fact_{suffix}_word{word_lanes}_r{r}{lane_suffix}.mem"
                    if path.exists():
                        got = read_mem_words(path)
                        status = "PASS" if got == expected else "FAIL"
                        add(rows, domain.name, f"fact_{suffix}_word{word_lanes}_r{r}_l{lanes}", status, f"depth={len(got)}, expected_depth={len(expected)}", path)
                    else:
                        add(rows, domain.name, f"fact_{suffix}_word{word_lanes}_r{r}_l{lanes}", "FAIL", "missing ROM", path)


def audit_crt(root: Path, rows: list[dict[str, str]]) -> None:
    path = root / "rtl" / "common" / "ntt46_fact_ip_v1_crt2_reconstruct.sv"
    text = path.read_text(encoding="utf-8")
    params: dict[str, int] = {}
    for name in ("P1", "P2", "P2_INV_MOD_P1", "P1_INV_MOD_P2"):
        m = re.search(rf"parameter\s+longint\s+unsigned\s+{name}\s*=\s*([0-9]+)", text)
        if not m:
            add(rows, "INT8_CRT", f"crt_param_{name}", "FAIL", "missing parameter", path)
            return
        params[name] = int(m.group(1))
    p1 = params["P1"]
    p2 = params["P2"]
    p2_inv = params["P2_INV_MOD_P1"]
    p1_inv = params["P1_INV_MOD_P2"]
    add(rows, "INT8_CRT", "p2_inv_mod_p1", "PASS" if (p2 * p2_inv) % p1 == 1 else "FAIL", f"P2*inv mod P1={(p2*p2_inv)%p1}", path)
    add(rows, "INT8_CRT", "p1_inv_mod_p2", "PASS" if (p1 * p1_inv) % p2 == 1 else "FAIL", f"P1*inv mod P2={(p1*p1_inv)%p2}", path)
    samples = [-1_000_000, -255, -1, 0, 1, 255, 1_000_000]
    ok = True
    for value in samples:
        r1 = value % p1
        r2 = value % p2
        term1 = r1 * p2 * p2_inv
        term2 = r2 * p1 * p1_inv
        product = p1 * p2
        mod = (term1 + term2) % product
        signed = mod - product if mod > (product >> 1) else mod
        if signed != value:
            ok = False
            break
    add(rows, "INT8_CRT", "crt_signed_samples", "PASS" if ok else "FAIL", f"samples={len(samples)}", path)


def audit_public_architecture(root: Path, rows: list[dict[str, str]]) -> None:
    p254_params = parse_params(root / "rtl" / "p254" / "ntt46_mrec_params_pkg.sv")
    p520_params = parse_params(root / "rtl" / "p520" / "p520_ntt46_mrec_params_pkg.sv")
    unified_dir = root / "rtl" / "unified"
    core_path = unified_dir / "ntt46_fact_lean_ip_int8_parallel_prime_core.sv"
    wrapper_path = unified_dir / "ntt46_fact_lean_ip_int8_axi_lite_core.sv"
    top_path = unified_dir / "ntt46_fact_lean_ip_unified_axi_lite_core.sv"
    files = (core_path, wrapper_path, top_path)
    for path in files:
        if not path.is_file():
            add(rows, "INT8_PUBLIC", f"{path.stem}_exists", "FAIL", "missing RTL", path)
            return

    core_text = core_path.read_text(encoding="utf-8")
    wrapper_text = wrapper_path.read_text(encoding="utf-8")
    top_text = top_path.read_text(encoding="utf-8")
    compact_core = re.sub(r"\s+", "", core_text)
    compact_wrapper = re.sub(r"\s+", "", wrapper_text)
    compact_top = re.sub(r"\s+", "", top_text)

    def check(name: str, condition: bool, detail: str, evidence: Path) -> None:
        add(rows, "INT8_PUBLIC", name, "PASS" if condition else "FAIL", detail, evidence)

    for name, expected in (("P1", p520_params["MREC_P"]), ("P2", p254_params["MREC_P"])):
        match = re.search(rf"localparam\s+longint\s+unsigned\s+{name}\s*=\s*([0-9]+)", core_text)
        value = int(match.group(1)) if match else None
        check(
            f"parallel_core_{name.lower()}_prime",
            value == expected,
            f"RTL={value}, package={expected}",
            core_path,
        )

    p520_instances = len(re.findall(r"\bntt46_p520_ntt46_fact_lean_ip_int4_local_core\s*#\s*\(", core_text))
    p254_instances = len(re.findall(r"(?<!p520_)\bntt46_fact_lean_ip_int4_local_core\s*#\s*\(", core_text))
    check("one_p520_residue_engine", p520_instances == 1, f"instances={p520_instances}", core_path)
    check("one_p254_residue_engine", p254_instances == 1, f"instances={p254_instances}", core_path)

    readout_connections = compact_core.count(".READOUT_PIPELINE(INT8_OUTPUT_PIPELINE)")
    check(
        "output_pipeline_reaches_both_residue_engines",
        readout_connections == 2,
        f"connections={readout_connections}",
        core_path,
    )
    check(
        "output_pipeline_controls_generate_branch",
        "if(INT8_OUTPUT_PIPELINE)begin:g_output_pipeline" in compact_core,
        "registered and combinational CRT branches are parameter-selected",
        core_path,
    )
    check(
        "registered_prime_crt_present",
        "ntt46_fact_ip_v1_crt2_reconstruct_pipeu_crt_pipe(" in compact_core,
        "pipelined CRT instance found",
        core_path,
    )
    check(
        "combinational_prime_crt_present",
        "ntt46_fact_ip_v1_crt2_reconstructu_crt(" in compact_core,
        "combinational CRT instance found",
        core_path,
    )
    check(
        "public_wrapper_selects_documented_readout",
        ".INT8_OUTPUT_PIPELINE(1'b0)" in compact_wrapper,
        "public wrapper selects combinational native-read CRT",
        wrapper_path,
    )
    check(
        "public_wrapper_instantiates_parallel_core",
        "ntt46_fact_lean_ip_int8_parallel_prime_core#(" in compact_wrapper,
        "parallel two-prime core is the only INT8 datapath",
        wrapper_path,
    )
    check(
        "unified_top_maps_precision_8",
        "elseif(PRECISION==8)begin:g_int8" in compact_top
        and "ntt46_fact_lean_ip_int8_axi_lite_core#(" in compact_top,
        "PRECISION=8 maps to the public INT8 wrapper",
        top_path,
    )
    check(
        "capability_prime_registers_match",
        "REG_PRIME0:read_data_c=32'd520193;" in compact_wrapper
        and "REG_PRIME1:read_data_c=32'd254977;" in compact_wrapper,
        "AXI-Lite capability registers expose the compiled prime set",
        wrapper_path,
    )
    public_text = "\n".join(path.read_text(encoding="utf-8") for path in unified_dir.glob("*.sv"))
    forbidden = re.findall(r"dual[_ -]?lean|area[_ -]?v[0-9]|sequential[_ -]?prime", public_text, re.IGNORECASE)
    check(
        "single_public_int8_architecture",
        not forbidden,
        f"historical-mode tokens={len(forbidden)}",
        unified_dir,
    )


def write_outputs(root: Path, tag: str, rows: list[dict[str, str]]) -> tuple[Path, Path]:
    report_dir = root / "build" / "parameter_audit"
    report_dir.mkdir(parents=True, exist_ok=True)
    csv_path = report_dir / f"fact_lean_ip_ntt_param_audit_{tag}.csv"
    md_path = report_dir / f"FACT_LEAN_IP_NTT_PARAM_AUDIT_{tag}.md"
    for row in rows:
        try:
            row["evidence"] = Path(row["evidence"]).resolve().relative_to(root).as_posix()
        except (OSError, ValueError):
            pass
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["domain", "check", "status", "detail", "evidence"])
        writer.writeheader()
        writer.writerows(rows)

    fail_count = sum(1 for row in rows if row["status"] == "FAIL")
    pass_count = sum(1 for row in rows if row["status"] == "PASS")
    info_count = sum(1 for row in rows if row["status"] == "INFO")
    verdict = "PASS" if fail_count == 0 else "FAIL"
    lines = [
        f"# FACT Lean-IP NTT Parameter Audit ({tag})",
        "",
        f"- Overall: {verdict}",
        f"- PASS checks: {pass_count}",
        f"- INFO checks: {info_count}",
        f"- FAIL checks: {fail_count}",
        "",
        "Scope: mathematical and ROM-content audit for p254/p520, plus public INT8 architecture wiring.",
        "This does not run RTL simulation or Vivado implementation.",
        "",
        "## Summary By Domain",
        "",
        "| Domain | PASS | INFO | FAIL |",
        "|---|---:|---:|---:|",
    ]
    domains = sorted({row["domain"] for row in rows})
    for domain in domains:
        subset = [row for row in rows if row["domain"] == domain]
        lines.append(
            f"| {domain} | {sum(r['status']=='PASS' for r in subset)} | "
            f"{sum(r['status']=='INFO' for r in subset)} | {sum(r['status']=='FAIL' for r in subset)} |"
        )
    lines.extend(["", "## Failed Checks", ""])
    failed = [row for row in rows if row["status"] == "FAIL"]
    if failed:
        lines.extend(["| Domain | Check | Detail | Evidence |", "|---|---|---|---|"])
        for row in failed:
            lines.append(f"| {row['domain']} | {row['check']} | {row['detail']} | `{row['evidence']}` |")
    else:
        lines.append("None.")
    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- p520 and p254 active arithmetic packages use pseudo-Mersenne folding with `PSEUDO_C=2^DATA_W-p`; `MREC_MU` is recorded as an informational reference.",
            "- Twiddle and FACT psi ROM checks regenerate the packed lane-major words from the RTL package constants and compare them byte-for-byte against the committed `.mem` files.",
            "- This is provenance evidence for parameter correctness. End-to-end convolution correctness still comes from xsim/Python golden checks.",
            "",
            "## Artifacts",
            "",
            f"- CSV: `build/parameter_audit/{csv_path.name}`",
            f"- Script: `scripts/audit_parameters.py`",
        ]
    )
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return csv_path, md_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit FACT Lean-IP NTT parameters and ROM assets")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--tag", default="20260709")
    args = parser.parse_args()
    root = args.root.resolve()

    rows: list[dict[str, str]] = []
    domains = [
        PrimeDomain(
            name="p254",
            params_path=root / "rtl" / "p254" / "ntt46_mrec_params_pkg.sv",
            rom_root=root / "rom" / "p254",
        ),
        PrimeDomain(
            name="p520",
            params_path=root / "rtl" / "p520" / "p520_ntt46_mrec_params_pkg.sv",
            rom_root=root / "rom" / "p520",
        ),
    ]
    for domain in domains:
        audit_domain(root, domain, rows)
    audit_crt(root, rows)
    audit_public_architecture(root, rows)
    csv_path, md_path = write_outputs(root, args.tag, rows)
    fail_count = sum(1 for row in rows if row["status"] == "FAIL")
    print(f"Wrote {csv_path}")
    print(f"Wrote {md_path}")
    print("Overall: " + ("PASS" if fail_count == 0 else "FAIL"))
    return 0 if fail_count == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
