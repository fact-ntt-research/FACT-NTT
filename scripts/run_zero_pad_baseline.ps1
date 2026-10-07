param(
  [switch]$Full,
  [string]$VivadoBin = $env:VIVADO_BIN,
  [string]$Python = $env:PYTHON
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$xvlog = Resolve-FactTool -ExplicitPath $VivadoBin -Executable 'xvlog.bat' -EnvironmentName 'VIVADO_BIN'
$toolDir = Split-Path -Parent $xvlog
$xelab = Join-Path $toolDir 'xelab.bat'
$xsim = Join-Path $toolDir 'xsim.bat'
foreach ($tool in @($xelab,$xsim)) { if (-not (Test-Path -LiteralPath $tool)) { throw "Missing Vivado tool: $tool" } }
$Python = Resolve-FactPython -ExplicitPath $Python

$mode = if ($Full) { 'full' } else { 'key' }
$work = Join-Path $root "build/baselines/zero_pad/$mode"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$sources = @(
  (Join-Path $root 'baselines/zero_pad/rtl/ntt46_zero_pad_radix2_reference_engine.sv'),
  (Join-Path $root 'baselines/zero_pad/rtl/ntt46_zero_pad_radix2_residue_conv_core.sv'),
  (Join-Path $root 'baselines/zero_pad/rtl/ntt46_zero_pad_radix2_unified_baseline.sv'),
  (Join-Path $root 'baselines/zero_pad/tb/tb_ntt46_zero_pad_radix2_unified_baseline.sv')
)

Push-Location $work
try {
  & $xvlog -sv @sources *> compile.log
  if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }
  $jobs = foreach ($n in 256,512,1024) {
    foreach ($precision in 4,8) {
      if ($Full) {
        foreach ($cin in 1,2,4) { foreach ($cout in 1,2,4) { [pscustomobject]@{N=$n;Precision=$precision;Cin=$cin;Cout=$cout} } }
      } else {
        [pscustomobject]@{N=$n;Precision=$precision;Cin=1;Cout=1}
        [pscustomobject]@{N=$n;Precision=$precision;Cin=4;Cout=4}
      }
    }
  }
  $rows = foreach ($job in $jobs) {
    $tag = "n$($job.N)_int$($job.Precision)_c$($job.Cin)o$($job.Cout)"
    $snapshot = "tb_zero_$tag"
    $generics = @("DUT_N=$($job.N)","DUT_PRECISION=$($job.Precision)","DUT_CIN=$($job.Cin)","DUT_COUT=$($job.Cout)")
    $genericArgs = ($generics | ForEach-Object { '-generic_top "' + $_ + '"' }) -join ' '
    $command = '"' + $xelab + '" tb_ntt46_zero_pad_radix2_unified_baseline ' +
               $genericArgs + ' -s ' + $snapshot
    & cmd.exe /d /s /c $command *> "elab_$tag.log"
    if ($LASTEXITCODE -ne 0) { throw "xelab failed for $tag" }
    & $xsim $snapshot -runall *> "sim_$tag.log"
    if ($LASTEXITCODE -ne 0) { throw "xsim failed for $tag" }
    $match = Select-String -LiteralPath "sim_$tag.log" -Pattern 'PASS .*cycles=([0-9]+)' | Select-Object -Last 1
    if ($null -eq $match) { throw "PASS marker missing for $tag" }
    [pscustomobject]@{N=$job.N;Precision=$job.Precision;Cin=$job.Cin;Cout=$job.Cout;Status='PASS';Cycles=[int64]$match.Matches[0].Groups[1].Value;Log="sim_$tag.log"}
  }
  $rows | Export-Csv -NoTypeInformation -Encoding ascii -LiteralPath results.csv
  & $Python (Join-Path $root 'baselines/zero_pad/verify_zero_pad_vector_dumps.py') $work *> python_direct_check.log
  if ($LASTEXITCODE -ne 0) { throw 'Independent Python direct-convolution check failed' }
  Write-Host "ZERO_PAD_BASELINE_PASS mode=$mode rows=$($rows.Count) evidence=$work/results.csv"
} finally { Pop-Location }
