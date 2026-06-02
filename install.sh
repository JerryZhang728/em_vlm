#!/usr/bin/env bash
# =============================================================================
# install.sh -- one-shot installer for live-vlm-webui (Emplus fork) on Jetson.
#
# Bootstraps a freshly-flashed Nvidia Jetson (Thor / Orin / etc.) into a
# fully-working VLM WebUI demo. Idempotent -- safe to re-run.
#
# Usage on a brand-new Jetson:
#
#     curl -fsSL https://raw.githubusercontent.com/<YOUR-GH-USER>/vlm2/main/install.sh | bash
#
# Or, after cloning manually:
#
#     bash install.sh
#
# Flags (set via env var):
#     VLM_REPO_URL    git URL to clone (default: this repo)
#     VLM_BRANCH      branch / tag (default: main)
#     VLM_PROJECT     install location (default: $HOME/vlm/vlm2)
#     VLM_MODEL       Ollama model to pull (default: qwen2.5vl:3b)
#     VLM_NUM_CTX     Ollama context cap (default: 8192)
#     SKIP_OLLAMA=1   skip Ollama install (already installed)
#     SKIP_APT=1      skip apt prereqs (e.g. behind firewall)
#     START_AFTER=1   start server in background after install
# =============================================================================

set -euo pipefail

# --- Defaults --------------------------------------------------------------
: "${VLM_REPO_URL:=https://github.com/JerryZhang728/VLM2.git}"
: "${VLM_BRANCH:=main}"
: "${VLM_PROJECT:=$HOME/vlm/vlm2}"
: "${VLM_MODEL:=qwen2.5vl:3b}"
: "${VLM_NUM_CTX:=8192}"
: "${SKIP_OLLAMA:=0}"
: "${SKIP_APT:=0}"
: "${START_AFTER:=0}"

C_OK="\033[1;32m"
C_INFO="\033[1;36m"
C_WARN="\033[1;33m"
C_ERR="\033[1;31m"
C_END="\033[0m"
log()  { echo -e "${C_INFO}==>${C_END} $*"; }
ok()   { echo -e "${C_OK}OK${C_END}  $*"; }
warn() { echo -e "${C_WARN}WARN${C_END} $*"; }
die()  { echo -e "${C_ERR}ERROR${C_END} $*" >&2; exit 1; }

# --- Sanity checks ---------------------------------------------------------
[[ "$(uname)" == "Linux" ]] || die "This installer is for Linux only."
[[ "$EUID" -ne 0 ]] || die "Do NOT run this script as root. Run as the ubuntu user."
command -v sudo >/dev/null || die "sudo is required."

if [[ -f /etc/nv_tegra_release ]]; then
    log "Detected Jetson device:"
    head -1 /etc/nv_tegra_release
elif command -v nvidia-smi >/dev/null 2>&1; then
    log "Detected NVIDIA discrete GPU"
else
    warn "No NVIDIA hardware detected. Continuing anyway."
fi

# --- 1. apt prereqs --------------------------------------------------------
if [[ "$SKIP_APT" != "1" ]]; then
    log "Installing apt prerequisites (will ask for sudo password)"
    sudo apt-get update -qq
    sudo apt-get install -y \
        openssh-server \
        curl wget git ca-certificates \
        build-essential cmake pkg-config \
        python3 python3-pip python3-dev python3-venv python3-full \
        libavformat-dev libavcodec-dev libavdevice-dev libavutil-dev \
        libswscale-dev libswresample-dev libavfilter-dev \
        libopus-dev libvpx-dev libsrtp2-dev \
        net-tools iproute2 iputils-ping rsync unzip htop
    ok "apt prereqs installed"
else
    warn "Skipping apt step (SKIP_APT=1)"
fi

# --- 2. Ollama -------------------------------------------------------------
if [[ "$SKIP_OLLAMA" != "1" ]]; then
    if ! command -v ollama >/dev/null 2>&1; then
        log "Installing Ollama"
        curl -fsSL https://ollama.com/install.sh | sh
    else
        ok "Ollama already installed"
    fi

    # Cap context to keep KV cache sane on smaller GPUs / avoid Qwen panics
    log "Capping Ollama context to ${VLM_NUM_CTX} (drops in /etc/systemd/system/ollama.service.d/)"
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null <<EOF
[Service]
Environment="OLLAMA_NUM_CTX=${VLM_NUM_CTX}"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
EOF
    sudo systemctl daemon-reload
    sudo systemctl restart ollama || true
    sleep 2

    # Pull the model
    if ! ollama list 2>/dev/null | grep -q "^${VLM_MODEL%%:*}"; then
        log "Pulling Ollama model: ${VLM_MODEL} (this may take a few minutes)"
        ollama pull "${VLM_MODEL}"
    else
        ok "Model already present: ${VLM_MODEL}"
    fi
