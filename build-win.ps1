<#
.SYNOPSIS
    Script to build Eatsbits for Windows Native 64-bit using PowerShell.

.DESCRIPTION
    Builds the Eatsbits application into a native 64-bit Windows executable.
    Ensures Windows desktop support is enabled, generates platform files if missing,
    and handles build cleaning, profiling, debug modes, asset bundling, and launching.

.PARAMETER Clean
    Cleans previous build artifacts before building (runs 'flutter clean').

.PARAMETER Profile
    Builds in profile mode for performance profiling ('flutter build windows --profile').

.PARAMETER Debug
    Builds in debug mode ('flutter build windows --debug').

.PARAMETER Open
    Opens Windows File Explorer in the output directory containing the executable upon build completion.

.PARAMETER Run
    Launches the compiled native executable immediately after a successful build.

.EXAMPLE
    .\build-win.ps1
    .\build-win.ps1 -Clean
    .\build-win.ps1 -Run
    .\build-win.ps1 -Profile -Open
#>

[CmdletBinding()]
param (
    [switch]$Clean,
    [switch]$Profile,
    [switch]$DebugBuild,
    [switch]$Open,
    [switch]$Run
)

$ErrorActionPreference = "Stop"

# Ensure script is running from project root directory
$rootDir = $PSScriptRoot
if (-not $rootDir) {
    $rootDir = Get-Location
}
Set-Location $rootDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Eatsbits Windows Native 64-bit Build Script" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# STEP 1: Environment & Toolchain Verification
# ------------------------------------------------------------------
Write-Host "`n[*] STEP 1: Verifying environment & toolchain..." -ForegroundColor Yellow

if (-not (Get-Command "flutter" -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter SDK not found in system PATH. Please install Flutter and add it to your PATH."
    exit 1
}

# Enable Windows Desktop platform if not already enabled
Write-Host "    Ensuring Windows Desktop platform is enabled in Flutter..." -ForegroundColor Gray
flutter config --enable-windows-desktop | Out-Null

# Ensure windows platform files exist
$windowsDir = Join-Path $rootDir "windows"
if (-not (Test-Path $windowsDir)) {
    Write-Host "    Windows platform files missing. Recreating project files ('flutter create --platforms=windows .')..." -ForegroundColor Gray
    flutter create --platforms=windows .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to generate Windows platform files."
        exit 1
    }
}

# Close any running instances of the app to prevent CMake file lock errors
$runningProcesses = Get-Process | Where-Object { $_.ProcessName -eq "eatsbits" -or $_.ProcessName -eq "mobile_wren_daw" }
if ($runningProcesses) {
    Write-Host "    Closing running application instances to release file locks..." -ForegroundColor Yellow
    $runningProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

# ------------------------------------------------------------------
# STEP 2: Optional Clean
# ------------------------------------------------------------------
if ($Clean) {
    Write-Host "`n[*] STEP 2: Cleaning previous build artifacts..." -ForegroundColor Yellow
    flutter clean
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to clean Flutter build."
        exit 1
    }
}

# ------------------------------------------------------------------
# STEP 3: Build Windows Native Executable
# ------------------------------------------------------------------
Write-Host "`n[*] STEP 3: Compiling for Windows Native 64-bit..." -ForegroundColor Yellow

$buildMode = "Release"
$buildArgs = @("build", "windows")

if ($Profile) {
    $buildMode = "Profile"
    $buildArgs += "--profile"
    Write-Host "    Target Mode: Profile" -ForegroundColor Gray
} elseif ($DebugBuild) {
    $buildMode = "Debug"
    $buildArgs += "--debug"
    Write-Host "    Target Mode: Debug" -ForegroundColor Gray
} else {
    $buildArgs += "--release"
    Write-Host "    Target Mode: Release" -ForegroundColor Gray
}

Write-Host "    Executing: flutter $($buildArgs -join ' ')..." -ForegroundColor Gray
& flutter @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[!] Build failed!" -ForegroundColor Red
    Write-Host "    Note: If building fails due to missing Visual Studio toolchain," -ForegroundColor Yellow
    Write-Host "    please install Visual Studio 2022 with the 'Desktop development with C++' workload." -ForegroundColor Yellow
    exit 1
}

# Find output directory and executable
$outDir = Join-Path $rootDir "build\windows\x64\runner\$buildMode"
if (-not (Test-Path $outDir)) {
    # Fallback path if x64 subfolder structure differs
    $outDir = Join-Path $rootDir "build\windows\runner\$buildMode"
}

Write-Host "`n[+] Build completed successfully!" -ForegroundColor Green
Write-Host "    Output Directory: $outDir" -ForegroundColor Cyan

# Locate executable
$exeFile = Get-ChildItem -Path $outDir -Filter "*.exe" | Select-Object -First 1
if ($exeFile) {
    Write-Host "    Executable: $($exeFile.FullName)" -ForegroundColor Green
}

# ------------------------------------------------------------------
# STEP 4: Post-Build Actions (-Open / -Run)
# ------------------------------------------------------------------
if ($Open -and (Test-Path $outDir)) {
    Write-Host "`n[*] Opening output folder in File Explorer..." -ForegroundColor Yellow
    Start-Process "explorer.exe" -ArgumentList "/select,`"$($exeFile.FullName)`""
}

if ($Run -and $exeFile -and (Test-Path $exeFile.FullName)) {
    Write-Host "`n[*] Launching native executable: $($exeFile.Name)..." -ForegroundColor Yellow
    Start-Process -FilePath $exeFile.FullName -WorkingDirectory $outDir
}
