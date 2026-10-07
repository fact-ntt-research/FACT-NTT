param(
  [switch]$Full,
  [string]$VivadoBin = $env:VIVADO_BIN,
  [string]$Python = $env:PYTHON
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Python = Resolve-FactPython -ExplicitPath $Python

$jobs = if ($Full) {
  foreach ($precision in 4,8) { foreach ($n in 256,512,1024) { [pscustomobject]@{Precision=$precision;N=$n} } }
} else {
  @([pscustomobject]@{Precision=4;N=256},[pscustomobject]@{Precision=8;N=256})
}

$rows = foreach ($job in $jobs) {
  & (Join-Path $PSScriptRoot 'run_xsim.ps1') -Precision $job.Precision -N $job.N -Cin 4 -Cout 4 -DumpCsv -VivadoBin $VivadoBin | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "RTL run failed for INT$($job.Precision) N=$($job.N)" }
  $work = Join-Path $root "build/xsim/p$($job.Precision)_n$($job.N)_c4o4_b0"
  $csv = Join-Path $work 'fact_output.csv'
  $report = Join-Path $work 'python_crosscheck.md'
  & $Python (Join-Path $PSScriptRoot 'check_fact_output.py') --csv $csv --report $report | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "Python crosscheck failed for INT$($job.Precision) N=$($job.N)" }
  [pscustomobject]@{Precision=$job.Precision;N=$job.N;Cin=4;Cout=4;Result='PASS';Report=$report}
}
$out = Join-Path $root 'build/python_crosscheck_matrix.csv'
$rows | Export-Csv -NoTypeInformation -Encoding utf8 -LiteralPath $out
Write-Host "FACT_PYTHON_CROSSCHECK_PASS rows=$($rows.Count) report=$out"
