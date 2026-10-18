# Emplus VLM WebUI (em_vlm)

A web interface for real-time Vision Language Model (VLM) analysis on NVIDIA
Jetson devices. Point it at a webcam, an RTSP IP camera, or local images and
videos, and a local Ollama vision model describes what it sees.

This is Emplus's modified version of NVIDIA's
[live-vlm-webui](https://github.com/nvidia-ai-iot/live-vlm-webui).
**Install it with the steps below, not with NVIDIA's pip or Docker
instructions.** NVIDIA's original README is kept in
[README.nvidia.md](./README.nvidia.md) for reference.

---

## Install

On the Jetson itself (monitor and keyboard, or SSH):

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/jerryzhang728/em_vlm.git
cd em_vlm
./install.sh
source ~/.bashrc
```

The installer asks for your sudo password once. Allow 30–45 minutes on a
fresh device: it downloads Ollama, two vision models (about 6–7 GB), and
compiles Python packages. It is safe to re-run.

Full details, install options and troubleshooting: **[INSTALL.md](./INSTALL.md)**.

## Run

```bash
em_vlm bg        # start in background (log: /tmp/vlm.log)
em_vlm           # start in foreground (Ctrl+C to stop)
em_vlm stop      # stop
em_vlm restart   # restart
em_vlm status    # is it running?
em_vlm log       # follow the log
```

Then open **`https://<device-ip>:8090`** in a browser (find the IP with
`hostname -I`) and accept the self-signed certificate warning once.

## Update

```bash
cd ~/em_vlm
git pull
.venv/bin/pip install -e . --quiet   # only if dependencies changed
em_vlm restart
```

---

## What's different from NVIDIA's version

- **Local file sources**: a single image, a folder of images (slideshow), or a
  video file, chosen with a built-in file browser
- **One-command install** for Jetson (`install.sh`) and the `em_vlm` command
- **Jetson GPU/VRAM stats** that work on JetPack 6.2 (Orin) and JetPack 7 (Thor)
- **gemma3:4b** as the default model; text-only models are greyed out in the
  model list
- Ollama context capped at 8K to avoid out-of-memory crashes
- Emplus branding

## Supported devices

| Device | JetPack | Python |
|---|---|---|
| Jetson Orin | 6.2 | 3.10 |
| Jetson Thor | 7.0 | 3.12 |

## Other docs

- [INSTALL.md](./INSTALL.md): full install guide
- [DEVELOPING.md](./DEVELOPING.md): the author's Windows-to-device dev loop
- [CHANGELOG.md](./CHANGELOG.md)

## License

Apache 2.0. Based on live-vlm-webui, Copyright (c) 2025 NVIDIA CORPORATION &
AFFILIATES. See [LICENSE](./LICENSE) and [NOTICE.txt](./NOTICE.txt).
