param(
  [string]$VivadoBin = $env:VIVADO_BIN,
  [string]$Python = $env:PYTHON
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Python = Resolve-FactPython -ExplicitPath $Python
foreach ($precision in 4,8) {
  foreach ($channel in 0,1,2,3) {
    & (Join-Path $PSScriptRoot 'run_xsim.ps1') -Precision $precision -N 1024 `
      -Cin 1 -Cout 1 -Nh 511 -Pattern 6 -ChannelBase $channel -DumpCsv -VivadoBin $VivadoBin | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "single-channel run failed INT$precision channel=$channel" }
  }
  foreach ($cin in 1,2,4) {
    & (Join-Path $PSScriptRoot 'run_xsim.ps1') -Precision $precision -N 1024 `
      -Cin $cin -Cout 1 -Nh 511 -Pattern 6 -DumpCsv -VivadoBin $VivadoBin | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "fused run failed INT$precision Cin=$cin" }
  }
}
$out = Join-Path $root 'build/cin_fusion_ablation/results.csv'
& $Python (Join-Path $PSScriptRoot 'verify_cin_fusion_ablation.py') `
  (Join-Path $root 'build/xsim') --output $out
if ($LASTEXITCODE -ne 0) { throw 'Cin-first fusion ablation failed' }
Write-Host "CIN_FUSION_ABLATION_PASS evidence=$out"
