#!/usr/bin/env python3
"""Generate full-length N=1024 radix-4 twiddles for the p520 baseline."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


P = 520193
DATA_W = 19
N = 1024
OMEGA = 421701
OMEGA_INV = 475157
LANES = 32
TWIDDLES_PER_LANE = 3


def pack_word(values: list[int]) -> str:
    word = 0
    for index, value in enumerate(values):
        if not 0 <= value < P:
            raise ValueError(f"twiddle value outside p520 field: {value}")
        word |= value << (index * DATA_W)
    digits = ((len(values) * DATA_W) + 3) // 4
    return f"{word:0{digits}X}"


def build_words(root: int) -> list[str]:
    words: list[str] = []
    stages = 5
    batches_per_stage = (N // 4) // LANES
    for stage in range(stages):
        length = N >> (2 * stage)
        quarter = length // 4
        step = N // length
        for batch in range(batches_per_stage):
            packed: list[int] = []
            for lane in range(LANES):
                butterfly = batch * LANES + lane
                offset = butterfly % quarter
                for factor in (1, 2, 3):
                    packed.append(pow(root, factor * step * offset, P))
            words.append(pack_word(packed))
    return words


def write_words(path: Path, words: list[str]) -> str:
    payload = ("\n".join(words) + "\n").encode("ascii")
    path.write_bytes(payload)
    return hashlib.sha256(payload).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-root", type=Path, default=Path("."))
    args = parser.parse_args()

    if pow(OMEGA, N, P) != 1 or pow(OMEGA, N // 2, P) == 1:
        raise ValueError("configured p520 omega is not a primitive N=1024 root")
    if (OMEGA * OMEGA_INV) % P != 1:
        raise ValueError("configured omega inverse is inconsistent")

    out_dir = args.out_root / "rom" / "zero_pad_p520_schedule"
    out_dir.mkdir(parents=True, exist_ok=True)
    fwd = out_dir / "twiddle_fwd_1024.mem"
    inv = out_dir / "twiddle_inv_1024.mem"
    fwd_words = build_words(OMEGA)
    inv_words = build_words(OMEGA_INV)
    manifest = {
        "architecture": "zero_padded_full_length_radix4_ntt_baseline",
        "prime": P,
        "n": N,
        "omega": OMEGA,
        "omega_inv": OMEGA_INV,
        "lanes": LANES,
        "data_w": DATA_W,
        "depth_per_direction": len(fwd_words),
        "word_bits": LANES * TWIDDLES_PER_LANE * DATA_W,
        "files": {
            fwd.name: {"sha256": write_words(fwd, fwd_words)},
            inv.name: {"sha256": write_words(inv, inv_words)},
        },
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="ascii")
    print(f"wrote {out_dir / 'manifest.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
