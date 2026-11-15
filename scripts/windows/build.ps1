# Build ECE-screen.exe for Windows.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\windows\build.ps1
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

Write-Host "ECE-screen Windows build" -ForegroundColor Cyan

# Prefer MSYS2 mingw64 toolchain if present with gcc.exe and gcc not already on PATH.
$mingwBin = "C:\msys64\mingw64\bin"
$mingwGcc = Join-Path $mingwBin "gcc.exe"
if (-not (Get-Command gcc -ErrorAction SilentlyContinue)) {
    if (Test-Path $mingwGcc) {
        $env:Path = "$mingwBin;" + $env:Path
        Write-Host "Using MSYS2 mingw64: $mingwBin"
    } elseif (Test-Path $mingwBin) {
        Write-Host "WARNING: $mingwBin exists but gcc.exe is missing." -ForegroundColor Yellow
        Write-Host "Open MSYS2 MINGW64 and run:" -ForegroundColor Yellow
        Write-Host "  pacman -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-pkgconf" -ForegroundColor Yellow
    }
}

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    throw "Go not found. Install from https://go.dev/dl"
}
if (-not (Get-Command gcc -ErrorAction SilentlyContinue)) {
    throw @"
gcc not found. Install the MinGW-w64 toolchain:

1. Install MSYS2 from https://www.msys2.org
2. Open MSYS2 MINGW64 and run:
     pacman -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-pkgconf
3. Add C:\msys64\mingw64\bin to your user PATH (or reopen this shell after install).
"@
}

# raylib needs CGO. go-mpv with -tags nocgo loads libmpv.dll via purego
# (no mpv/client.h / -lmpv required). Place libmpv.dll next to the exe.
$env:CGO_ENABLED = "1"
$env:GOOS = "windows"
$env:GOARCH = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }

Write-Host "go mod download..."
go mod download

$out = Join-Path $Root "ECE-screen.exe"
Write-Host "compiling $out (tags: nocgo) ..."
go build -tags nocgo -o $out .
if ($LASTEXITCODE -ne 0) {
    throw "go build failed with exit code $LASTEXITCODE"
}

# Ensure a libmpv DLL sits next to the exe (runtime load / PATH).
$deps = Join-Path $Root "deps"
New-Item -ItemType Directory -Force -Path $deps | Out-Null
$candidates = @(
    (Join-Path $deps "libmpv-2.dll"),
    (Join-Path $deps "libmpv.dll"),
    (Join-Path $Root "libmpv-2.dll"),
    (Join-Path $Root "libmpv.dll")
)
$dll = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($dll) {
    $destNames = @("libmpv-2.dll", "libmpv.dll")
    foreach ($name in $destNames) {
        $dest = Join-Path $Root $name
        if (-not (Test-Path $dest)) {
            Copy-Item $dll $dest -Force
            Write-Host "copied $(Split-Path $dll -Leaf) -> $name"
        }
    }
} else {
    Write-Host "WARNING: no libmpv DLL in .\deps - runtime video needs libmpv-2.dll or libmpv.dll beside ECE-screen.exe" -ForegroundColor Yellow
}

Write-Host "Built $out" -ForegroundColor Green
Write-Host "Run with:  powershell -File scripts\windows\run.ps1"
