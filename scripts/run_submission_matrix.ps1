param(
  [string]$OutDir = '',
  [string]$VivadoBin = $env:VIVADO_BIN,
  [string]$PythonExe = $env:PYTHON,
  [int[]]$Precisions = @(4, 8),
  [int[]]$Ns = @(256, 512, 1024),
  [switch]$Quick,
  [switch]$Resume
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PythonExe = Resolve-FactPython -ExplicitPath $PythonExe
if (-not $OutDir) { $OutDir = Join-Path $root 'build/submission_matrix' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path

$verificationFiles = @(Get-FactRtlSources -Root $root)
$verificationFiles += Join-Path $root 'tb/tb_ntt46_fact_lean_ip_unified_axi_lite_core.sv'
$verificationFiles += Join-Path $root 'scripts/check_fact_output.py'
$verificationRecords = foreach ($path in ($verificationFiles | Sort-Object)) {
  $resolvedPath = (Resolve-Path -LiteralPath $path).Path
  if (-not $resolvedPath.StartsWith($root + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Verification input is outside the public root: $resolvedPath"
  }
  [pscustomobject]@{
    Path = $resolvedPath.Substring($root.Length + 1).Replace('\','/')
    SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedPath).Hash.ToLowerInvariant()
  }
}
$verificationPayload = ($verificationRecords | ForEach-Object { "$($_.Path)|$($_.SHA256)" }) -join "`n"
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
  $verificationDigest = -join ($sha256.ComputeHash(
    [System.Text.Encoding]::UTF8.GetBytes($verificationPayload)) |
    ForEach-Object { $_.ToString('x2') })
} finally {
  $sha256.Dispose()
}
$verificationRecords | Export-Csv -NoTypeInformation -LiteralPath (
  Join-Path $OutDir 'verification_inputs_sha256.csv')
Set-Content -Encoding ascii -LiteralPath (Join-Path $OutDir 'verification_digest.txt') `
  -Value $verificationDigest

$xvlog = Resolve-FactTool -ExplicitPath $VivadoBin -Executable 'xvlog.bat' -EnvironmentName 'VIVADO_BIN'
$toolDir = Split-Path -Parent $xvlog
$xelab = Join-Path $toolDir 'xelab.bat'
$xsim = Join-Path $toolDir 'xsim.bat'
$checker = Join-Path $root 'scripts/check_fact_output.py'
$allRows = [System.Collections.Generic.List[object]]::new()
$resultsPath = Join-Path $OutDir 'results.csv'
if ($Resume -and (Test-Path -LiteralPath $resultsPath)) {
  foreach ($row in @(Import-Csv -LiteralPath $resultsPath)) { $allRows.Add($row) }
}

foreach ($precision in $Precisions) {
  foreach ($n in $Ns) {
    $r = [int]($n / 2)
    $lanes = if ($n -eq 1024) { 16 } else { 8 }
    $bound = if ($precision -eq 4) { 8 } else { 128 }
    $work = Join-Path $OutDir "p${precision}_n${n}"
    $logs = Join-Path $work 'logs'
    $dumps = Join-Path $work 'dumps'
    $pythonLogs = Join-Path $work 'python'
    New-Item -ItemType Directory -Force -Path $logs,$dumps,$pythonLogs | Out-Null
    Initialize-FactRomWorkspace -Root $root -WorkDir $work
    $sources = @(Get-FactRtlSources -Root $root)
    $sources += Join-Path $root 'tb/tb_ntt46_fact_lean_ip_unified_axi_lite_core.sv'
    $fileList = Join-Path $work 'xvlog_sources.f'
    $sources | ForEach-Object { '"' + ($_.Replace('\','/')) + '"' } |
      Set-Content -Encoding ascii -LiteralPath $fileList

    Push-Location $work
    try {
      & $xvlog -sv -f $fileList *> (Join-Path $logs 'compile.log')
      if ($LASTEXITCODE -ne 0) { throw "xvlog failed INT$precision N=$n" }

      $cases = [System.Collections.Generic.List[object]]::new()
      if ($Quick) {
        $cases.Add([pscustomobject]@{Nh=($r-1); Cin=1; Cout=1; Pattern=6; Kind='quick'})
      } else {
        foreach ($nh in @(1, [int]($r / 2), ($r - 1))) {
          foreach ($cin in @(1, 2, 4)) {
            foreach ($cout in @(1, 2, 4)) {
              $cases.Add([pscustomobject]@{Nh=$nh; Cin=$cin; Cout=$cout; Pattern=6; Kind='matrix'})
            }
          }
        }
        foreach ($pattern in @(1, 2, 3, 5)) {
          $cases.Add([pscustomobject]@{Nh=($r-1); Cin=4; Cout=4; Pattern=$pattern; Kind='stress'})
        }
      }

      foreach ($case in $cases) {
        $tag = "p${precision}_n${n}_nh$($case.Nh)_c$($case.Cin)o$($case.Cout)_pat$($case.Pattern)"
        $snapshot = "sim_$tag"
        $existing = @($allRows | Where-Object {
          [int]$_.Precision -eq $precision -and [int]$_.N -eq $n -and
          [int]$_.Nh -eq $case.Nh -and [int]$_.Cin -eq $case.Cin -and
          [int]$_.Cout -eq $case.Cout -and [int]$_.Pattern -eq $case.Pattern
        } | Select-Object -First 1)
        if ($Resume -and $existing.Count -eq 1 -and
            $existing[0].VerificationDigest -eq $verificationDigest -and
            (Test-Path -LiteralPath $existing[0].SimLog) -and
            (Test-Path -LiteralPath $existing[0].Dump) -and
            (Test-Path -LiteralPath $existing[0].PythonLog) -and
            (Select-String -LiteralPath $existing[0].SimLog -Pattern 'tb_ntt46_fact_lean_ip_unified_axi_lite_core PASS' -Quiet) -and
            (Select-String -LiteralPath $existing[0].PythonLog -Pattern 'mismatches=0' -Quiet)) {
          Write-Host "RESUME_PASS $tag"
          continue
        }
        if ($existing.Count -eq 1) { $allRows.Remove($existing[0]) | Out-Null }
        $generics = @(
          "DUT_PRECISION=$precision", "DUT_R=$r", "DUT_LANES=$lanes",
          "DUT_CIN=$($case.Cin)", "DUT_COUT=$($case.Cout)", 'DUT_COUT_MAX=4',
          "DUT_NH=$($case.Nh)", "DUT_PATTERN=$($case.Pattern)", "DUT_BOUND=$bound",
          'DUT_CHANNEL_BASE=0', 'DUT_TEST_ILLEGAL=0', 'DUT_TEST_REPEAT_START=0',
          'DUT_TEST_BACK_TO_BACK=0', 'DUT_TEST_RESET_MID_TASK=0',
          'DUT_DUMP_CSV=1', 'DUT_TIMEOUT_CYCLES=1200000'
        )
        $genericArgs = ($generics | ForEach-Object { '-generic_top "' + $_ + '"' }) -join ' '
        $command = '"' + $xelab + '" tb_ntt46_fact_lean_ip_unified_axi_lite_core ' +
                   $genericArgs + ' -s ' + $snapshot
        & cmd.exe /d /s /c $command *> (Join-Path $logs "elab_$tag.log")
        if ($LASTEXITCODE -ne 0) { throw "xelab failed $tag" }
        & $xsim $snapshot -runall *> (Join-Path $logs "sim_$tag.log")
        if ($LASTEXITCODE -ne 0) { throw "xsim failed $tag" }
        $pass = Select-String -Path (Join-Path $logs "sim_$tag.log") `
          -Pattern 'PASS .*wall_cycles=([0-9]+) core_compute_cycles=([0-9]+)' |
          Select-Object -Last 1
        if (-not $pass) { throw "PASS marker missing $tag" }

        $dump = Join-Path $dumps "$tag.csv"
        Move-Item -Force -LiteralPath (Join-Path $work 'fact_output.csv') -Destination $dump
        $pythonLog = Join-Path $pythonLogs "$tag.log"
        & $PythonExe $checker --csv $dump *> $pythonLog
        if ($LASTEXITCODE -ne 0) { throw "Python direct check failed $tag" }

        $allRows.Add([pscustomobject]@{
          Precision=$precision; N=$n; Nh=$case.Nh; Cin=$case.Cin; Cout=$case.Cout
          Pattern=$case.Pattern; Kind=$case.Kind; Status='PASS'
          VerificationDigest=$verificationDigest
          WallCycles=[int64]$pass.Matches[0].Groups[1].Value
          CoreCycles=[int64]$pass.Matches[0].Groups[2].Value
          ComparedOutputs=$n*$case.Cout; Mismatches=0
          SimLog=(Join-Path $logs "sim_$tag.log"); Dump=$dump; PythonLog=$pythonLog
        })
        $allRows | Export-Csv -NoTypeInformation -Path $resultsPath
        Write-Host "PASS $tag core=$($pass.Matches[0].Groups[2].Value)"
      }
    } finally {
      Pop-Location
    }
  }
}

$allRows | Export-Csv -NoTypeInformation -Path $resultsPath
Write-Host "FACT_SUBMISSION_MATRIX_PASS cases=$($allRows.Count) results=$resultsPath"
