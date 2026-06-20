# Developing Live VLM WebUI (personal dev loop)

This is the **author's workflow**: edit on a Windows notebook (with Claude
Cowork), push to an NVIDIA device on the LAN for live testing, then commit and
push to Git when stable. For first-time setup of a device, see
[INSTALL.md](./INSTALL.md) instead.

```
  Windows notebook  ──push──►  NVIDIA device (Orin / Thor)  ──►  browser test
        │                                                          
        └────────────────────── commit + push ──────────────►  GitHub
```

---

## One-time setup

1. The device already has the project installed (see INSTALL.md).
2. SSH works from Windows to the device. Recommended: passwordless key auth, so
   the scripts don't prompt for a password every run:

   ```powershell
   ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519 -N '""'
   type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh ubuntu@<device-ip> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
   ```

---

## The device IP is asked once, then remembered

DHCP changes the device IP, so the scripts **prompt for it** instead of
hardcoding it:

```
Enter Nvidia device IP [192.168.1.50]:
```

- The last IP you used is shown in brackets — press **Enter** to reuse it.
- Type a new IP only when DHCP changed it.
- It's saved in `.device_ip` (gitignored, per-machine).
- Override without prompting: `.\push -DeviceIP 192.168.1.77`

---

## Daily loop

From PowerShell in the project folder:

```powershell
.\push_and_restart.ps1     # push code + restart server, show last log lines
```

Then hard-refresh the browser (**Ctrl+Shift+R**) at `https://<device-ip>:8090`.

> **Testing an alternate folder (e.g. vlm3):** the scripts push to
> `/home/ubuntu/em_vlm` by default. To target a different clone, pass
> `-DevicePath`: `.\push_and_restart.ps1 -DevicePath /home/ubuntu/vlm3`.

Other helpers:

```powershell
.\push        # push code only (no restart)
.\start       # run server in foreground (Ctrl+C to stop, live logs)
.\restart     # restart server in background
.\push-images # copy the local Images/ test folder to the device
```

All of them prompt for / reuse the device IP the same way.

Tail logs while testing:

```powershell
ssh ubuntu@<device-ip> "tail -f /tmp/vlm.log"
```

---

## Pushing safely

`push` strips Python bytecode caches (`__pycache__`, `*.pyc`) before sending,
so junk never travels to the device. If it finds a `.fuse_hidden*` orphan file
(can happen when editing on a synced/mounted drive), it **stops and tells you to
delete it** rather than failing mid-transfer. Delete it on Windows:

```powershell
Remove-Item "<project>\src\live_vlm_webui\.fuse_hidden*" -Force
```

---

## When stable: commit and push to Git

The public repo is `https://github.com/jerryzhang728/em_vlm` (`main`). A fresh
device clones from there (see INSTALL.md), so push your tested changes up:

```powershell
git add -A
git commit -m "Describe the change"
git push origin main
```

---

## Two targets: Orin and Thor

The code auto-detects the board at runtime (Orin uses JetPack 6.2 / Python 3.10,
Thor uses JetPack 7.0 / Python 3.12), so the same scripts and repo work for
both. Work with **one device at a time** — point the scripts at whichever IP you
enter at the prompt.
