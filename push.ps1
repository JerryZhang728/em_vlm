# push.ps1 -- sync local VLM2/ files to the Nvidia device over LAN. No restart.
# Usage:
#   .\push                       # prompts for device IP (remembers last one)
#   .\push -DeviceIP 192.168.1.50
#
# After pushing, use .\start (foreground, see logs) or .\restart (background).

param(
    [string]$DeviceIP   = "",
    [string]$DeviceUser = "ubuntu",
    [string]$DevicePath = "/home/ubuntu/em_vlm"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "device_target.ps1")
$t = Resolve-DeviceTarget -DeviceIP $DeviceIP -DeviceUser $DeviceUser -DevicePath $DevicePath

$LocalPath = $PSScriptRoot
Clear-PushJunk -Root (Join-Path $LocalPath "src")

Write-Host "==> Pushing $LocalPath\  ->  $($t.User)@$($t.IP):$($t.Path)/" -ForegroundColor Cyan

# Pre-fix: make existing files writable so scp can overwrite them.
ssh "$($t.User)@$($t.IP)" "chmod -R u+rwX $($t.Path) 2>/dev/null; true" | Out-Null

$pushTargets = @(
    "src",
    "bin",
    "start",
    "pyproject.toml",
    "requirements.txt",
    "MANIFEST.in",
    "README.md",
    "LICENSE",
    "NOTICE.txt"
)

foreach ($f in $pushTargets) {
    $local = Join-Path $LocalPath $f
    if (Test-Path $local) {
        Write-Host "    scp $f" -ForegroundColor DarkGray
        scp -r -q $local "$($t.User)@$($t.IP):$($t.Path)/"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    FAIL transferring $f" -ForegroundColor Red
            exit 1
        }
    }
}

# scp loses the +x bit; restore exec permission on shell scripts.
ssh "$($t.User)@$($t.IP)" "chmod +x $($t.Path)/start $($t.Path)/bin/*.sh $($t.Path)/bin/em_vlm 2>/dev/null; true" | Out-Null

Write-Host "==> Push complete." -ForegroundColor Green
Write-Host "    From Windows:  .\start (foreground)  |  .\restart (background)" -ForegroundColor DarkGray
