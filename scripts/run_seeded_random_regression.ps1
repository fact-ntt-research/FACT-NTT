param(
  [string]$OutDir = '',
  [string]$VivadoBin = $env:VIVADO_BIN,
  [string]$PythonExe = $env:PYTHON,
  [int[]]$Seeds = @(101, 1009)
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PythonExe = Resolve-FactPython -ExplicitPath $PythonExe
if (-not $OutDir) { $OutDir = Join-Path $root 'build/seeded_random' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$rows = [System.Collections.Generic.List[object]]::new()
$legal = @(1, 2, 4)

foreach ($precision in @(4, 8)) {
  foreach ($n in @(256, 512, 1024)) {
    $r = [int]($n / 2)
    foreach ($seed in $Seeds) {
      $mix64 = ([uint64]$seed * [uint64]2654435761) +
               ([uint64]$precision * [uint64]2246822519) + [uint64]$n
      $mix = [uint32]($mix64 % [uint64]4294967296)
      $cin = $legal[$mix % 3]
      $cout = $legal[($mix -shr 5) % 3]
      $nh = 1 + [int](($mix -shr 9) % ($r - 1))
      $tag = "p${precision}_n${n}_seed${seed}_nh${nh}_c${cin}o${cout}"
      $simLog = Join-Path $OutDir "${tag}_xsim.log"
      $pythonLog = Join-Path $OutDir "${tag}_python.log"
      & (Join-Path $PSScriptRoot 'run_xsim.ps1') -Precision $precision -N $n `
        -Cin $cin -Cout $cout -Nh $nh -Pattern $seed -DumpCsv `
        -VivadoBin $VivadoBin *> $simLog
      if ($LASTEXITCODE -ne 0) { throw "xsim failed: $tag" }
      $sourceDump = Join-Path $root "build/xsim/p${precision}_n${n}_c${cin}o${cout}_b0/fact_output.csv"
      $dump = Join-Path $OutDir "${tag}.csv"
      Copy-Item -Force -LiteralPath $sourceDump -Destination $dump
      & $PythonExe (Join-Path $PSScriptRoot 'check_fact_output.py') --csv $dump *> $pythonLog
      if ($LASTEXITCODE -ne 0) { throw "Python direct check failed: $tag" }
      if (-not (Select-String -LiteralPath $pythonLog -Pattern 'mismatches=0' -Quiet)) {
        throw "Zero-mismatch marker missing: $tag"
      }
      $rows.Add([pscustomobject]@{
        Precision=$precision; N=$n; Seed=$seed; Nh=$nh; Cin=$cin; Cout=$cout
        Status='PASS'; ComparedOutputs=$n*$cout; Mismatches=0
        SimLog=$simLog; Dump=$dump; PythonLog=$pythonLog
      })
      $rows | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $OutDir 'results.csv')
      Write-Host "PASS $tag"
    }
  }
}

Write-Host "FACT_SEEDED_RANDOM_PASS cases=$($rows.Count) results=$(Join-Path $OutDir 'results.csv')"
