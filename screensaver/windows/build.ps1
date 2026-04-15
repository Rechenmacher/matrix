# build.ps1 — Build the Matrix screensaver for Windows
# Usage: .\build.ps1 [-Configuration Release]
#
# Prerequisites:
#   - .NET 8 SDK (https://dotnet.microsoft.com/download)
#   - WebView2 Runtime (pre-installed on Windows 11, downloadable for Windows 10)
#
# Output: dist\MatrixScreenSaver.scr + dist\web\ (web assets)

param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Join-Path $scriptDir "MatrixScreenSaver"
$distDir = Join-Path $scriptDir "dist"
$repoRoot = (Resolve-Path (Join-Path $scriptDir ".." "..")).Path

Write-Host "=== Building MatrixScreenSaver ($Configuration) ===" -ForegroundColor Green

# Clean dist
if (Test-Path $distDir) { Remove-Item -Recurse -Force $distDir }
New-Item -ItemType Directory -Path $distDir | Out-Null

# Build
dotnet publish $projectDir `
    -c $Configuration `
    -r win-x64 `
    --self-contained false `
    -o (Join-Path $distDir "build")

if ($LASTEXITCODE -ne 0) { throw "Build failed" }

# Rename .exe to .scr
$exe = Join-Path $distDir "build" "MatrixScreenSaver.exe"
$scr = Join-Path $distDir "MatrixScreenSaver.scr"
Copy-Item $exe $scr

# Copy WebView2 loader DLL (required at runtime)
$loaderDll = Join-Path $distDir "build" "WebView2Loader.dll"
if (Test-Path $loaderDll) {
    Copy-Item $loaderDll $distDir
}

# Copy web assets
$webDist = Join-Path $distDir "web"
New-Item -ItemType Directory -Path $webDist | Out-Null

# Copy the essential web files from the repo root
$webItems = @("index.html", "js", "lib", "shaders", "assets")
foreach ($item in $webItems) {
    $src = Join-Path $repoRoot $item
    if (Test-Path $src) {
        $dest = Join-Path $webDist $item
        if ((Get-Item $src).PSIsContainer) {
            Copy-Item -Recurse $src $dest
        } else {
            Copy-Item $src $dest
        }
    }
}

# Summary
$scrSize = (Get-Item $scr).Length / 1MB
Write-Host ""
Write-Host "=== Build complete ===" -ForegroundColor Green
Write-Host "  Screensaver: $scr ($([math]::Round($scrSize, 1)) MB)"
Write-Host "  Web assets:  $webDist"
Write-Host ""
Write-Host "To install:" -ForegroundColor Cyan
Write-Host "  1. Copy dist\MatrixScreenSaver.scr and dist\web\ to C:\Windows\System32\"
Write-Host "  2. Right-click MatrixScreenSaver.scr -> Install"
Write-Host "  Or: rundll32.exe desk.cpl,InstallScreenSaver $scr"
