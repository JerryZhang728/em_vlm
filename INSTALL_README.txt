================================================================
 EMPLUS VLM2 -- INSTALL FROM A FRESH JETSON
================================================================

Total time:   ~15 minutes
Prereqs:      Internet on the Jetson, any laptop with SSH + a browser

----------------------------------------------------------------
 PART A. ON THE JETSON (monitor + keyboard, one time)
----------------------------------------------------------------

1. Boot the device. Finish Ubuntu's first-run wizard. Set the
   `ubuntu` user password. Connect to WiFi or Ethernet.

2. Open a terminal and install SSH:

       sudo apt update
       sudo apt install -y openssh-server
       sudo systemctl enable --now ssh

3. Find this Jetson's IP -- write it down:

       ip -4 addr show | grep inet

   Look for a 192.168.x.y on your LAN interface.

After this you can disconnect the monitor + keyboard. The rest
runs over SSH from any laptop.


----------------------------------------------------------------
 PART B. ON ANY LAPTOP (with SSH + a browser)
----------------------------------------------------------------

SSH clients are built into:
  * macOS Terminal
  * Linux Terminal
  * Windows 10/11 PowerShell or cmd
  * ChromeOS Linux apps

1. SSH into the Jetson:

       ssh ubuntu@<jetson-ip>

   Paste the Jetson password when prompted.

2. Run the one-line installer:

       curl -fsSL https://raw.githubusercontent.com/jerryzhang728/em_vlm/main/install.sh | bash

   Wait ~10-15 min. It will:
     - apt install build tools, libav*, python3-venv, ssh, etc.
     - install Ollama and cap context to 8K (prevents Qwen panics)
     - pull qwen2.5vl:3b
     - install jetson-stats for GPU/VRAM telemetry
     - clone the project into ~/em_vlm
     - create .venv and pip install -e .
     - install the `em_vlm` CLI wrapper into ~/.local/bin

3. After it finishes, reload the shell + start the server:

       source ~/.bashrc
       em_vlm bg

4. On the laptop, open a browser:

       https://<jetson-ip>:8090

   Accept the self-signed certificate warning (one-time).


----------------------------------------------------------------
 PART C. RUNNING THE SERVER (em_vlm CLI)
----------------------------------------------------------------

From any shell on the Jetson:

    em_vlm              # start in foreground (Ctrl+C to stop)
    em_vlm bg           # start in background, logs at /tmp/vlm.log
    em_vlm stop         # kill the server
    em_vlm restart      # stop + bg
    em_vlm status       # is it running?
    em_vlm log          # tail /tmp/vlm.log


----------------------------------------------------------------
 PART D. UPDATING TO A NEWER COMMIT
----------------------------------------------------------------

When the GitHub repo has new commits and you want them on this
Jetson:

    cd ~/em_vlm
    git pull
    .venv/bin/pip install -e . --quiet      # if deps changed
    em_vlm restart


----------------------------------------------------------------
 PART E. OPTIONAL EXTRAS
----------------------------------------------------------------

Passwordless SSH from your laptop (skip future password prompts):

    # On macOS / Linux / WSL:
    ssh-keygen -t ed25519
    ssh-copy-id ubuntu@<jetson-ip>

    # On Windows PowerShell:
    ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519 -N '""'
    type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh ubuntu@<jetson-ip> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

Test stock photos (Pexels API key required, free):

    # On the Jetson:
    cd ~/em_vlm/../Images/stock     # or any location with keywords.json
    export PEXELS_API_KEY="ghp_yourkey_here"
    python3 download_photos.py        # see README in that folder

Change the model used:

    VLM_MODEL=gemma3:4b curl -fsSL https://raw.githubusercontent.com/jerryzhang728/em_vlm/main/install.sh | bash

Skip Ollama (you already have it elsewhere):

    SKIP_OLLAMA=1 curl -fsSL ... | bash

Auto-start server when install finishes:

    START_AFTER=1 curl -fsSL ... | bash


----------------------------------------------------------------
 PART F. TROUBLESHOOTING
----------------------------------------------------------------

| Symptom                              | Fix |
|-------------------------------------|-----|
| `em_vlm: command not found`           | `source ~/.bashrc` once per shell |
| Server exits silently               | `em_vlm log` to see why |
| Browser shows "insecure"            | Accept the self-signed cert |
| GPU bars stuck at 0                 | Ensure jetson-stats is in venv: `cd ~/em_vlm && .venv/bin/pip install jetson-stats` |
| Qwen returns 500 errors             | Context too large -- redo step `OLLAMA_NUM_CTX=8192` (installer does this; check `sudo systemctl show ollama | grep Env`) |
| Image path "not found" in UI        | The path is on the Jetson, not your laptop. Verify with `ls -la /full/path/on/jetson` |


----------------------------------------------------------------
 LICENSE
----------------------------------------------------------------

Apache License 2.0. See LICENSE and NOTICE.txt in this repo.
Based on nvidia-ai-iot/live-vlm-webui (also Apache 2.0).
Modifications by Emplus Technologies.
