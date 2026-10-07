param(
  [ValidateSet(4,8)][int]$Precision = 8,
  [ValidateSet(256,512,1024)][int]$N = 256,
  [ValidateSet(1,2,4)][int]$Cin = 4,
  [int]$Nh = 0,
  [int]$Pattern = 6,
  [switch]$Full,
  [string]$VivadoBin = $env:VIVADO_BIN
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$nx = [int]($N / 2)
if ($Nh -eq 0) { $Nh = $nx - 1 }
if ($Nh -lt 1 -or $Nh -ge $nx) { throw "Nh must be in [1,$($nx-1)] for N=$N" }
$dataW = $Precision
$accW = 32

$xvlog = Resolve-FactTool -ExplicitPath $VivadoBin -Executable 'xvlog.bat' -EnvironmentName 'VIVADO_BIN'
$toolDir = Split-Path -Parent $xvlog
$xelab = Join-Path $toolDir 'xelab.bat'
$xsim = Join-Path $toolDir 'xsim.bat'
foreach ($tool in @($xelab,$xsim)) { if (-not (Test-Path -LiteralPath $tool)) { throw "Missing Vivado tool: $tool" } }

$work = Join-Path $root "build/baselines/direct/int${Precision}_n${N}_c${Cin}"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$sources = @(
  (Join-Path $root 'baselines/direct/rtl/ntt46_direct_spatial_conv_baseline.sv'),
  (Join-Path $root 'baselines/direct/rtl/ntt46_direct_spatial_serial_baseline.sv'),
  (Join-Path $root 'baselines/direct/rtl/ntt46_direct_spatial_parpipe_baseline.sv'),
  (Join-Path $root 'baselines/direct/tb/tb_ntt46_direct_spatial_conv_baseline.sv')
)

Push-Location $work
try {
  & $xvlog -sv @sources *> compile.log
  if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }
  $snapshot = "tb_direct_int${Precision}_n${N}_c${Cin}"
  $generics = @(
    "NX=$nx", 'PAR=4', "DATA_W=$dataW", "ACC_W=$accW",
    'DUT_PARPIPE=1', 'DUT_CIN_MAX=4',
    "DUT_SINGLE_CASE=$([int](-not $Full.IsPresent))",
    "DUT_SINGLE_PATTERN=$Pattern", "DUT_SINGLE_NH=$Nh", "DUT_SINGLE_CIN=$Cin"
  )
  $genericArgs = ($generics | ForEach-Object { '-generic_top "' + $_ + '"' }) -join ' '
  $command = '"' + $xelab + '" tb_ntt46_direct_spatial_conv_baseline ' +
             $genericArgs + ' -s ' + $snapshot
  & cmd.exe /d /s /c $command *> elab.log
  if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }
  & $xsim $snapshot -runall *> sim.log
  if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit code $LASTEXITCODE" }
  if (-not (Select-String -LiteralPath sim.log -Pattern 'tb_ntt46_direct_spatial_conv_baseline PASS' -Quiet)) {
    throw 'xsim completed without the final PASS marker'
  }
  Write-Host "DIRECT_BASELINE_PASS precision=$Precision N=$N Cin=$Cin Nh=$Nh log=$work/sim.log"
} finally { Pop-Location }
