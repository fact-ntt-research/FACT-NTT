#!/usr/bin/env python3
"""Reference host sequence for the FACT native interface.

The abstract Transport class deliberately does not claim a board driver or DMA.
Run this file without arguments to validate and print a dry-run transaction plan.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol, Sequence


REG_CTRL = 0x00
REG_STATUS = 0x04
REG_CFG_NH = 0x08
REG_CFG_CIN = 0x0C
REG_CFG_COUT = 0x10
REG_ERROR_CODE = 0x24
REG_IP_ID = 0x28
CTRL_START = 1
CTRL_CLEAR = 2
STATUS_BUSY = 1 << 1
STATUS_DONE = 1 << 2
STATUS_ERROR_MASK = 0x38
IP_ID = 0x46414354


class Transport(Protocol):
    def reg_write(self, offset: int, value: int) -> None: ...
    def reg_read(self, offset: int) -> int: ...
    def preload(self, is_h: bool, cin: int, cout: int, index: int, data: int) -> None: ...
    def read_output(self, cout: int, index: int) -> int: ...


@dataclass(frozen=True)
class Build:
    precision: int
    n: int

    @property
    def r(self) -> int:
        return self.n // 2

    def validate(self) -> None:
        if self.precision not in (4, 8):
            raise ValueError("precision must select an INT4 or INT8 bitstream")
        if self.n not in (256, 512, 1024):
            raise ValueError("n must select a 256, 512, or 1024 bitstream")


def validate_task(build: Build, nh: int, x: Sequence[Sequence[int]],
                  h: Sequence[Sequence[Sequence[int]]]) -> tuple[int, int]:
    build.validate()
    cin = len(x)
    cout = len(h)
    if cin not in (1, 2, 4) or cout not in (1, 2, 4):
        raise ValueError("Cin and Cout must each be 1, 2, or 4")
    if not 1 <= nh < build.r:
        raise ValueError(f"Nh must be in [1, {build.r - 1}]")
    if any(len(channel) != build.r for channel in x):
        raise ValueError("each X channel must contain R samples")
    if len(h) != cout or any(len(bank) != cin for bank in h):
        raise ValueError("H shape must be [Cout][Cin][R]")
    if any(len(taps) != build.r for bank in h for taps in bank):
        raise ValueError("each H bank must contain R storage entries")
    lo, hi = (-(1 << (build.precision - 1)), (1 << (build.precision - 1)) - 1)
    values = [value for channel in x for value in channel]
    values += [value for bank in h for taps in bank for value in taps]
    if any(value < lo or value > hi for value in values):
        raise ValueError(f"input samples must be signed INT{build.precision}")
    return cin, cout


def run_task(io: Transport, build: Build, nh: int,
             x: Sequence[Sequence[int]],
             h: Sequence[Sequence[Sequence[int]]]) -> list[list[int]]:
    cin, cout = validate_task(build, nh, x, h)
    if io.reg_read(REG_IP_ID) != IP_ID:
        raise RuntimeError("FACT IP_ID mismatch; check the mapped bitstream")
    io.reg_write(REG_CTRL, CTRL_CLEAR)
    io.reg_write(REG_CFG_NH, nh)
    io.reg_write(REG_CFG_CIN, cin)
    io.reg_write(REG_CFG_COUT, cout)
    for channel in range(cin):
        for index, value in enumerate(x[channel]):
            io.preload(False, channel, 0, index, value)
    for output in range(cout):
        for channel in range(cin):
            for index, value in enumerate(h[output][channel]):
                io.preload(True, channel, output, index, value if index < nh else 0)
    io.reg_write(REG_CTRL, CTRL_START)
    while True:
        status = io.reg_read(REG_STATUS)
        if status & STATUS_ERROR_MASK:
            raise RuntimeError(f"FACT task failed, error={io.reg_read(REG_ERROR_CODE)}")
        if status & STATUS_DONE:
            break
    return [[io.read_output(output, index) for index in range(build.n)]
            for output in range(cout)]


class DryRunTransport:
    def __init__(self) -> None:
        self.registers = {REG_IP_ID: IP_ID, REG_STATUS: STATUS_DONE}
        self.preloads = 0
        self.reads = 0

    def reg_write(self, offset: int, value: int) -> None:
        self.registers[offset] = value

    def reg_read(self, offset: int) -> int:
        return self.registers.get(offset, 0)

    def preload(self, is_h: bool, cin: int, cout: int, index: int, data: int) -> None:
        self.preloads += 1

    def read_output(self, cout: int, index: int) -> int:
        self.reads += 1
        return 0


if __name__ == "__main__":
    selected = Build(precision=8, n=256)
    x_data = [[0] * selected.r for _ in range(2)]
    h_data = [[[0] * selected.r for _ in range(2)] for _ in range(4)]
    dry = DryRunTransport()
    output = run_task(dry, selected, nh=17, x=x_data, h=h_data)
    assert len(output) == 4 and all(len(channel) == selected.n for channel in output)
    assert dry.preloads == (2 * selected.r) + (4 * 2 * selected.r)
    assert dry.reads == 4 * selected.n
    print(f"FACT_HOST_SEQUENCE_PASS preloads={dry.preloads} reads={dry.reads}")
