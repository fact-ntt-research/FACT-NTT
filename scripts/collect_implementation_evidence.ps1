param(
  [string]$MatrixCsv = "build/implementation_matrix/implementation_matrix_latest.csv",
  [string]$OutputCsv = "reports/implementation.csv"
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$matrixPath = Join-Path $root $MatrixCsv
$outputPath = Join-Path $root $OutputCsv

function Contract-ToMap([string]$Path) {
  $map = @{}
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^([^=]+)=(.*)$') { $map[$matches[1]] = $matches[2] }
  }
  return $map
}

function Match-Value([string]$Path, [string]$Pattern, [int]$Group = 1) {
  $match = [regex]::Match((Get-Content -Raw -LiteralPath $Path), $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)
  if (-not $match.Success) { throw "Pattern not found in $Path : $Pattern" }
  return $match.Groups[$Group].Value.Trim()
}

$rows = foreach ($job in Import-Csv -LiteralPath $matrixPath) {
  $contractPath = Join-Path $root $job.contract
  if (-not (Test-Path -LiteralPath $contractPath)) { throw "Missing contract: $contractPath" }
  $contract = Contract-ToMap $contractPath
  $dir = Split-Path -Parent $contractPath
  $tag = [IO.Path]::GetFileName($contractPath) -replace '_build_contract\.txt$',''
  $utilSuffix = if ($job.kind -eq 'fact') { '_util.rpt' } else { '_utilization.rpt' }
  $utilPath = Join-Path $dir ($tag + $utilSuffix)
  $timingPath = Join-Path $dir ($tag + '_timing.rpt')
  $routePath = Join-Path $dir ($tag + '_route_status.rpt')
  $drcPath = Join-Path $dir ($tag + '_drc.rpt')
  $powerPath = Join-Path $dir ($tag + '_power_vectorless.rpt')
  foreach ($path in $utilPath,$timingPath,$routePath,$drcPath,$powerPath) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing evidence report: $path" }
  }
  $routeErrors = Match-Value $routePath '# of nets with routing errors\.\.\.*\s*:\s*(\d+)\s*:'
  $luts = Match-Value $utilPath '^\| CLB LUTs\s*\|\s*([0-9.]+)\s*\|'
  $ffs = Match-Value $utilPath '^\| CLB Registers\s*\|\s*([0-9.]+)\s*\|'
  $bram = Match-Value $utilPath '^\| Block RAM Tile\s*\|\s*([0-9.]+)\s*\|'
  $dsp = Match-Value $utilPath '^\| DSPs\s*\|\s*([0-9.]+)\s*\|'
  $power = Match-Value $powerPath '^\| Total On-Chip Power \(W\)\s*\|\s*([0-9.]+)\s*\|'
  $confidence = Match-Value $powerPath '^\| Confidence Level\s*\|\s*([^|]+)\|'
  $drcText = Get-Content -Raw -LiteralPath $drcPath
  $criticalRules = [regex]::Matches($drcText, '^\|\s*([^|]+?)\s*\|\s*Critical Warning\s*\|', 'Multiline') |
    ForEach-Object { $_.Groups[1].Value.Trim() } | Sort-Object -Unique
  $unconstrainedInternal = if ((Get-Content -Raw -LiteralPath $timingPath) -match 'There are 0 pins that are not constrained for maximum delay\.') { 0 } else { 'CHECK' }
  [pscustomobject]@{
    name=$job.name; kind=$job.kind; precision=$job.precision; N=$job.N
    period_ns=$job.period_ns; fmax_target_mhz=[math]::Round(1000.0/[double]$job.period_ns,3)
    route_status=$contract.route_status; route_errors=$routeErrors; wns_ns=$contract.wns_ns; whs_ns=$contract.whs_ns
    clb_luts=$luts; clb_registers=$ffs; dsp=$dsp; bram_tiles=$bram
    vectorless_power_w=$power; power_confidence=$confidence
    unconstrained_internal_max_endpoints=$unconstrainedInternal
    critical_drc_rules=($criticalRules -join ';')
    source_manifest_sha256=$contract.rtl_source_manifest_sha256
    contract=$job.contract
    timing_report=$timingPath.Substring($root.Length+1).Replace('\','/')
    utilization_report=$utilPath.Substring($root.Length+1).Replace('\','/')
    route_report=$routePath.Substring($root.Length+1).Replace('\','/')
    drc_report=$drcPath.Substring($root.Length+1).Replace('\','/')
    power_report=$powerPath.Substring($root.Length+1).Replace('\','/')
  }
}

$outputDir = Split-Path -Parent $outputPath
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$rows | Export-Csv -NoTypeInformation -Encoding ascii -LiteralPath $outputPath
if (($rows | Where-Object { $_.route_errors -ne '0' -or [double]$_.wns_ns -lt 0 -or [double]$_.whs_ns -lt 0 }).Count) {
  throw 'Implementation evidence contains a route or timing failure.'
}
Write-Host "IMPLEMENTATION_EVIDENCE_PASS rows=$($rows.Count) output=$outputPath"
