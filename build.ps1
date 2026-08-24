<#
.SYNOPSIS
    Script to build and serve the Eatsbeats web app on Windows using PowerShell.

.DESCRIPTION
    First builds the Flutter web application. Once the build finishes successfully,
    stops existing web server processes and starts a new Python HTTP server on a random (or specified) port.

.PARAMETER Clean
    Cleans previous build before building (runs 'flutter clean').

.PARAMETER Port
    Port number to listen on. If omitted or 0, a random free port will be automatically selected.

.PARAMETER Wasm
    Builds with WebAssembly support ('flutter build web --wasm').

.PARAMETER Profile
    Builds in profile mode ('flutter build web --profile').

.PARAMETER NoBrowser
    Prevents automatically opening the default browser.

.EXAMPLE
    .\build.ps1
    .\build.ps1 -Clean
    .\build.ps1 -Port 8080
    .\build.ps1 -Wasm
#>

[CmdletBinding()]
param (
    [switch]$Clean,
    [int]$Port = 8080,
    [switch]$Wasm,
    [switch]$Profile,
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

# Ensure we are in the project root directory
$rootDir = $PSScriptRoot
if (-not $rootDir) {
    $rootDir = Get-Location
}
Set-Location $rootDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Eatsbeats Web App Build & Serve Script" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# STEP 1: Build the Flutter Web Application FIRST
# ------------------------------------------------------------------
Write-Host "`n[*] STEP 1: Building the app..." -ForegroundColor Yellow

if ($Clean) {
    Write-Host "    Cleaning previous build ('flutter clean')..." -ForegroundColor Gray
    flutter clean
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to clean Flutter project."
        exit 1
    }
}

# Construct build arguments
$buildArgs = @("build", "web", "--no-tree-shake-icons", "--pwa-strategy=none")
if ($Wasm) {
    $buildArgs += "--wasm"
    Write-Host "    Target: Web (WASM)" -ForegroundColor Gray
} elseif ($Profile) {
    $buildArgs += "--profile"
    Write-Host "    Target: Web (Profile)" -ForegroundColor Gray
} else {
    $buildArgs += "--release"
    Write-Host "    Target: Web (Release)" -ForegroundColor Gray
}

Write-Host "    Executing: flutter $($buildArgs -join ' ')..." -ForegroundColor Gray
& flutter @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed! Existing web server was NOT stopped."
    exit 1
}

$buildWebDir = Join-Path $rootDir "build\web"
if (-not (Test-Path $buildWebDir)) {
    Write-Error "Build failed: output directory '$buildWebDir' was not found."
    exit 1
}

function Format-FileSize ([long]$bytes) {
    if ($bytes -ge 1GB) {
        return ("{0:N2} GB ({1:N0} bytes)" -f ($bytes / 1GB), $bytes)
    } elseif ($bytes -ge 1MB) {
        return ("{0:N2} MB ({1:N0} bytes)" -f ($bytes / 1MB), $bytes)
    } elseif ($bytes -ge 1KB) {
        return ("{0:N2} KB ({1:N0} bytes)" -f ($bytes / 1KB), $bytes)
    } else {
        return ("{0:N0} bytes" -f $bytes)
    }
}

# Patch flutter_service_worker.js to prevent onlineFirst uncaught TypeError on fetch failure
$swFile = Join-Path $buildWebDir "flutter_service_worker.js"
if (Test-Path $swFile) {
    try {
        $swContent = Get-Content $swFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($swContent) {
            $swContent = $swContent.Replace("throw error;", "return new Response('', {status: 404, statusText: 'Not Found'});")
            if ($swContent -notmatch "unhandledrejection") {
                $swContent += "`nself.addEventListener('unhandledrejection', function(e) { e.preventDefault(); });`n"
            }
            Set-Content -Path $swFile -Value $swContent -Encoding UTF8
            Write-Host "    [+] Patched flutter_service_worker.js for network resilience." -ForegroundColor Gray
        }
    } catch {
        Write-Host "    [!] Note: Unable to patch service worker file: $_" -ForegroundColor Gray
    }
}

# Copy audio folder (e.g. audio/ir/*.zip) to build/web/audio/ if present
$audioSource = Join-Path $rootDir "audio"
if (Test-Path $audioSource) {
    $audioTarget = Join-Path $buildWebDir "audio"
    Copy-Item -Path "$audioSource\*" -Destination $audioTarget -Recurse -Force
    Write-Host "    [+] Copied audio assets to build/web/audio/." -ForegroundColor Gray
}

Write-Host "[+] Build completed successfully!" -ForegroundColor Green

# ------------------------------------------------------------------
# Build Artifact & Package Sizes
# ------------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Web Build Artifact & Package Sizes" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$allWebFiles = Get-ChildItem -Path $buildWebDir -Recurse -File -ErrorAction SilentlyContinue
$totalWebBytes = if ($allWebFiles) { ($allWebFiles | Measure-Object -Property Length -Sum).Sum } else { 0 }

Write-Host "  Binaries / Compiled Scripts:" -ForegroundColor Yellow
$keyWebFiles = @(
    "main.dart.js",
    "main.dart.wasm",
    "main.dart.mjs",
    "flutter.js",
    "flutter_bootstrap.js",
    "flutter_service_worker.js"
)
foreach ($kf in $keyWebFiles) {
    $item = Join-Path $buildWebDir $kf
    if (Test-Path $item) {
        $len = (Get-Item $item).Length
        Write-Host ("    - {0,-26} : {1}" -f $kf, (Format-FileSize $len)) -ForegroundColor Gray
    }
}