else
    warn "Skipping Ollama install (SKIP_OLLAMA=1)"
fi

# --- 3. jetson-stats (Jetson only) -----------------------------------------
if [[ -f /etc/nv_tegra_release ]]; then
    if ! command -v jtop >/dev/null 2>&1; then
        log "Installing jetson-stats (for GPU/VRAM telemetry)"
        sudo pip3 install --break-system-packages jetson-stats
        sudo systemctl restart jtop.service 2>/dev/null || true
    else
        ok "jetson-stats already installed"
    fi
fi

# --- 4. Clone project ------------------------------------------------------
if [[ ! -d "$VLM_PROJECT/.git" && ! -f "$VLM_PROJECT/pyproject.toml" ]]; then
    log "Cloning ${VLM_REPO_URL} -> ${VLM_PROJECT}"
    mkdir -p "$(dirname "$VLM_PROJECT")"
    git clone --branch "$VLM_BRANCH" --depth 1 "$VLM_REPO_URL" "$VLM_PROJECT"
elif [[ -d "$VLM_PROJECT/.git" ]]; then
    log "Updating existing clone at ${VLM_PROJECT}"
    git -C "$VLM_PROJECT" fetch --depth 1 origin "$VLM_BRANCH"
    git -C "$VLM_PROJECT" checkout "$VLM_BRANCH"
    git -C "$VLM_PROJECT" reset --hard "origin/$VLM_BRANCH"
else
    ok "Project files present at ${VLM_PROJECT} (no git, that's fine)"
fi

# --- 5. venv + editable install --------------------------------------------
cd "$VLM_PROJECT"
if [[ ! -x ".venv/bin/python" ]]; then
    log "Creating Python venv"
    python3 -m venv .venv
fi
log "Installing live-vlm-webui (editable) into venv"
.venv/bin/pip install --upgrade pip --quiet
.venv/bin/pip install -e . --quiet
.venv/bin/pip install jetson-stats --quiet 2>/dev/null || true
ok "Python package installed"

# --- 6. vlm2 CLI wrapper ---------------------------------------------------
if [[ -f "$VLM_PROJECT/bin/install_vlm2.sh" ]]; then
    log "Installing vlm2 CLI wrapper"
    bash "$VLM_PROJECT/bin/install_vlm2.sh"
fi

# --- 7. Make scripts executable --------------------------------------------
chmod +x "$VLM_PROJECT/start" 2>/dev/null || true
chmod +x "$VLM_PROJECT/bin/"*.sh 2>/dev/null || true
chmod +x "$VLM_PROJECT/bin/vlm2" 2>/dev/null || true

# --- 8. Optionally start the server ----------------------------------------
if [[ "$START_AFTER" == "1" ]]; then
    log "Starting server in background"
    if command -v vlm2 >/dev/null 2>&1; then
        vlm2 bg
    else
        cd "$VLM_PROJECT"
        nohup .venv/bin/python -m live_vlm_webui.server >/tmp/vlm.log 2>&1 &
        disown
        sleep 2
        tail -n 20 /tmp/vlm.log || true
    fi
fi

# --- Done ------------------------------------------------------------------
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
cat <<DONE

${C_OK}========================================================${C_END}
${C_OK}  Installation complete${C_END}
${C_OK}========================================================${C_END}

  Project:    ${VLM_PROJECT}
  Venv:       ${VLM_PROJECT}/.venv
  Ollama:     ${VLM_MODEL} (num_ctx=${VLM_NUM_CTX})
  CLI:        vlm2 {start|bg|stop|restart|status|log}

  Start the server:
      vlm2 bg          # background, logs at /tmp/vlm.log
      vlm2             # foreground

  Open in browser:
      https://${IP:-<this-device-ip>}:8090

  Need to re-open terminal first so PATH picks up ~/.local/bin:
      source ~/.bashrc

DONE
