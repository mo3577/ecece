# Build ECE-screen.exe for Windows.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\windows\build.ps1
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

Write-Host "ECE-screen Windows build" -ForegroundColor Cyan

# Prefer MSYS2 mingw64 toolchain if present and gcc not already on PATH.
$mingwBin = "C:\msys64\mingw64\bin"
if (-not (Get-Command gcc -ErrorAction SilentlyContinue) -and (Test-Path $mingwBin)) {
    $env:Path = "$mingwBin;" + $env:Path
    Write-Host "Using MSYS2 mingw64: $mingwBin"
}

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    throw "Go not found. Install from https://go.dev/dl"
}
if (-not (Get-Command gcc -ErrorAction SilentlyContinue)) {
    throw "gcc not found. Install MSYS2 mingw-w64-x86_64-gcc and add mingw64\bin to PATH."
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
