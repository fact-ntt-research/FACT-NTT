# FACT-NTT parameter audit

- Overall: PASS
- PASS checks: 181
- INFO checks: 1
- FAIL checks: 0

Scope: mathematical and ROM-content audit for p254/p520, plus public INT8 architecture wiring.
This does not run RTL simulation or Vivado implementation.

## Summary By Domain

| Domain | PASS | INFO | FAIL |
|---|---:|---:|---:|
| INT8_CRT | 3 | 0 | 0 |
| INT8_PUBLIC | 13 | 0 | 0 |
| p254 | 83 | 0 | 0 |
| p520 | 82 | 1 | 0 |

## Failed Checks

None.

## Notes

- p520 and p254 active arithmetic packages use pseudo-Mersenne folding with `PSEUDO_C=2^DATA_W-p`; `MREC_MU` is recorded as an informational reference.
- Twiddle and FACT psi ROM checks regenerate the packed lane-major words from the RTL package constants and compare them byte-for-byte against the committed `.mem` files.
- This is provenance evidence for parameter correctness. End-to-end convolution correctness still comes from xsim/Python golden checks.

## Artifacts

- CSV: `reports/verification/parameter_audit/checks.csv`
- Script: `scripts/audit_parameters.py`
