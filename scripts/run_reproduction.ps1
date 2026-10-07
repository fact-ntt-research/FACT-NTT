param(
  [switch]$Full,
  [switch]$RunImplementation,
  [string]$VivadoBin = $env:VIVADO_BIN,
  [string]$PythonExe = $env:PYTHON
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$python = Resolve-FactPython -ExplicitPath $PythonExe

$manifest = Join-Path $root 'MANIFEST_SHA256.csv'
if (Test-Path -LiteralPath $manifest) {
  & (Join-Path $PSScriptRoot 'verify_manifest.ps1') -Manifest $manifest
}

& $python (Join-Path $PSScriptRoot 'check_paper_alignment.py')
if ($LASTEXITCODE -ne 0) { throw 'Paper and archived evidence alignment failed' }
& $python (Join-Path $root 'examples/test_host_sequence.py')
if ($LASTEXITCODE -ne 0) { throw 'Host preload contract test failed' }
& $python (Join-Path $PSScriptRoot 'audit_parameters.py') `
  --root $root --tag reproduction
if ($LASTEXITCODE -ne 0) { throw 'Parameter and ROM audit failed' }

if ($Full) {
  & (Join-Path $PSScriptRoot 'run_submission_matrix.ps1') `
    -VivadoBin $VivadoBin -PythonExe $python
  foreach ($precision in 4,8) {
    foreach ($n in 256,512,1024) {
      & (Join-Path $PSScriptRoot 'run_xsim.ps1') -Precision $precision -N $n `
        -ProtocolChecks -BackToBack -ResetMidTask -VivadoBin $VivadoBin
      & (Join-Path $PSScriptRoot 'run_direct_baseline.ps1') -Precision $precision `
        -N $n -Cin 4 -VivadoBin $VivadoBin
    }
  }
  & (Join-Path $PSScriptRoot 'run_zero_pad_baseline.ps1') -Full `
    -VivadoBin $VivadoBin -Python $python
  & (Join-Path $PSScriptRoot 'run_cin_fusion_ablation.ps1') `
    -VivadoBin $VivadoBin -Python $python
  & (Join-Path $PSScriptRoot 'run_fir_workload.ps1') `
    -VivadoBin $VivadoBin -Python $python
  foreach ($cin in 1,2,4) {
    foreach ($case in @(@(1,4), @(256,0), @(511,6))) {
      & (Join-Path $PSScriptRoot 'run_parallel_zero_pad.ps1') `
        -Cin $cin -Nh $case[0] -Pattern $case[1] -VivadoBin $VivadoBin
    }
  }
} else {
  & (Join-Path $PSScriptRoot 'run_python_crosscheck.ps1') `
    -VivadoBin $VivadoBin -Python $python
  foreach ($precision in 4,8) {
    & (Join-Path $PSScriptRoot 'run_xsim.ps1') -Precision $precision -N 256 `
      -ProtocolChecks -BackToBack -ResetMidTask -VivadoBin $VivadoBin
    & (Join-Path $PSScriptRoot 'run_direct_baseline.ps1') -Precision $precision `
      -N 256 -Cin 4 -VivadoBin $VivadoBin
  }
  & (Join-Path $PSScriptRoot 'run_zero_pad_baseline.ps1') `
    -VivadoBin $VivadoBin -Python $python
}

if ($RunImplementation) {
  foreach ($precision in 4,8) {
    foreach ($n in 256,512,1024) {
      & (Join-Path $PSScriptRoot 'run_implementation.ps1') `
        -Precision $precision -N $n -VivadoBin $VivadoBin
    }
  }
}

Write-Host "FACT_REPRODUCTION_PASS full=$($Full.IsPresent) implementation=$($RunImplementation.IsPresent) root=$root"
