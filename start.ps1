# start.ps1 -- kill any running server and start in FOREGROUND so logs stream live.
# Ctrl+C in this window stops the server.
# Usage:  .\start             (prompts for device IP, remembers last one)

param(
    [string]$DeviceIP   = "",
    [string]$DeviceUser = "ubuntu",
    [string]$DevicePath = "/home/ubuntu/em_vlm"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "device_target.ps1")
$t = Resolve-DeviceTarget -DeviceIP $DeviceIP -DeviceUser $DeviceUser -DevicePath $DevicePath

Write-Host "==> Killing any existing live-vlm-webui processes..." -ForegroundColor Cyan
ssh "$($t.User)@$($t.IP)" "pkill -f live_vlm_webui.server 2>/dev/null; sleep 1; pgrep -f live_vlm_webui.server >/dev/null && pkill -9 -f live_vlm_webui.server; true"

Write-Host "==> Starting server in foreground (Ctrl+C to stop)..." -ForegroundColor Cyan
Write-Host "    URL: https://$($t.IP):8090" -ForegroundColor Yellow
Write-Host ""

ssh -t "$($t.User)@$($t.IP)" "cd $($t.Path) && PYTHONUNBUFFERED=1 .venv/bin/python -u -m live_vlm_webui.server"
