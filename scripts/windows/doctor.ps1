# Check Windows deps for ECE-screen.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\windows\doctor.ps1
# ASCII-only strings: Windows PowerShell 5.1 breaks on UTF-8 em-dashes without BOM.
$ErrorActionPreference = "Continue"
$bad = 0

function Ok($msg) { Write-Host "  OK  $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "  FAIL $msg" -ForegroundColor Red; script:bad++ }
function Warn($msg) { Write-Host "  WARN $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "ECE-screen Windows doctor" -ForegroundColor Cyan
Write-Host ""

if (Get-Command go -ErrorAction SilentlyContinue) {
    Ok ("go " + (go version))
} else {
    Fail "Go not found - install from https://go.dev/dl and reopen the terminal"
}

$gcc = Get-Command gcc -ErrorAction SilentlyContinue
if (-not $gcc) { $gcc = Get-Command x86_64-w64-mingw32-gcc -ErrorAction SilentlyContinue }
if ($gcc) { Ok ("C compiler: " + $gcc.Source) }
else { Fail "MinGW gcc not found - install MSYS2 and: pacman -S mingw-w64-x86_64-gcc (then add mingw64\bin to PATH)" }

$ff = Get-Command ffprobe -ErrorAction SilentlyContinue
if ($ff) { Ok ("ffprobe: " + $ff.Source) }
else { Warn "ffprobe missing - install ffmpeg (optional but used for video sizing)" }

function Find-LibMpv {
    $names = @("libmpv-2.dll", "libmpv.dll", "mpv-2.dll")
    $repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    # Shallow search in project dirs only (no PATH recursion - too slow/noisy).
    $dirs = @(
        (Join-Path $repo "deps"),
        $repo.Path,
        (Join-Path $repo "build")
    )
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir -PathType Container)) { continue }
        foreach ($name in $names) {
            $p = Join-Path $dir $name
            if (Test-Path $p) { return (Resolve-Path $p).Path }
        }
    }
    foreach ($name in $names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

$dll = Find-LibMpv
if ($dll) { Ok ("libmpv DLL: $dll") }
else {
    Fail "libmpv DLL not found - download a Windows mpv/libmpv build and place libmpv-2.dll (or libmpv.dll) in .\deps\"
    Write-Host "         https://sourceforge.net/projects/mpv-player-windows/files/libmpv/" -ForegroundColor DarkGray
}

if ($env:DISPLAY -or $env:WAYLAND_DISPLAY) {
    Warn "DISPLAY/WAYLAND set - on Windows this is usually unused"
}

Write-Host ""
if ($bad -gt 0) {
    Write-Host "Doctor found $bad required issue(s)." -ForegroundColor Red
    exit 1
}
Write-Host "Ready to build." -ForegroundColor Green
exit 0
