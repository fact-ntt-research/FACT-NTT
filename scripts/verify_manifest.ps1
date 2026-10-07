param(
  [string]$Manifest = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'MANIFEST_SHA256.csv')
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath $Manifest)) {
  throw "Manifest not found: $Manifest"
}
$Manifest = (Resolve-Path -LiteralPath $Manifest).Path

$rows = @(Import-Csv -LiteralPath $Manifest)
$listed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($row in $rows) {
  $relative = $row.Path.Replace('/', [IO.Path]::DirectorySeparatorChar)
  if (-not $listed.Add($relative)) { throw "Duplicate manifest entry: $($row.Path)" }
  $path = Join-Path $root $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing manifest file: $($row.Path)"
  }
  $item = Get-Item -LiteralPath $path
  if ([int64]$row.Length -ne $item.Length) {
    throw "Length mismatch: $($row.Path)"
  }
  $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $row.SHA256.ToLowerInvariant()) {
    throw "SHA256 mismatch: $($row.Path)"
  }
}

$actual = Get-ChildItem -LiteralPath $root -Recurse -File |
  Where-Object { $_.FullName -ne $Manifest -and $_.FullName -notmatch '[\\/]build[\\/]' -and $_.FullName -notmatch '[\\/]\.git[\\/]' } |
  ForEach-Object { $_.FullName.Substring($root.Length + 1) }
$extras = @($actual | Where-Object { -not $listed.Contains($_) })
if ($extras.Count -ne 0) { throw "Files missing from manifest: $($extras -join ', ')" }

Write-Host "FACT_MANIFEST_PASS files=$($rows.Count) root=$root"
