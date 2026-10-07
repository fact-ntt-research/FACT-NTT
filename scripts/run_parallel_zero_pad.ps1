param(
  [ValidateSet(1,2,4)][int]$Cin = 4,
  [ValidateRange(1,511)][int]$Nh = 511,
  [ValidateSet(0,4,6)][int]$Pattern = 6,
  [switch]$RunImplementation,
  [string]$VivadoBin = $env:VIVADO_BIN
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fact_sources.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$baseline = Join-Path $root 'baselines/parallel_zero_pad'
$work = Join-Path $root "build/parallel_zero_pad/c${Cin}_nh${Nh}_p${Pattern}"
if ($RunImplementation) { $work = Join-Path $root 'build/parallel_zero_pad/implementation' }
New-Item -ItemType Directory -Force -Path $work | Out-Null
Copy-Item -LiteralPath (Join-Path $baseline 'rom') -Destination $work -Recurse -Force

Push-Location $work
try {
  if ($RunImplementation) {
    $vivado = Resolve-FactTool -ExplicitPath $VivadoBin -Executable 'vivado.bat' -EnvironmentName 'VIVADO_BIN'
    & $vivado -mode batch -source (Join-Path $baseline 'implement.tcl') -tclargs $baseline $work
    if ($LASTEXITCODE -ne 0) { throw 'Parallel zero-pad implementation failed.' }
    return
  }
  $xvlog = Resolve-FactTool -ExplicitPath $VivadoBin -Executable 'xvlog.bat' -EnvironmentName 'VIVADO_BIN'
  $toolDir = Split-Path -Parent $xvlog
  $sources = Get-Content -LiteralPath (Join-Path $baseline 'sources.f') | Where-Object { $_.Trim() }
  $fileList = Join-Path $work 'sources.f'
  $sources | ForEach-Object { '"' + ((Join-Path $baseline $_).Replace('\','/')) + '"' } |
    Set-Content -LiteralPath $fileList -Encoding ascii
  & $xvlog -sv -f $fileList
  if ($LASTEXITCODE -ne 0) { throw 'Parallel zero-pad xvlog failed.' }
  $snapshot = "parallel_zp_c${Cin}_nh${Nh}_p${Pattern}"
  $generics = @("DUT_CIN=$Cin", "DUT_NH=$Nh", "DUT_PATTERN=$Pattern", 'DUT_DUMP_CSV=1')
  $genericArgs = ($generics | ForEach-Object { '-generic_top "' + $_ + '"' }) -join ' '
  $command = '"' + (Join-Path $toolDir 'xelab.bat') +
    '" tb_ntt46_zero_pad_p520_n1024_local_core ' + $genericArgs + ' -s ' + $snapshot
  & cmd.exe /d /s /c $command
  if ($LASTEXITCODE -ne 0) { throw 'Parallel zero-pad xelab failed.' }
  & (Join-Path $toolDir 'xsim.bat') $snapshot -runall
  if ($LASTEXITCODE -ne 0) { throw 'Parallel zero-pad xsim failed.' }
  $log = Get-Content -LiteralPath (Join-Path $work 'xsim.log') -Raw
  $expectedCycles = @{1=332; 2=554; 4=998}[$Cin]
  if ($log -match 'Fatal:|ERROR:' -or $log -notmatch "PASS Cin=$Cin Nh=$Nh Pattern=$Pattern compute_cycles=$expectedCycles rows=1024") {
    throw 'Parallel zero-pad failed its coefficient or archived cycle check.'
  }
  Write-Host "PARALLEL_ZERO_PAD_PASS Cin=$Cin cycles=$expectedCycles coefficients=1024"
} finally {
  Pop-Location
}
