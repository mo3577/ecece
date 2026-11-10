# Build (if needed) and run ECE-screen on Windows.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\windows\run.ps1
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

$exe = Join-Path $Root "ECE-screen.exe"
if (-not (Test-Path $exe)) {
    & (Join-Path $PSScriptRoot "build.ps1")
}

# Load optional .env (KEY=VALUE lines) into the process environment.
$envFile = Join-Path $Root ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $i = $line.IndexOf("=")
        if ($i -lt 1) { return }
        $k = $line.Substring(0, $i).Trim()
        $v = $line.Substring($i + 1).Trim().Trim('"')
        Set-Item -Path "Env:$k" -Value $v
    }
}

# Put repo + deps on PATH so libmpv / ffmpeg resolve.
$deps = Join-Path $Root "deps"
$env:Path = "$Root;$deps;" + $env:Path

Write-Host "Launching ECE-screen (press X to quit)..." -ForegroundColor Cyan
& $exe
$code = $LASTEXITCODE
if ($code -ne 0) { exit $code }
