#!/bin/bash
# cc-bootstrap: One-command Claude Code environment setup
# Usage: git clone https://github.com/Byun-jinyoung/cc-bootstrap.git && cd cc-bootstrap && bash setup.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ERRORS=0

echo "=== cc-bootstrap: Claude Code Environment Setup ==="

# Prerequisites
echo "[1/7] Checking prerequisites..."
for cmd in git node npm; do
  if ! command -v $cmd &>/dev/null; then
    echo "  ERROR: $cmd not found"
    ERRORS=$((ERRORS + 1))
  fi
done
if [ $ERRORS -gt 0 ]; then
  echo "Install missing prerequisites and re-run."
  exit 1
fi
echo "  node $(node -v), npm $(npm -v)"

# Codex global instructions
echo "[2/7] Codex instructions..."
mkdir -p "$HOME/.codex"
cp "$SCRIPT_DIR/codex/instructions.md" "$HOME/.codex/instructions.md"
echo "  -> ~/.codex/instructions.md"

# Gemini global instructions
echo "[3/7] Gemini instructions..."
mkdir -p "$HOME/.gemini"
cp "$SCRIPT_DIR/gemini/GEMINI.md" "$HOME/.gemini/GEMINI.md"
echo "  -> ~/.gemini/GEMINI.md"

# Claude Code skills
echo "[4/7] Skills..."
mkdir -p "$CONFIG_DIR/commands"
cp "$SCRIPT_DIR/claude/commands/"*.md "$CONFIG_DIR/commands/" 2>/dev/null || true
echo "  -> $CONFIG_DIR/commands/"

# Custom statusline
echo "[5/7] Custom statusline..."
mkdir -p "$CONFIG_DIR/hud"
cp "$SCRIPT_DIR/hud/my-statusline.mjs" "$CONFIG_DIR/hud/my-statusline.mjs"
chmod +x "$CONFIG_DIR/hud/my-statusline.mjs"
# Set statusLine in settings.json
if [ -f "$CONFIG_DIR/settings.json" ]; then
  python3 -c "
import json
with open('$CONFIG_DIR/settings.json') as f:
    d = json.load(f)
d['statusLine'] = {'type': 'command', 'command': 'node \$HOME/.claude/hud/my-statusline.mjs'}
with open('$CONFIG_DIR/settings.json', 'w') as f:
    json.dump(d, f, indent=2)
print('  statusLine updated')
"
else
  echo '{"statusLine":{"type":"command","command":"node $HOME/.claude/hud/my-statusline.mjs"}}' > "$CONFIG_DIR/settings.json"
  echo "  settings.json created"
fi

# codex-gemini-mcp fork (session resume + gemini -y)
echo "[6/7] codex-gemini-mcp (fork)..."
if command -v codex-mcp &>/dev/null; then
  # Check if fork version
  INSTALL_PATHS=(
    "$(npm prefix -g 2>/dev/null)/lib/node_modules/@donghae0414/codex-gemini-mcp/dist"
    "/usr/local/lib/node_modules/@donghae0414/codex-gemini-mcp/dist"
    "/usr/lib/node_modules/@donghae0414/codex-gemini-mcp/dist"
  )
  FOUND=false
  for p in "${INSTALL_PATHS[@]}"; do
    if grep -q "session_id" "$p/tools/schema.js" 2>/dev/null; then
      FOUND=true
      echo "  Fork version already installed"
      break
    fi
  done
  if [ "$FOUND" = false ]; then
    echo "  Original version detected. Installing fork..."
    curl -sL https://raw.githubusercontent.com/Byun-jinyoung/codex-gemini-mcp/main/install.sh | bash
  fi
else
  echo "  Not installed. Installing fork..."
  curl -sL https://raw.githubusercontent.com/Byun-jinyoung/codex-gemini-mcp/main/install.sh | bash
fi

# Gemini swarm extension
echo "[7/7] Gemini swarm extension..."
if command -v gemini &>/dev/null; then
  if gemini --list-extensions 2>&1 | grep -q "gemini-swarm"; then
    echo "  gemini-swarm already installed"
  else
    gemini extensions install https://github.com/tmdgusya/gemini-swarm --consent 2>&1 | tail -1
  fi
else
  echo "  Gemini CLI not found. Skip. Install with: npm install -g @google/gemini-cli"
fi

# Apply OMC patches (if OMC is installed)
echo ""
echo "Applying patches..."
if [ -f "$SCRIPT_DIR/patches/omc-render-model-first.sh" ]; then
  bash "$SCRIPT_DIR/patches/omc-render-model-first.sh" 2>&1 | sed 's/^/  /'
fi

# Summary
echo ""
echo "=== cc-bootstrap complete ==="
echo "  Codex instructions:  ~/.codex/instructions.md"
echo "  Gemini instructions: ~/.gemini/GEMINI.md"
echo "  Skills:              $CONFIG_DIR/commands/"
echo "  Statusline:          $CONFIG_DIR/hud/my-statusline.mjs"
echo "  codex-gemini-mcp:    $(which codex-mcp 2>/dev/null || echo 'not found')"
echo ""
echo "Restart Claude Code to apply all changes."
