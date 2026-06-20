# Installing Live VLM WebUI on an NVIDIA device

This guide sets up the VLM WebUI demo on a freshly-flashed NVIDIA Jetson,
directly from this Git repo. **You run everything on the device itself** — no
second PC required.

Tested on:

- **Jetson Orin** (JetPack 6.2, Python 3.10)
- **Jetson Thor** (JetPack 7.0, Python 3.12)

The same steps work on both; the software auto-detects which board it's on.

---

## 1. Prerequisites on the device

A fresh Jetson needs only Git and network access to start. From a terminal on
the device (monitor + keyboard, or SSH):

```bash
sudo apt update
sudo apt install -y git
```

Make sure the device is online (the installer downloads Ollama, a vision
model, and Python packages).

---

## 2. Clone and install

```bash
git clone https://github.com/jerryzhang728/em_vlm.git
cd em_vlm
./install.sh
```

`install.sh` installs **in-place in the folder you cloned into**, so you can use
any folder name — e.g. clone into `vlm3` to test a new build alongside an
existing one:

```bash
git clone https://github.com/jerryzhang728/em_vlm.git vlm3
cd vlm3
./install.sh
```

The `em_vlm` command will then control whichever clone you installed most
recently. Note the WebUI uses port **8090**, so run one instance at a time.

`install.sh` is **idempotent** — safe to re-run. It will:

1. Install apt build prerequisites (PyAV / aiortc need these).
2. Install **Ollama**, cap its context to 8K (avoids KV-cache crashes), and
   pull both vision models — **gemma3:4b** (default) and **qwen2.5vl:3b**.
3. Install **jetson-stats** so the GPU/VRAM bars work (Jetson only).
4. Create a Python venv and install the project (editable).
5. Install the `em_vlm` CLI helper.

It takes roughly 30–45 minutes on a fresh device, mostly Ollama downloads and
compiling native Python extensions on ARM64.

### Useful install options (environment variables)

```bash
VLM_MODEL=gemma3:4b ./install.sh     # pull a different vision model
START_AFTER=1       ./install.sh     # start the server when done
SKIP_OLLAMA=1       ./install.sh     # Ollama already set up
SKIP_APT=1          ./install.sh     # skip apt (offline / restricted)
```

---

## 3. Run it

```bash
em_vlm bg        # start in background (logs at /tmp/vlm.log)
em_vlm           # start in foreground
em_vlm stop      # stop
em_vlm restart   # restart
em_vlm status    # is it running?
em_vlm log       # tail the log
```

If `em_vlm: command not found`, run `source ~/.bashrc` once (the installer adds
`~/.local/bin` to PATH).

Open the WebUI in a browser:

```
https://<device-ip>:8090
```

Find `<device-ip>` with `hostname -I`. Accept the self-signed certificate
warning (one-time per browser).

---

## 4. Pick a vision model

The WebUI defaults to **gemma3:4b** when it's installed. **You must use a
vision-capable model** — a text-only model (e.g. `qwen3:4b`) will reject images.
Good choices:

```bash
ollama pull gemma3:4b
ollama pull qwen2.5vl:3b
```

The model dropdown greys out text-only models, so if a model is disabled there,
it can't see images.

---

## 5. Troubleshooting

| Symptom | Fix |
|---|---|
| `em_vlm: command not found` | `source ~/.bashrc` |
| `externally-managed-environment` on pip | You're outside the venv; the installer handles this, re-run `./install.sh` |
| GPU/VRAM bars stay empty | `jetson-stats` not active: `sudo systemctl restart jtop.service` |
| `panic: failed to sample token` (Ollama) | Context too large; installer caps it to 8K — re-run, or `sudo systemctl restart ollama` |
| Model gives a `400 ... does not support multimodal` | You picked a text-only model; choose a vision model |
| Browser "connection insecure" | Accept the self-signed cert (one-time) |

To wipe and start over after a re-flash, just repeat from step 1.
