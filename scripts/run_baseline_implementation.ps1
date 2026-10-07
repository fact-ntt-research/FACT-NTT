param(
  [ValidateSet('direct','zero_pad')][string]$Baseline,
  [ValidateSet(4,8)][int]$Precision = 8,
  [ValidateSet(256,512,1024)][int]$N = 256,
  [double]$PeriodNs = 0,
  [string]$VivadoBin = $env:VIVADO_BIN
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ($PeriodNs -eq 0) {
  $PeriodNs = if ($Baseline -eq 'direct') { if ($Precision -eq 4) { 4.000 } else { 5.500 } } else { 5.000 }
}
$vivado = Resolve-FactTool -ExplicitPath $VivadoBin -Executable 'vivado.bat' -EnvironmentName 'VIVADO_BIN'
$periodTag = $PeriodNs.ToString('0.000',[Globalization.CultureInfo]::InvariantCulture).Replace('.','_')
$tag = "${Baseline}_int${Precision}_n${N}_p$periodTag"
$work = Join-Path $root "build/baselines/implementation/$tag"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$sourceFiles = if ($Baseline -eq 'direct') {
  @('baselines/direct/rtl/ntt46_direct_spatial_parpipe_baseline.sv',
    'baselines/direct/rtl/direct_spatial_parpipe_baseline_top.sv')
} else {
  @('baselines/zero_pad/rtl/ntt46_zero_pad_radix2_reference_engine.sv',
    'baselines/zero_pad/rtl/ntt46_zero_pad_radix2_residue_conv_core.sv',
    'baselines/zero_pad/rtl/ntt46_zero_pad_radix2_unified_baseline.sv')
}
$sourceManifest = Join-Path $work 'rtl_sources_sha256.csv'
$sourceFiles | ForEach-Object {
  $path = Join-Path $root $_
  [pscustomobject]@{path=$_.Replace('\','/');sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()}
} | Export-Csv -NoTypeInformation -Encoding ascii -LiteralPath $sourceManifest
$env:BASELINE_KIND = $Baseline
$env:BASELINE_PRECISION = [string]$Precision
$env:BASELINE_N = [string]$N
$env:BASELINE_PERIOD_NS = $PeriodNs.ToString([Globalization.CultureInfo]::InvariantCulture)
$env:BASELINE_BUILD_TAG = $tag
$env:BASELINE_OUT_DIR = $work
$env:BASELINE_SOURCE_MANIFEST_SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceManifest).Hash.ToLowerInvariant()
$env:BASELINE_TCL_SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot 'implement_baseline.tcl')).Hash.ToLowerInvariant()
$env:BASELINE_DRIVER_SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()
Push-Location $work
try {
  & $vivado -mode batch -source (Join-Path $PSScriptRoot 'implement_baseline.tcl') -notrace
  if ($LASTEXITCODE -ne 0) { throw "Vivado implementation failed with exit code $LASTEXITCODE" }
  Write-Host "BASELINE_IMPLEMENTATION_PASS kind=$Baseline precision=$Precision N=$N period_ns=$PeriodNs reports=$work"
} finally { Pop-Location }
