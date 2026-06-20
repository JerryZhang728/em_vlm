# Rebuild Guide — live-vlm-webui (Emplus / Thor)

> **Note:** This document is superseded by [INSTALL.md](./INSTALL.md) (fresh-device install from Git) and [DEVELOPING.md](./DEVELOPING.md) (the Windows dev loop). It's kept for reference; IPs below are examples — the dev scripts now prompt for the device IP.


Complete recovery procedure for getting back up and running after the Nvidia
Thor device has been re-flashed. Follow top to bottom. Each step is
independent; if something's already done, skip ahead.

**Default values used throughout** (change to your environment as needed):

| Setting          | Value                                    |
|------------------|------------------------------------------|
| Thor user        | `ubuntu`                                 |
| Thor IP          | `192.168.213.135`                        |
| Thor project dir | `/home/ubuntu/em_vlm`                  |
| Windows project  | `C:\Users\jerry\OneDrive_Gmail\OneDrive\Claude\VLM\VLM2` |
| Web URL          | `https://192.168.213.135:8090`           |

---

## Part 1 — Thor: from freshly-flashed to network reachable

These steps run on Thor with a monitor + keyboard attached (no SSH yet).

### 1.1 Boot, finish Ubuntu first-run setup

Set a password for the `ubuntu` user. Connect to your WiFi/Ethernet from
the Ubuntu setup wizard.

### 1.2 Confirm Thor is on the LAN

Open a terminal on Thor:

```bash
ip -4 addr show | grep inet
```

Note the IP (e.g. `192.168.213.135`). It must be on the same subnet as
your Windows PC.

### 1.3 Enable SSH + install baseline tools

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y \
    openssh-server \
    curl wget git ca-certificates \
    build-essential cmake pkg-config \
    python3 python3-pip python3-dev python3-venv python3-full \
    htop nano vim \
    net-tools iproute2 iputils-ping \
    rsync unzip
sudo systemctl enable --now ssh
```

Verify SSH:

```bash
ss -tlnp | grep :22
```

Should show sshd listening on port 22.

### 1.4 (Optional) Install Firefox for local testing

If you want to open the WebUI directly on Thor (via attached display):

```bash
sudo apt install -y firefox
```

---

## Part 2 — Windows: confirm you can reach Thor

From PowerShell on your Windows PC:

```powershell
ping 192.168.213.135
ssh ubuntu@192.168.213.135
```

If ping works but SSH fails, check that Thor's `ufw` isn't blocking port 22
(`sudo ufw allow 22` on Thor). Type `exit` to leave SSH.

### Recommended: passwordless SSH (saves typing the password 100 times/day)

In Windows PowerShell:

```powershell
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519 -N '""'
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh ubuntu@192.168.213.135 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
ssh ubuntu@192.168.213.135 "echo OK"
```

The last line should print `OK` with no password prompt.

---

## Part 3 — Thor: install Ollama and a vision model

SSH into Thor (`ssh ubuntu@192.168.213.135`), then:

### 3.1 Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Confirm it's running:

```bash
ollama list
```

### 3.2 Reduce the default context size

The default 256K context blows up the KV cache and crashes Qwen2.5VL.
Cap it to 8K:

```bash
sudo systemctl edit ollama
```

In the editor, paste:

```
[Service]
Environment="OLLAMA_NUM_CTX=8192"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
```

Save. Then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### 3.3 Pull at least one vision model

```bash
ollama pull qwen2.5vl:3b
# or:
ollama pull gemma3:4b
```

### 3.4 Confirm GPU usage

```bash
ollama run qwen2.5vl:3b "hello" &
sleep 5
ollama ps
```

The `PROCESSOR` column should say `100% GPU`. Stop with `pkill ollama` if
the run hangs (it's fine, just confirms the model loaded).

---

## Part 4 — Thor: install Python prereqs

Still SSH'd in:

```bash
sudo apt install -y python3-venv python3-full \
    libavformat-dev libavcodec-dev libavdevice-dev libavutil-dev \
    libswscale-dev libswresample-dev libavfilter-dev \
    libopus-dev libvpx-dev pkg-config libsrtp2-dev
