# Expose local PocketBase (:8090) to the internet via Cloudflare quick tunnel.
# Phone (Android/iOS) admin can then use the printed https://….trycloudflare.com URL
# without being on the same Wi-Fi. Requires ECE-screen (or PocketBase) already running.
#
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File scripts\windows\remote-tunnel.ps1
#
# For a stable hostname, create a Cloudflare named tunnel and set ECE_PUBLIC_URL
# (see docs/operations.md). Quick tunnels get a new random URL each run.

$ErrorActionPreference = "Stop"
$Port = if ($env:ECE_PB_PORT) { $env:ECE_PB_PORT } else { "8090" }
$Target = "http://127.0.0.1:$Port"
$Deps = Join-Path $PSScriptRoot "..\..\deps"
$Bin = Join-Path $Deps "cloudflared.exe"

function Ensure-Cloudflared {
    if (Get-Command cloudflared -ErrorAction SilentlyContinue) {
        return (Get-Command cloudflared).Source
    }
    if (Test-Path $Bin) { return $Bin }

    New-Item -ItemType Directory -Force -Path $Deps | Out-Null
    $url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
    Write-Host "Downloading cloudflared -> $Bin"
    Invoke-WebRequest -Uri $url -OutFile $Bin -UseBasicParsing
    return $Bin
}

Write-Host "Checking PocketBase at $Target ..."
try {
    Invoke-WebRequest -Uri "$Target/api/health" -UseBasicParsing -TimeoutSec 5 | Out-Null
} catch {
    Write-Host "WARNING: could not reach $Target/api/health - start ECE-screen first."
}

$cf = Ensure-Cloudflared
Write-Host ""
Write-Host "Starting Cloudflare tunnel -> $Target"
Write-Host "Copy the https://....trycloudflare.com URL into the phone ECE Admin server field."
Write-Host "Press Ctrl+C to stop the tunnel."
Write-Host ""
& $cf tunnel --url $Target
