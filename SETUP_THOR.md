# Setting up live-vlm-webui v2 on the Thor device

> **Note:** This document is superseded by [INSTALL.md](./INSTALL.md) (fresh-device install from Git) and [DEVELOPING.md](./DEVELOPING.md) (the Windows dev loop). It's kept for reference; IPs below are examples — the dev scripts now prompt for the device IP.


One-time setup for the Nvidia Thor (Ubuntu 24.04, ARM64, Python 3.12). After
this, iteration is just `.\push_and_restart.ps1` from Windows.

## Prereqs

- Thor on the same LAN as your Windows PC (confirmed: `192.168.213.135`)
- SSH from Windows works (confirmed)
- Ollama running on Thor with at least one vision model
  (`ollama pull gemma3:4b` or `ollama pull qwen2.5vl:3b`)

## One-time install on Thor

**From your Windows PowerShell**, push the project to Thor:

```powershell
cd C:\Users\jerry\OneDrive_Gmail\OneDrive\Claude\VLM\VLM2
ssh ubuntu@192.168.213.135 "mkdir -p /home/ubuntu/em_vlm"
scp -r src pyproject.toml requirements.txt MANIFEST.in README.md LICENSE ubuntu@192.168.213.135:/home/ubuntu/em_vlm/
```

**Then SSH into Thor and install inside a venv** (Ubuntu 24.04 / Python 3.12
blocks system-wide pip install per PEP 668, so a venv is required):

```bash
ssh ubuntu@192.168.213.135

# One-time apt packages (Python venv + system libs PyAV/aiortc need)
sudo apt update
sudo apt install -y \
    python3-venv python3-full \
    libavformat-dev libavcodec-dev libavdevice-dev libavutil-dev \
    libswscale-dev libswresample-dev libavfilter-dev \
    libopus-dev libvpx-dev pkg-config libsrtp2-dev

# Create the project venv (one time)
cd /home/ubuntu/em_vlm
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e .       # editable install -- picks up code edits live
```

The `pip install -e .` step takes a few minutes (compiling C extensions for
aiortc / PyAV on ARM64). Lots of compiler output is normal.

Verify:

```bash
# Still inside the activated venv:
python -c "from live_vlm_webui import local_file_track; print('OK')"
```

Should print `OK`. If you see `ImportError`, a pip dep is missing — re-run
`pip install -e .`.

## Recommended: passwordless SSH

So `push_and_restart.ps1` doesn't ask for a password every iteration:

```powershell
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519 -N '""'
type $env:USERPROFILE\.ssh\id_ed25519.pub | `
    ssh ubuntu@192.168.213.135 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

## Daily dev loop

After the one-time setup above, from Windows PowerShell:

```powershell
cd C:\Users\jerry\OneDrive_Gmail\OneDrive\Claude\VLM\VLM2
.\push_and_restart.ps1
```

That copies the sources to Thor, kills any running server, and starts a fresh
one **inside the venv** (`.venv/bin/python -m live_vlm_webui.server`) with logs
at `/tmp/vlm.log`. The script prints the last 30 lines so you see startup
errors immediately.

Open `https://192.168.213.135:8090` in your browser (accept the self-signed
cert warning).

To tail logs while testing:

```powershell
ssh ubuntu@192.168.213.135 "tail -f /tmp/vlm.log"
```

## What's new in v2 — UI orientation

The Source panel has **four tabs** instead of two:

| Tab | Source | Server module |
|---|---|---|
| **Webcam** | Browser captures, server processes (unchanged from upstream) | (existing) |
| **IP Cam** | RTSP URL, server decodes (unchanged from upstream, renamed) | `rtsp_track.py` |
| **Image** | Single image file *or* folder (slideshow). Auto-detected. | `local_file_track.py` (NEW) |
| **Video** | Local video file, paced to native FPS, loops at EOF | `local_file_track.py` (NEW) |

Below the tabs, **Analysis Cadence** has three modes:

- **Every N frames** — original behavior (default = 30)
- **Every N seconds** — wall-clock interval
- **On scene change** — only fire when content actually changes. Best for
  slideshows where each image is shown for variable durations.

Backpressure protection is automatic: if Ollama is still chewing on the
previous frame, new frames are skipped (instead of piling up and eventually
hanging — which is the emplus failure mode).

## Test files (in your /Images folder)

Copy them to Thor (one time, optional — paths in the UI need to be on Thor):

```powershell
scp -r C:\Users\jerry\OneDrive_Gmail\OneDrive\Claude\VLM\Images ubuntu@192.168.213.135:/home/ubuntu/
```

After that, in the UI:

| Tab | Path to try | What you should see |
|---|---|---|
| Image | `/home/ubuntu/Images/images_sel/fire.jpg` | Single still, VLM analyzes once per interval |
| Image | `/home/ubuntu/Images/images_sel/` | Slideshow — 23 images, holds each per the slider |
| Video | `/home/ubuntu/Images/vlmvideo_15s.mp4` | Slideshow video, 15s per scene |

For the slideshow video, pick **On scene change** for cadence — VLM fires
exactly once per slide, no matter the duration. That's the killer combo.

## Troubleshooting

- **`externally-managed-environment`** — you forgot to activate the venv;
  `source .venv/bin/activate` first.
- **Server won't start, "address already in use"** — `pkill -f live_vlm_webui` on Thor.
- **Browser shows "Connection insecure"** — accept the self-signed cert.
- **VLM never responds** — check Ollama: `ollama list`. Default expects
  Ollama at `http://localhost:11434/v1`.
- **Image / video file "not found"** — paths are on Thor, not Windows. Verify
  the file exists at the path you typed: `ls -la <path>` on Thor.
- **`push_and_restart.ps1` reports `venv not found`** — you haven't done the
  one-time `python3 -m venv .venv && pip install -e .` step above.
