# restart.ps1 -- restart the server in BACKGROUND on the device; logs to /tmp/vlm.log
# Usage:  .\restart            (prompts for device IP, remembers last one)

param(
    [string]$DeviceIP   = "",
    [string]$DeviceUser = "ubuntu",
    [string]$DevicePath = "/home/ubuntu/em_vlm"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "device_target.ps1")
$t = Resolve-DeviceTarget -DeviceIP $DeviceIP -DeviceUser $DeviceUser -DevicePath $DevicePath

$DPath = $t.Path
$VenvPython = "$DPath/.venv/bin/python"

$cmd = @"
set -e
cd $DPath
if [ ! -x "$VenvPython" ]; then
    echo "ERROR: venv not found at $VenvPython"
    exit 1
fi
pkill -f 'live_vlm_webui.server' 2>/dev/null || true
sleep 1
setsid $VenvPython -u -m live_vlm_webui.server </dev/null > /tmp/vlm.log 2>&1 &
disown 2>/dev/null || true
sleep 3
echo '--- last 30 lines of /tmp/vlm.log ---'
tail -n 30 /tmp/vlm.log
"@

ssh "$($t.User)@$($t.IP)" $cmd
Write-Host ""
Write-Host "==> Done. URL: https://$($t.IP):8090" -ForegroundColor Green
