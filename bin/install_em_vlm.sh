#!/bin/bash
# Install the em_vlm CLI wrapper into ~/.local/bin.
# Run once on Thor after the project files are in place.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.local/bin/em_vlm"

mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/em_vlm" "$TARGET"
chmod +x "$TARGET"

# Bake the real project path (parent of this bin/ dir) into the installed copy
# so the global 'em_vlm' command controls THIS clone.
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# Replace ONLY the assignment line, not the sentinel in the comparison below it.
sed -i "s#^PROJECT=\"__VLM_PROJECT__\"#PROJECT=\"${PROJECT_DIR}\"#" "$TARGET"
echo "Installed: $TARGET  (project: $PROJECT_DIR)"

# Ensure ~/.local/bin is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin"; then
    echo ""
    echo "Note: \$HOME/.local/bin is not in your PATH yet."
    echo "Adding to ~/.bashrc so 'em_vlm' works from any shell..."
    if ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo "Added. Run 'source ~/.bashrc' or open a new shell."
    fi
fi

echo ""
echo "Try it:  em_vlm status"
