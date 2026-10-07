"""Host-only regression for complete, zero-tailed H preload; no RTL simulation."""
import sys
import unittest

sys.dont_write_bytecode = True
from fact_ntt_host_sequence import Build, DryRunTransport, run_task


class CaptureTransport(DryRunTransport):
    def __init__(self):
        super().__init__()
        self.h_memory = {}

    def preload(self, is_h, cin, cout, index, data):
        super().preload(is_h, cin, cout, index, data)
        if is_h:
            self.h_memory[cout, cin, index] = data


class HostSequenceTest(unittest.TestCase):
    def test_shorter_filter_overwrites_stale_tail(self):
        for precision in (4, 8):
            for n in (256, 512, 1024):
                with self.subTest(precision=precision, n=n):
                    build = Build(precision, n)
                    io = CaptureTransport()
                    x = [[1] * build.r for _ in range(2)]
                    h = [[[3] * build.r for _ in range(2)] for _ in range(4)]
                    for nh in (build.r - 1, 1):
                        run_task(io, build, nh, x, h)
                        self.assertEqual(len(io.h_memory), 4 * 2 * build.r)
                        for (out, channel, index), value in io.h_memory.items():
                            self.assertEqual(value, 3 if index < nh else 0)


if __name__ == '__main__':
    unittest.main()
