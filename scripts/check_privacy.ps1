param([string]$Root = '')

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
else { $Root = (Resolve-Path -LiteralPath $Root).Path }
# Check local-environment paths and contact information.
# TCAS-II is single-blind; the authors in CITATION.cff are intentional.
$extensions = @('.md','.txt','.csv','.json','.yaml','.yml','.cff','.sv','.v','.vh','.tcl','.ps1','.py','.f','.mem','.rpt','.log','.gitignore')
$patterns = @(
  '(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
  '(?i)C:[/\\]Users[/\\]',
  '(?i)[A-Z]:[/\\]NTT_[^/\\\s]+',
  '(?i)NTT_4\.6_UPGRADE'
)
$hits = [System.Collections.Generic.List[object]]::new()
foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File) {
  if ($file.FullName -match '[\\/]build[\\/]' -or $file.Extension.ToLowerInvariant() -notin $extensions) { continue }
  $lineNo = 0
  foreach ($line in Get-Content -LiteralPath $file.FullName -ErrorAction Stop) {
    $lineNo++
    if ($line -match '(?i)^\|\s*Host\s*:\s*(.+?)\s*$' -and $Matches[1] -ne '<REDACTED>') {
      $hits.Add([pscustomobject]@{File=$file.FullName.Substring($Root.Length+1).Replace('\','/');Line=$lineNo;Pattern='unredacted Vivado Host header'})
      continue
    }
    foreach ($pattern in $patterns) {
      if ($line -match $pattern) {
        $hits.Add([pscustomobject]@{File=$file.FullName.Substring($Root.Length+1).Replace('\','/');Line=$lineNo;Pattern=$pattern})
        break
      }
    }
  }
}
if ($hits.Count -ne 0) {
  $hits | Format-Table -AutoSize | Out-Host
  throw "PRIVACY_SCAN_FAIL hits=$($hits.Count)"
}
Write-Host "PRIVACY_SCAN_PASS root=$Root"
