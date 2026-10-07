param(
  [string]$VivadoBin = $env:VIVADO_BIN,
  [string]$Python = $env:PYTHON
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Python = Resolve-FactPython -ExplicitPath $Python
& (Join-Path $PSScriptRoot 'run_xsim.ps1') -Precision 8 -N 1024 -Cin 4 -Cout 4 `
  -Nh 31 -Pattern 7 -DumpCsv -VivadoBin $VivadoBin | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'INT8 FIR RTL run failed' }
$work = Join-Path $root 'build/xsim/p8_n1024_c4o4_b0'
$dump = Join-Path $work 'fact_output.csv'
& $Python (Join-Path $PSScriptRoot 'verify_multichannel_fir_workload.py') $dump |
  Tee-Object -FilePath (Join-Path $work 'fir_python_check.log')
if ($LASTEXITCODE -ne 0) { throw 'Independent FIR workload check failed' }
Write-Host "FIR_WORKLOAD_PASS dump=$dump"
