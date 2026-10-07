param(
  [ValidateSet(4,8)][int]$Precision = 8,
  [ValidateSet(256,512,1024)][int]$N = 256,
  [ValidateSet(1,2,4)][int]$Cin = 1,
  [ValidateSet(1,2,4)][int]$Cout = 1,
  [int]$Nh = 0,
  [int]$Pattern = 6,
  [ValidateRange(0,3)][int]$ChannelBase = 0,
  [switch]$ProtocolChecks,
  [switch]$BackToBack,
  [switch]$Repreload,
  [switch]$ResetMidTask,
  [switch]$DumpCsv,
  [switch]$TraceTransforms,
  [string]$VivadoBin = $env:VIVADO_BIN
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$r = [int]($N / 2)
$lanes = if ($N -eq 1024) { 16 } else { 8 }
if ($Nh -eq 0) { $Nh = $r - 1 }
if ($Nh -lt 1 -or $Nh -ge $r) { throw "Nh must be in [1,$($r-1)] for N=$N" }
$bound = if ($Precision -eq 4) { 8 } else { 128 }

$xvlog = Resolve-FactTool -ExplicitPath $VivadoBin -Executable 'xvlog.bat' -EnvironmentName 'VIVADO_BIN'
$toolDir = Split-Path -Parent $xvlog
$xelab = Join-Path $toolDir 'xelab.bat'
$xsim = Join-Path $toolDir 'xsim.bat'
foreach ($tool in @($xelab,$xsim)) { if (-not (Test-Path $tool)) { throw "Missing Vivado tool: $tool" } }

$work = Join-Path $root "build/xsim/p${Precision}_n${N}_c${Cin}o${Cout}_b${ChannelBase}"
New-Item -ItemType Directory -Force -Path $work | Out-Null
Initialize-FactRomWorkspace -Root $root -WorkDir $work
$sources = @(Get-FactRtlSources -Root $root)
$sources += Join-Path $root 'tb/tb_ntt46_fact_lean_ip_unified_axi_lite_core.sv'
$fileList = Join-Path $work 'xvlog_sources.f'
$sources | ForEach-Object { '"' + ($_.Replace('\','/')) + '"' } |
  Set-Content -Encoding ascii -LiteralPath $fileList
$snapshot = "tb_fact_p${Precision}_n${N}_c${Cin}o${Cout}"

Push-Location $work
try {
  & $xvlog -sv -f $fileList
  if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }
  $generics = @(
    "DUT_PRECISION=$Precision", "DUT_R=$r", "DUT_LANES=$lanes",
    "DUT_CIN=$Cin", "DUT_COUT=$Cout", 'DUT_COUT_MAX=4', "DUT_NH=$Nh",
    "DUT_PATTERN=$Pattern", "DUT_BOUND=$bound",
    "DUT_CHANNEL_BASE=$ChannelBase",
    "DUT_TEST_ILLEGAL=$([int]$ProtocolChecks.IsPresent)",
    "DUT_TEST_REPEAT_START=$([int]$ProtocolChecks.IsPresent)",
    "DUT_TEST_BACK_TO_BACK=$([int]$BackToBack.IsPresent)",
    "DUT_TEST_REPRELOAD=$([int]$Repreload.IsPresent)",
    "DUT_TEST_RESET_MID_TASK=$([int]$ResetMidTask.IsPresent)",
    "DUT_DUMP_CSV=$([int]$DumpCsv.IsPresent)", 'DUT_TIMEOUT_CYCLES=1200000',
    "DUT_TRACE_TRANSFORMS=$([int]$TraceTransforms.IsPresent)"
  )
  $genericArgs = ($generics | ForEach-Object { '-generic_top "' + $_ + '"' }) -join ' '
  $xelabCommand = '"' + $xelab + '" tb_ntt46_fact_lean_ip_unified_axi_lite_core ' +
                  $genericArgs + ' -s ' + $snapshot
  & cmd.exe /d /s /c $xelabCommand
  if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }
  & $xsim $snapshot -runall
  if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit code $LASTEXITCODE" }
  if (-not (Select-String -LiteralPath (Join-Path $work 'xsim.log') -Pattern 'tb_ntt46_fact_lean_ip_unified_axi_lite_core PASS' -Quiet)) {
    throw 'xsim completed without the final PASS marker'
  }
  Write-Host "FACT_XSIM_PASS precision=$Precision N=$N Cin=$Cin Cout=$Cout Nh=$Nh log=$work/xsim.log"
} finally {
  Pop-Location
}
