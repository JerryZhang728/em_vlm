# Publishing your fork to GitHub

These steps push your modified `VLM2/` codebase up to a repo under your own
GitHub account, so other Jetson devices can install it with a single
`curl | bash` command.

Honest note: I cannot push to your GitHub account from my sandbox — you have
to run these git commands on your Windows PC (or on Thor). One-time setup,
then everyday updates are a single `git push`.

---

## One-time: create the repo on GitHub

1. Go to https://github.com/new (log in as **jerryzhang728** if not already)
2. Repository name: `em_vlm`  (or whatever name you want — adjust install.sh
   accordingly)
3. **Public** (required for `curl install.sh | bash` to work without auth)
4. **Don't** initialize with README/LICENSE/.gitignore (we already have them)
5. Click **Create repository**

GitHub will show you a URL like:
```
https://github.com/jerryzhang728/em_vlm.git
```

## One-time: push your current VLM2/ to GitHub

In PowerShell on your Windows PC:

```powershell
cd C:\Users\jerry\OneDrive_Gmail\OneDrive\Claude\VLM\VLM2

# Initialize a git repo (if not already a repo)
git init
git branch -M main

# Tell git who you are (first time on this PC only)
git config user.name  "jerryzhang728"
git config user.email "jerryzhang728@gmail.com"

# Add the GitHub remote
git remote add origin https://github.com/jerryzhang728/em_vlm.git

# Stage everything except heavy/transient junk
git add .
git status               # take a look at what's staged

# First commit + push
git commit -m "Initial Emplus fork of live-vlm-webui v0.4.0"
git push -u origin main
```

GitHub will ask for credentials. **Don't use your account password** — use a
[Personal Access Token](https://github.com/settings/tokens/new):

- Click "Generate new token (classic)"
- Scopes: tick `repo`
- Copy the token, paste it as the password when git asks

Windows Credential Manager will remember it for future pushes.

## Recommended: a `.gitignore` to keep noise out

Before the first commit, create `.gitignore` in VLM2/:

```
.venv/
__pycache__/
*.pyc
*.pyo
*.log
src/live_vlm_webui.egg-info/
build/
dist/
.vscode/
.idea/
```

(The upstream `.gitignore` already covers most of this, just confirm it's
intact.)

## Everyday update flow

After you've edited code:

```powershell
cd C:\Users\jerry\OneDrive_Gmail\OneDrive\Claude\VLM\VLM2
git add .
git commit -m "describe what you changed"
git push
```

---

## Now the one-shot installer becomes real

Once your repo is public at `https://github.com/jerryzhang728/em_vlm`, any
fresh Jetson can install everything in one command:

```bash
curl -fsSL https://raw.githubusercontent.com/jerryzhang728/em_vlm/main/install.sh | bash
```

That single line does (idempotently):

1. apt update + installs build tools, Python venv, libav* dev libs, ssh, git, ...
2. Installs Ollama
3. Caps Ollama context to 8192 (avoids the Qwen2.5VL panic we hit)
4. Pulls `qwen2.5vl:3b`
5. Installs `jetson-stats` (for GPU/VRAM telemetry)
6. Clones `https://github.com/jerryzhang728/em_vlm.git` into `~/em_vlm`
7. Creates `.venv`, runs `pip install -e .`
8. Installs the `em_vlm` CLI wrapper into `~/.local/bin/em_vlm`
9. Makes the helper scripts executable

After it finishes, the user types `em_vlm bg` and the WebUI is live at
`https://<device-ip>:8090`.

## Flags the installer respects

Set as env vars on the same command line:

```bash
# Use Gemma instead of Qwen
VLM_MODEL=gemma3:4b curl -fsSL https://raw.githubusercontent.com/jerryzhang728/em_vlm/main/install.sh | bash

# Install to a different path
VLM_PROJECT=/opt/em_vlm curl -fsSL ... | bash

# Auto-start the server when done
START_AFTER=1 curl -fsSL ... | bash

# Skip Ollama (already configured)
SKIP_OLLAMA=1 curl -fsSL ... | bash
```

---

## If you ever want to keep some files private

If part of your code shouldn't be public (license keys, internal-only
configs), keep the public repo bare and push private stuff via a separate
private repo or a sync mechanism (rsync from your laptop). Apache 2.0 only
requires you publish what you *distribute* — it doesn't force you to
publish modifications you keep in-house.

For your current Emplus demo there's nothing sensitive — public is fine.

---

## Versioning + release tags (optional polish)

When you have a known-good state worth marking:

```powershell
git tag -a v1.0-emplus -m "First Emplus-branded release"
git push origin v1.0-emplus
```

Other Jetson devices can then install a specific pinned version:

```bash
VLM_BRANCH=v1.0-emplus curl -fsSL https://raw.githubusercontent.com/jerryzhang728/em_vlm/v1.0-emplus/install.sh | bash
```
