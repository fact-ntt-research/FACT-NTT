param([string]$Root = '')

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
else { $Root = (Resolve-Path -LiteralPath $Root).Path }
$manifest = Join-Path $Root 'MANIFEST_SHA256.csv'
$rows = Get-ChildItem -LiteralPath $Root -Recurse -File |
  Where-Object { $_.FullName -ne $manifest -and $_.FullName -notmatch '[\\/]build[\\/]' -and $_.FullName -notmatch '[\\/]\.git[\\/]' } |
  ForEach-Object {
    [pscustomobject]@{
      Path = $_.FullName.Substring($Root.Length + 1).Replace('\','/')
      Length = $_.Length
      SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
  } | Sort-Object Path
$rows | Export-Csv -NoTypeInformation -Encoding ascii -LiteralPath $manifest
Write-Host "MANIFEST_GENERATED files=$($rows.Count) path=$manifest"
