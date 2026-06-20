# push_and_restart.ps1
# ---------------------------------------------------------------------------
# One-shot dev-loop helper: copy the local VLM2/ tree to the Nvidia device over
# LAN, then restart live-vlm-webui on it (inside the venv at DevicePath/.venv).
#
# Prereqs (one-time, see DEVELOPING.md):
#   * SSH access to the device (password-free key auth recommended)
#   * On the device:  cd <project> && python3 -m venv .venv &&
#                     source .venv/bin/activate && pip install -e .
#     (or just run ./install.sh once -- see INSTALL.md)
#
# Usage:
#   .\push_and_restart.ps1                  # prompts for device IP (remembered)
#   .\push_and_restart.ps1 -DeviceIP 192.168.1.50
#   .\push_and_restart.ps1 -Restart:$false  # push only, don't restart
# ---------------------------------------------------------------------------

param(
    [string]$DeviceIP   = "",
    [string]$DeviceUser = "ubuntu",
    [string]$DevicePath = "/home/ubuntu/em_vlm",
    [bool]  $Restart    = $true
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "device_target.ps1")
$t = Resolve-DeviceTarget -DeviceIP $DeviceIP -DeviceUser $DeviceUser -DevicePath $DevicePath

$LocalPath  = $PSScriptRoot
$DPath      = $t.Path
$VenvPython = "$DPath/.venv/bin/python"
$VenvPip    = "$DPath/.venv/bin/pip"

Clear-PushJunk -Root (Join-Path $LocalPath "src")

Write-Host "==> Pushing $LocalPath\  ->  $($t.User)@$($t.IP):$DPath/" -ForegroundColor Cyan

$pushTargets = @(
    "src",
    "bin",
    "pyproject.toml",
    "requirements.txt",
    "MANIFEST.in",
    "README.md",
    "LICENSE"
)

foreach ($f in $pushTargets) {
    $local = Join-Path $LocalPath $f
    if (Test-Path $local) {
        Write-Host "    scp $f" -ForegroundColor DarkGray
        scp -r -q $local "$($t.User)@$($t.IP):$DPath/"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    FAIL transferring $f" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host "==> Push complete" -ForegroundColor Green

if ($Restart) {
    Write-Host "==> Restarting live-vlm-webui on the device (venv)..." -ForegroundColor Cyan

    $restartCmd = @"
set -e
cd $DPath
if [ ! -x "$VenvPython" ]; then
    echo "ERROR: venv not found at $VenvPython"
    echo "Run ./install.sh on the device first (see INSTALL.md)."
    exit 1
fi
$VenvPip install -e . --quiet 2>/dev/null || true
pkill -f 'live_vlm_webui.server' 2>/dev/null || true
pkill -f 'live-vlm-webui' 2>/dev/null || true
sleep 1
setsid $VenvPython -u -m live_vlm_webui.server </dev/null > /tmp/vlm.log 2>&1 &
disown 2>/dev/null || true
sleep 3
echo '--- last 30 lines of /tmp/vlm.log ---'
tail -n 30 /tmp/vlm.log
"@

    ssh "$($t.User)@$($t.IP)" $restartCmd
    Write-Host ""
    Write-Host "==> Done." -ForegroundColor Green
    Write-Host "    Open https://$($t.IP):8090 in your browser" -ForegroundColor Yellow
    Write-Host "    Tail logs:  ssh $($t.User)@$($t.IP) 'tail -f /tmp/vlm.log'" -ForegroundColor DarkGray
}
