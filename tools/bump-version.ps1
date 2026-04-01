$root = Split-Path $PSScriptRoot -Parent

$rockspec = Get-ChildItem -Path (Join-Path $root 'bridge') -Filter 'civ5mcp-*.rockspec' | Select-Object -First 1
if (-not $rockspec) { Write-Error "No rockspec found"; exit 1 }

if ($rockspec.BaseName -notmatch 'civ5mcp-(\d+)\.(\d+)-1') {
    Write-Error "Unexpected rockspec name: $($rockspec.Name)"; exit 1
}
$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$newMinor = $minor + 1

$oldVer = "$major.$minor"
$newVer = "$major.$newMinor"
$oldDb  = "Civ5 MCP Bridge-$major$minor.db"
$newDb  = "Civ5 MCP Bridge-$major$newMinor.db"

Write-Host "Bumping $oldVer -> $newVer"

$newRockspec = Join-Path $rockspec.Directory "civ5mcp-$newVer-1.rockspec"
git -C $root mv $rockspec.FullName $newRockspec

(Get-Content $newRockspec) -replace [regex]::Escape("version = `"$oldVer-1`""), "version = `"$newVer-1`"" |
    Set-Content $newRockspec

$serverFile = Join-Path $root 'server\civ5_mcp_server.py'
(Get-Content $serverFile) -replace [regex]::Escape($oldDb), $newDb |
    Set-Content $serverFile