```

### Install jetson-stats so the GPU/VRAM bars work in the UI

```bash
sudo pip install jetson-stats --break-system-packages
sudo systemctl restart jtop.service
```

---

## Part 5 — Push the project to Thor for the first time

From Windows PowerShell:

```powershell
cd C:\Users\jerry\OneDrive_Gmail\OneDrive\Claude\VLM\VLM2
ssh ubuntu@192.168.213.135 "mkdir -p /home/ubuntu/em_vlm"
.\push
```

`.\push` runs `scp` for each top-level item (`src`, `bin`, `start`,
`pyproject.toml`, `requirements.txt`, `MANIFEST.in`, `README.md`,
`LICENSE`, `NOTICE.txt`). It also chmods `start`, `bin/em_vlm`, and
`bin/*.sh` to executable.

---

## Part 6 — Thor: create the venv and install the package

SSH in, then:

```bash
cd /home/ubuntu/em_vlm
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e .
pip install jetson-stats
```

The `pip install -e .` step takes a few minutes (compiles aiortc, PyAV
on ARM64). Lots of compiler output is normal.

Verify:

```bash
python -c "from live_vlm_webui import local_file_track; print('OK')"
```

---

## Part 7 — Thor: install the `em_vlm` CLI wrapper

```bash
bash /home/ubuntu/em_vlm/bin/install_em_vlm.sh
source ~/.bashrc
em_vlm status      # should say "not running"
```

If `em_vlm: command not found` after `source ~/.bashrc`, your
`~/.local/bin` isn't on PATH — re-run the install script; it appends
the PATH line to `~/.bashrc` automatically.

---

## Part 8 — First run

### From Thor (the recommended way)

```bash
em_vlm          # foreground, Ctrl+C to stop
em_vlm bg       # background, logs to /tmp/vlm.log
em_vlm stop     # kill it
em_vlm restart  # stop + bg
em_vlm status   # is it running?
em_vlm log      # tail /tmp/vlm.log
```

### From your Windows PowerShell

```powershell
.\push           # push source files (no restart)
.\start          # SSH + run server in foreground; you see live logs
.\restart        # restart server in background, tail recent log lines
```

Open `https://192.168.213.135:8090` in your browser. Accept the
self-signed certificate warning.

---

## Part 9 — Daily workflow

1. **Edit** files locally in `C:\Users\...\VLM\VLM2\` (OneDrive folder).
2. **Push** to Thor:
   ```powershell
   .\push
   ```
3. **Restart** the server on Thor — pick one:
   - From Windows: `.\start` (foreground, see logs) or `.\restart` (background)
   - From Thor (SSH): `em_vlm restart`
4. **Test**: refresh the browser. **Ctrl+Shift+R** for a hard refresh
   when CSS/JS changes don't appear.

---

## Part 10 — Troubleshooting

| Symptom                                          | Fix |
|--------------------------------------------------|-----|
| `em_vlm: command not found`                        | `source ~/.bashrc` or `bash bin/install_em_vlm.sh` again |
| `externally-managed-environment` on pip          | You forgot `source .venv/bin/activate` |
| Server exits silently when started over SSH      | Already fixed via `setsid` in `push.ps1` and `em_vlm bg` |
| "Permission denied" during scp                   | `push.ps1` now `chmod -R u+rwX` first; if it persists, the file in question is owned by a different user — `sudo chown -R ubuntu:ubuntu /home/ubuntu/em_vlm` |
| Browser shows "Connection insecure"              | Accept the self-signed cert (one-time per browser) |
| GPU%  stuck at 22%                               | Idle frequency proxy. Will rise during VLM inference |
| GPU% stays 0 during inference                    | `jetson-stats` not installed in the venv; `pip install jetson-stats` while venv is active |
| `panic: failed to sample token` (Ollama)         | Context too large. Run the step 3.2 systemd edit and restart Ollama |
| "VLM stops responding" (long hang)               | Likely Ollama queue backed up. Reduce cadence rate; backpressure guard should now skip rather than queue |
| Video tab: "file not found"                      | Path is on Thor, not Windows. `ls -la /path/on/thor` to verify |
| Image tab folder slideshow doesn't advance       | Set "Hold each image (seconds)" before starting; can't change mid-stream |
| Browse button does nothing                       | Hard refresh (Ctrl+Shift+R). If still broken, view-source and grep for `browseFor` — should appear |

---

## Part 11 — Re-deploy after a Thor re-flash

If Thor is wiped completely, the recovery path is just the same as
above, in order:

1. Part 1 (boot + network)
2. Part 2 (SSH key from Windows)
3. Part 3 (Ollama + reduced context + at least one vision model)
4. Part 4 (apt prereqs + jetson-stats)
5. Part 5 (`.\push` from Windows)
6. Part 6 (venv + `pip install -e .`)
7. Part 7 (install `em_vlm`)
8. Part 8 (`em_vlm bg`)

Total time on a fresh Thor: roughly 30–45 minutes, most of which is
`pip install -e .` and `ollama pull` downloads.
