# Allow ECE-screen LAN admin discovery + PocketBase through Windows Firewall.
# Run once (as Administrator if prompted):
#   powershell -ExecutionPolicy Bypass -File scripts\windows\allow-firewall.ps1
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$exe = Join-Path $Root "ECE-screen.exe"

$rules = @(
    @{ Name = "ECE-screen PocketBase TCP 8090"; Protocol = "TCP"; Port = 8090 },
    @{ Name = "ECE-screen Admin Discovery UDP 28090"; Protocol = "UDP"; Port = 28090 }
)

foreach ($r in $rules) {
    $existing = netsh advfirewall firewall show rule name="$($r.Name)" 2>$null
    if ($LASTEXITCODE -eq 0 -and $existing -match $r.Name) {
        Write-Host "OK already: $($r.Name)"
        continue
    }
    if (Test-Path $exe) {
        netsh advfirewall firewall add rule name="$($r.Name)" dir=in action=allow protocol=$($r.Protocol) localport=$($r.Port) program="$exe" profile=private,domain | Out-Null
    } else {
        netsh advfirewall firewall add rule name="$($r.Name)" dir=in action=allow protocol=$($r.Protocol) localport=$($r.Port) profile=private,domain | Out-Null
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED $($r.Name) - re-run this script as Administrator" -ForegroundColor Red
        exit 1
    }
    Write-Host "Added $($r.Name)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Firewall ready. Keep phone + PC on the same Wi-Fi (not guest/AP isolation)." -ForegroundColor Cyan