$ckDir = Join-Path $buildWebDir "canvaskit"
if (Test-Path $ckDir) {
    $ckFiles = Get-ChildItem -Path $ckDir -Recurse -File -ErrorAction SilentlyContinue
    $ckBytes = if ($ckFiles) { ($ckFiles | Measure-Object -Property Length -Sum).Sum } else { 0 }
    Write-Host ("    - {0,-26} : {1}" -f "canvaskit/ (wasm engines)", (Format-FileSize $ckBytes)) -ForegroundColor Gray
}

Write-Host "`n  Assets & Bundles:" -ForegroundColor Yellow
$assetsDir = Join-Path $buildWebDir "assets"
if (Test-Path $assetsDir) {
    $assetFiles = Get-ChildItem -Path $assetsDir -Recurse -File -ErrorAction SilentlyContinue
    $assetBytes = if ($assetFiles) { ($assetFiles | Measure-Object -Property Length -Sum).Sum } else { 0 }
    Write-Host ("    - {0,-26} : {1}" -f "assets/", (Format-FileSize $assetBytes)) -ForegroundColor Gray
}

$audioDir = Join-Path $buildWebDir "audio"
if (Test-Path $audioDir) {
    $audioFiles = Get-ChildItem -Path $audioDir -Recurse -File -ErrorAction SilentlyContinue
    $audioBytes = if ($audioFiles) { ($audioFiles | Measure-Object -Property Length -Sum).Sum } else { 0 }
    Write-Host ("    - {0,-26} : {1}" -f "audio/", (Format-FileSize $audioBytes)) -ForegroundColor Gray
}

Write-Host "  ----------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ("  Total Package Size         : {0}" -f (Format-FileSize $totalWebBytes)) -ForegroundColor Green
Write-Host ("  Output Location            : {0}" -f $buildWebDir) -ForegroundColor DarkGray
Write-Host "============================================================" -ForegroundColor Cyan


# ------------------------------------------------------------------
# STEP 2: Ensure Open Servers are Closed BEFORE Starting New One
# ------------------------------------------------------------------
Write-Host "`n[*] STEP 2: Closing open web server processes..." -ForegroundColor Yellow

# 1. Stop process from .server.pid if exists
$pidFile = Join-Path $rootDir ".server.pid"
if (Test-Path $pidFile) {
    try {
        $oldPidRaw = Get-Content $pidFile -ErrorAction SilentlyContinue | Out-String
        $oldPid = $oldPidRaw.Trim()
        if ($oldPid -match '^\d+$') {
            $proc = Get-Process -Id ([int]$oldPid) -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Host "    Stopping existing server (PID: $oldPid)..." -ForegroundColor Gray
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        # Ignore errors
    } finally {
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }
}

# 2. Stop any running Python HTTP servers or serve_fresh processes
try {
    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -like "python*" -or $_.Name -eq "py.exe") -and 
        ($_.CommandLine -like "*http.server*" -or $_.CommandLine -like "*serve_fresh*")
    }
    if ($procs) {
        foreach ($proc in $procs) {
            Write-Host "    Stopping Python server (PID: $($proc.ProcessId))..." -ForegroundColor Gray
            Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 1
    } else {
        Write-Host "    No existing Python web servers found." -ForegroundColor Gray
    }
} catch {
    Write-Host "    Note: Unable to query process list or no matching server found." -ForegroundColor Gray
}

# 3. If a specific port is requested, stop any process listening on that port
if ($Port -gt 0) {
    try {
        $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        foreach ($conn in $conns) {
            if ($conn.OwningProcess -and $conn.OwningProcess -ne $PID) {
                Write-Host "    Stopping process (PID: $($conn.OwningProcess)) listening on port $Port..." -ForegroundColor Gray
                Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        # Ignore if Get-NetTCPConnection isn't available or port is free
    }
}

Write-Host "[+] All previous open servers closed." -ForegroundColor Green

# ------------------------------------------------------------------
# STEP 3: Start New Server
# ------------------------------------------------------------------
Write-Host "`n[*] STEP 3: Starting new web server..." -ForegroundColor Yellow

# Detect available Python launcher
$pythonCmd = "python"
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
    if (Get-Command "py" -ErrorAction SilentlyContinue) {
        $pythonCmd = "py"
    } elseif (Get-Command "python3" -ErrorAction SilentlyContinue) {
        $pythonCmd = "python3"
    }
}

$serveFreshPy = Join-Path $rootDir "scripts\serve_fresh.py"

if (Test-Path $serveFreshPy) {
    $pyArgs = @($serveFreshPy, "--no-build")
    if ($Port -gt 0) {
        $pyArgs += @("--port", $Port.ToString())
    }
    if ($NoBrowser) {
        $pyArgs += "--no-browser"
    }
    & $pythonCmd @pyArgs
} else {
    if ($Port -le 0) {
        $ip = [System.Net.IPAddress]::Loopback
        $listener = New-Object System.Net.Sockets.TcpListener -ArgumentList @($ip, 0)
        $listener.Start()
        $Port = $listener.LocalEndpoint.Port
        $listener.Stop()
    }
    Set-Location $buildWebDir
    Write-Host "    Starting server on http://localhost:$Port..." -ForegroundColor Green
    & $pythonCmd -m http.server $Port
}