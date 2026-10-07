param(
  [switch]$Resume,
  [switch]$ContinueOnFailure,
  [switch]$ListOnly,
  [string]$VivadoBin = $env:VIVADO_BIN
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$matrixDir = Join-Path $root 'build/implementation_matrix'
$logDir = Join-Path $matrixDir 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Read-BuildContract([string]$Path) {
  $values = @{}
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^([^=]+)=(.*)$') { $values[$matches[1]] = $matches[2] }
  }
  return $values
}

function Test-SourceManifest([string]$ManifestPath, [string]$ExpectedDigest) {
  if (-not (Test-Path -LiteralPath $ManifestPath)) { return $false }
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $ManifestPath).Hash.ToLowerInvariant() -ne $ExpectedDigest) { return $false }
  foreach ($row in Import-Csv -LiteralPath $ManifestPath) {
    $source = Join-Path $root ($row.path.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $source)) { return $false }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant() -ne $row.sha256) { return $false }
  }
  return $true
}

function Test-CompletedBuild([pscustomobject]$Job) {
  if (-not $Resume -or -not (Test-Path -LiteralPath $Job.Contract)) { return $false }
  $contract = Read-BuildContract $Job.Contract
  foreach ($key in 'route_status','wns_ns','whs_ns','rtl_source_manifest_sha256') {
    if (-not $contract.ContainsKey($key)) { return $false }
  }
  if ($contract.route_status -notin @('ROUTED','ROUTED_WITH_WARNINGS')) { return $false }
  if ([double]::Parse($contract.wns_ns,[Globalization.CultureInfo]::InvariantCulture) -lt 0) { return $false }
  if ([double]::Parse($contract.whs_ns,[Globalization.CultureInfo]::InvariantCulture) -lt 0) { return $false }
  if (-not (Test-SourceManifest $Job.Manifest $contract.rtl_source_manifest_sha256)) { return $false }
  $driverKey = if ($Job.Kind -eq 'fact') { 'run_implementation_ps1_sha256' } else { 'run_baseline_implementation_ps1_sha256' }
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Job.Tcl).Hash.ToLowerInvariant() -ne $contract.implement_tcl_sha256) { return $false }
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Job.Driver).Hash.ToLowerInvariant() -ne $contract[$driverKey]) { return $false }
  return $true
}

$jobs = [System.Collections.Generic.List[object]]::new()
foreach ($precision in 4,8) {
  foreach ($n in 256,512,1024) {
    $period = if ($precision -eq 4) { @{256=3.500;512=4.000;1024=4.125}[$n] } elseif ($n -eq 1024) { 5.000 } else { 4.750 }
    $periodTag = $period.ToString('0.000',[Globalization.CultureInfo]::InvariantCulture).Replace('.','_')
    $tag = "int${precision}_n${n}_p${periodTag}"
    $out = Join-Path $root "build/vivado/$tag"
    $jobs.Add([pscustomobject]@{
      Name="fact_$tag"; Kind='fact'; Precision=$precision; N=$n; Period=$period
      Contract=(Join-Path $out "${tag}_build_contract.txt"); Manifest=(Join-Path $out 'rtl_sources_sha256.csv')
      Driver=(Join-Path $PSScriptRoot 'run_implementation.ps1'); Tcl=(Join-Path $PSScriptRoot 'implement.tcl')
    })
  }
}
foreach ($baseline in 'direct','zero_pad') {
  foreach ($precision in 4,8) {
    foreach ($n in 256,512,1024) {
      $period = if ($baseline -eq 'direct') { if ($precision -eq 4) { 4.000 } else { 5.500 } } else { 5.000 }
      $periodTag = $period.ToString('0.000',[Globalization.CultureInfo]::InvariantCulture).Replace('.','_')
      $tag = "${baseline}_int${precision}_n${n}_p${periodTag}"
      $out = Join-Path $root "build/baselines/implementation/$tag"
      $jobs.Add([pscustomobject]@{
        Name=$tag; Kind=$baseline; Precision=$precision; N=$n; Period=$period
        Contract=(Join-Path $out "${tag}_build_contract.txt"); Manifest=(Join-Path $out 'rtl_sources_sha256.csv')
        Driver=(Join-Path $PSScriptRoot 'run_baseline_implementation.ps1'); Tcl=(Join-Path $PSScriptRoot 'implement_baseline.tcl')
      })
    }
  }
}

if ($ListOnly) {
  $jobs | Select-Object Name,Kind,Precision,N,Period
  exit 0
}
$vivado = Resolve-FactTool -ExplicitPath $VivadoBin -Executable 'vivado.bat' -EnvironmentName 'VIVADO_BIN'
$results = [System.Collections.Generic.List[object]]::new()
$failed = $false
foreach ($job in $jobs) {
  $started = Get-Date
  $status = 'PASS'
  if (Test-CompletedBuild $job) {
    $status = 'RESUMED'
    Write-Host "IMPLEMENTATION_MATRIX_RESUME $($job.Name)"
  } else {
    $log = Join-Path $logDir "$($job.Name).log"
    Write-Host "IMPLEMENTATION_MATRIX_START $($job.Name)"
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$job.Driver)
    if ($job.Kind -ne 'fact') { $arguments += @('-Baseline',$job.Kind) }
    $arguments += @('-Precision',[string]$job.Precision,'-N',[string]$job.N,'-PeriodNs',$job.Period.ToString([Globalization.CultureInfo]::InvariantCulture),'-VivadoBin',$vivado)
    $childExitCode = 0
    try {
      & powershell.exe @arguments *> $log
      $childExitCode = $LASTEXITCODE
    } catch {
      $childExitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 1 }
      $_ | Out-String | Add-Content -LiteralPath $log
    }
    if ($childExitCode -ne 0 -or -not (Test-Path -LiteralPath $job.Contract)) {
      $status = 'FAIL'
      $failed = $true
    } else {
      $contract = Read-BuildContract $job.Contract
      if ($contract.route_status -notin @('ROUTED','ROUTED_WITH_WARNINGS') -or [double]$contract.wns_ns -lt 0 -or [double]$contract.whs_ns -lt 0) {
        $status = 'FAIL'
        $failed = $true
      }
    }
    Write-Host "IMPLEMENTATION_MATRIX_DONE $($job.Name) status=$status log=$log"
  }
  $contract = if (Test-Path -LiteralPath $job.Contract) { Read-BuildContract $job.Contract } else { @{} }
  $results.Add([pscustomobject]@{
    name=$job.Name; kind=$job.Kind; precision=$job.Precision; N=$job.N; period_ns=$job.Period
    status=$status; route_status=$contract.route_status; wns_ns=$contract.wns_ns; whs_ns=$contract.whs_ns
    elapsed_minutes=[math]::Round(((Get-Date)-$started).TotalMinutes,2)
    contract=$job.Contract.Substring($root.Length+1).Replace('\','/')
  })
  $results | Export-Csv -NoTypeInformation -Encoding ascii -LiteralPath (Join-Path $matrixDir 'implementation_matrix_latest.csv')
  if ($status -eq 'FAIL' -and -not $ContinueOnFailure) { throw "Implementation matrix stopped at $($job.Name); inspect its log." }
}
if ($failed) { throw 'One or more implementation matrix jobs failed.' }
Write-Host "IMPLEMENTATION_MATRIX_PASS jobs=$($jobs.Count) summary=$(Join-Path $matrixDir 'implementation_matrix_latest.csv')"
