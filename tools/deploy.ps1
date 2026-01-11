Param(
    [string]$Source = (Get-ChildItem -Path (Join-Path $PSScriptRoot '..\dist') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object { $_.FullName }),
    [string]$Destination = (Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath "My Games\Sid Meier's Civilization 5\MODS")
)

# Resolve source
$srcResolved = Resolve-Path -LiteralPath $Source -ErrorAction SilentlyContinue
if (-not $srcResolved) {
    Write-Error "Source not found: $Source"
    exit 1
}
$srcPath = $srcResolved.Path

# Ensure destination exists
if (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

# Target path inside MODS
$targetPath = Join-Path -Path $Destination -ChildPath (Split-Path -Path $srcPath -Leaf)

# Remove existing target to ensure a clean deploy
if (Test-Path -LiteralPath $targetPath) {
    Remove-Item -LiteralPath $targetPath -Recurse -Force
}

# Copy
Copy-Item -LiteralPath $srcPath -Destination $Destination -Recurse -Force

Write-Output "Deployed '$srcPath' to '$targetPath'"