# device_target.ps1
# ---------------------------------------------------------------------------
# Shared helpers for the VLM2 dev scripts (dot-sourced by the others).
#   * Resolve-DeviceTarget : ask for / remember the Nvidia device IP.
#                            DHCP-friendly: the last IP is stored in .device_ip
#                            and offered as the default (press Enter to reuse).
#   * Clear-PushJunk       : strip __pycache__/*.pyc before a push and refuse
#                            to push if .fuse_hidden orphan files are present.
#
# Use from a sibling script:
#     . (Join-Path $PSScriptRoot 'device_target.ps1')
# ---------------------------------------------------------------------------

function Resolve-DeviceTarget {
    param(
        [string]$DeviceIP   = "",
        [string]$DeviceUser = "ubuntu",
        [string]$DevicePath = "/home/ubuntu/em_vlm"
    )

    $stateFile = Join-Path $PSScriptRoot ".device_ip"

    if (-not $DeviceIP) {
        $last = ""
        if (Test-Path $stateFile) {
            $last = Get-Content $stateFile -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($last) { $last = $last.Trim() }
        }
        if ($last) {
            $ans = Read-Host "Enter Nvidia device IP [$last]"
            if ([string]::IsNullOrWhiteSpace($ans)) { $DeviceIP = $last } else { $DeviceIP = $ans.Trim() }
        } else {
            $DeviceIP = (Read-Host "Enter Nvidia device IP").Trim()
        }
    }

    if ([string]::IsNullOrWhiteSpace($DeviceIP)) {
        throw "No device IP provided."
    }

    # Remember for next time.
    Set-Content -Path $stateFile -Value $DeviceIP -Encoding ascii

    Write-Host "==> Target device: $DeviceUser@$DeviceIP : $DevicePath" -ForegroundColor DarkCyan

    return [pscustomobject]@{
        User = $DeviceUser
        IP   = $DeviceIP
        Path = $DevicePath
    }
}

function Clear-PushJunk {
    param([Parameter(Mandatory)][string]$Root)

    if (-not (Test-Path $Root)) { return }

    # Refuse to push if FUSE orphan files exist -- they can't be overwritten
    # and cause scp "permission denied" failures.
    $orphans = Get-ChildItem -Path $Root -Recurse -Force -Filter ".fuse_hidden*" -ErrorAction SilentlyContinue
    if ($orphans) {
        Write-Host "==> Found .fuse_hidden orphan file(s) -- delete these, then re-run:" -ForegroundColor Red
        $orphans | ForEach-Object { Write-Host "    $($_.FullName)" -ForegroundColor Red }
        throw "Refusing to push with .fuse_hidden orphans present."
    }

    # Strip Python bytecode caches so they never travel to the device.
    Get-ChildItem -Path $Root -Recurse -Force -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $Root -Recurse -Force -Include "*.pyc" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
