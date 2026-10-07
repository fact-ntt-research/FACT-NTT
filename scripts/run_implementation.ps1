param(
  [ValidateSet(4,8)][int]$Precision = 8,
  [ValidateSet(256,512,1024)][int]$N = 256,
  [double]$PeriodNs = 0,
  [string]$VivadoBin = $env:VIVADO_BIN
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ($PeriodNs -eq 0) {
  if ($Precision -eq 4) {
    $PeriodNs = switch ($N) {
      256  { 3.500 }
      512  { 4.000 }
      1024 { 4.125 }
    }
  }
  else { $PeriodNs = if ($N -eq 1024) { 5.000 } else { 4.750 } }
}
$vivado = Resolve-FactTool -ExplicitPath $VivadoBin -Executable 'vivado.bat' -EnvironmentName 'VIVADO_BIN'
$tag = "int${Precision}_n${N}_p$($PeriodNs.ToString('0.000',[Globalization.CultureInfo]::InvariantCulture).Replace('.','_'))"
$work = Join-Path $root "build/vivado/$tag"
New-Item -ItemType Directory -Force -Path $work | Out-Null
Initialize-FactRomWorkspace -Root $root -WorkDir $work
$sourceList = Join-Path $work 'rtl_sources.txt'
$sourceManifest = Join-Path $work 'rtl_sources_sha256.csv'
$sources = @(Get-FactRtlSources -Root $root)
$sources | Set-Content -LiteralPath $sourceList -Encoding ascii
$sources | ForEach-Object {
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_).Hash.ToLowerInvariant()
  [pscustomobject]@{ path = $_.Substring($root.Length + 1).Replace('\','/'); sha256 = $hash }
} | Export-Csv -LiteralPath $sourceManifest -NoTypeInformation -Encoding ascii
$env:FACT_SOURCE_MANIFEST_SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceManifest).Hash.ToLowerInvariant()
$env:FACT_TCL_SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot 'implement.tcl')).Hash.ToLowerInvariant()
$env:FACT_DRIVER_SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()
$env:FACT_PRECISION = [string]$Precision
$env:FACT_N = [string]$N
$env:FACT_PERIOD_NS = $PeriodNs.ToString([Globalization.CultureInfo]::InvariantCulture)
$env:FACT_BUILD_TAG = $tag
$env:FACT_RTL_SOURCE_LIST = $sourceList
$env:FACT_RTL_SOURCE_MANIFEST = $sourceManifest
Push-Location $work
try {
  & $vivado -mode batch -source (Join-Path $PSScriptRoot 'implement.tcl') -notrace
  if ($LASTEXITCODE -ne 0) { throw "Vivado implementation failed with exit code $LASTEXITCODE" }
  Write-Host "FACT_IMPLEMENTATION_PASS precision=$Precision N=$N period_ns=$PeriodNs reports=$work"
} finally { Pop-Location }
