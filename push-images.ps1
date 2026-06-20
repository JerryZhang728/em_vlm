# push-images.ps1 -- sync the /VLM/Images test folder to the Nvidia device.
# Usage:  .\push-images        (prompts for device IP, remembers last one)

param(
    [string]$DeviceIP   = "",
    [string]$DeviceUser = "ubuntu",
    [string]$DeviceDest = "/home/ubuntu/Images",
    [string]$LocalSrc   = "C:\Users\jerry\OneDrive_Gmail\OneDrive\Claude\VLM\Images"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "device_target.ps1")
$t = Resolve-DeviceTarget -DeviceIP $DeviceIP -DeviceUser $DeviceUser -DevicePath $DeviceDest

if (-not (Test-Path $LocalSrc)) {
    Write-Host "Local source missing: $LocalSrc" -ForegroundColor Red
    exit 1
}

Write-Host "==> Pushing $LocalSrc\  ->  $($t.User)@$($t.IP):$DeviceDest/" -ForegroundColor Cyan

# Make destination writable first so scp can overwrite existing files.
ssh "$($t.User)@$($t.IP)" "mkdir -p $DeviceDest; chmod -R u+rwX $DeviceDest 2>/dev/null; true" | Out-Null

scp -r -q "$LocalSrc\*" "$($t.User)@$($t.IP):$DeviceDest/"
if ($LASTEXITCODE -eq 0) {
    Write-Host "==> Done." -ForegroundColor Green
    ssh "$($t.User)@$($t.IP)" "ls -la $DeviceDest | head -20"
} else {
    Write-Host "==> Push failed." -ForegroundColor Red
    exit 1
}
