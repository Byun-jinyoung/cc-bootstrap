#!/bin/bash
# cc-bootstrap: One-command Claude Code environment setup
# Usage: git clone https://github.com/Byun-jinyoung/cc-bootstrap.git && cd cc-bootstrap && bash setup.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ERRORS=0
WARNINGS=0

echo "=== cc-bootstrap: Claude Code Environment Setup ==="
echo ""

# ============================================================
# Phase 1: Dependency Check
# ============================================================
echo "[ Phase 1 ] Dependency check"
echo "------------------------------------------------------------"

# Required
for cmd in git node npm python3; do
  if command -v $cmd &>/dev/null; then
    echo "  [OK] $cmd: $(command -v $cmd)"
  else
    echo "  [FAIL] $cmd: not found"
    ERRORS=$((ERRORS + 1))
  fi
done

# Node version
NODE_VER=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)
if [ -n "$NODE_VER" ] && [ "$NODE_VER" -ge 20 ]; then
  echo "  [OK] node version: $(node -v)"
else
  echo "  [FAIL] node >= 20 required (found: $(node -v 2>/dev/null || echo 'none'))"
  ERRORS=$((ERRORS + 1))
fi

# Optional
for cmd in codex gemini claude; do
  if command -v $cmd &>/dev/null; then
    echo "  [OK] $cmd: $(command -v $cmd)"
  else
    echo "  [WARN] $cmd: not found (optional)"
    WARNINGS=$((WARNINGS + 1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "FATAL: $ERRORS required dependency missing. Fix and re-run."
  exit 1
fi
echo ""

# ============================================================
# Phase 2: Install Components
# ============================================================
echo "[ Phase 2 ] Install components"
echo "------------------------------------------------------------"

# [1] Codex global instructions
echo "  [1/7] Codex instructions..."
mkdir -p "$HOME/.codex"
cp "$SCRIPT_DIR/codex/instructions.md" "$HOME/.codex/instructions.md"

# [2] Gemini global instructions
echo "  [2/7] Gemini instructions..."
mkdir -p "$HOME/.gemini"
cp "$SCRIPT_DIR/gemini/GEMINI.md" "$HOME/.gemini/GEMINI.md"

# [3] Claude Code skills
echo "  [3/7] Skills..."
mkdir -p "$CONFIG_DIR/commands"
cp "$SCRIPT_DIR/claude/commands/"*.md "$CONFIG_DIR/commands/" 2>/dev/null || true

# [4] Custom statusline
echo "  [4/7] Custom statusline..."
mkdir -p "$CONFIG_DIR/hud"
cp "$SCRIPT_DIR/hud/my-statusline.mjs" "$CONFIG_DIR/hud/my-statusline.mjs"
chmod +x "$CONFIG_DIR/hud/my-statusline.mjs"
if [ -f "$CONFIG_DIR/settings.json" ]; then
  python3 -c "
import json
with open('$CONFIG_DIR/settings.json') as f:
    d = json.load(f)
d['statusLine'] = {'type': 'command', 'command': 'node \$HOME/.claude/hud/my-statusline.mjs'}
with open('$CONFIG_DIR/settings.json', 'w') as f:
    json.dump(d, f, indent=2)
"
else
  echo '{"statusLine":{"type":"command","command":"node $HOME/.claude/hud/my-statusline.mjs"}}' > "$CONFIG_DIR/settings.json"
fi

# [5] codex-gemini-mcp fork
echo "  [5/7] codex-gemini-mcp (fork)..."
FORK_INSTALLED=false
if command -v codex-mcp &>/dev/null; then
  for p in \
    "$(npm prefix -g 2>/dev/null)/lib/node_modules/@donghae0414/codex-gemini-mcp/dist" \
    "/usr/local/lib/node_modules/@donghae0414/codex-gemini-mcp/dist" \
    "/usr/lib/node_modules/@donghae0414/codex-gemini-mcp/dist"; do
    if grep -q "session_id" "$p/tools/schema.js" 2>/dev/null; then
      FORK_INSTALLED=true
      break
    fi
  done
fi
if [ "$FORK_INSTALLED" = true ]; then
  echo "         Fork already installed"
else
  echo "         Installing fork..."
  curl -sL https://raw.githubusercontent.com/Byun-jinyoung/codex-gemini-mcp/main/install.sh | bash
fi

# [6] Gemini swarm extension
echo "  [6/7] Gemini swarm extension..."
if command -v gemini &>/dev/null; then
  if gemini --list-extensions 2>&1 | grep -q "gemini-swarm"; then
    echo "         Already installed"
  else
    gemini extensions install https://github.com/tmdgusya/gemini-swarm --consent 2>&1 | tail -1
  fi
else
  echo "         Skipped (Gemini CLI not found)"
fi

# [7] OMC patches
echo "  [7/7] OMC patches..."
if [ -f "$SCRIPT_DIR/patches/omc-render-model-first.sh" ]; then
  bash "$SCRIPT_DIR/patches/omc-render-model-first.sh" 2>&1 | sed 's/^/         /'
else
  echo "         No patches to apply"
fi
echo ""

# ============================================================
# Phase 3: Integrity Verification
# ============================================================
echo "[ Phase 3 ] Integrity verification"
echo "------------------------------------------------------------"
VERIFY_ERRORS=0

# [1] Config files exist
for check in \
  "$HOME/.codex/instructions.md:Codex instructions" \
  "$HOME/.gemini/GEMINI.md:Gemini instructions" \
  "$CONFIG_DIR/commands/gemini-swarm.md:gemini-swarm skill" \
  "$CONFIG_DIR/hud/my-statusline.mjs:Custom statusline"; do
  FILE="${check%%:*}"
  LABEL="${check##*:}"
  if [ -f "$FILE" ]; then
    echo "  [OK] $LABEL"
  else
    echo "  [FAIL] $LABEL: $FILE not found"
    VERIFY_ERRORS=$((VERIFY_ERRORS + 1))
  fi
done

# [2] statusLine configured
if [ -f "$CONFIG_DIR/settings.json" ]; then
  if grep -q "my-statusline.mjs" "$CONFIG_DIR/settings.json" 2>/dev/null; then
    echo "  [OK] statusLine -> my-statusline.mjs"
  else
    echo "  [FAIL] statusLine not pointing to my-statusline.mjs"
    VERIFY_ERRORS=$((VERIFY_ERRORS + 1))
  fi
fi

# [3] codex-gemini-mcp fork features
if command -v codex-mcp &>/dev/null; then
  FOUND_PATH=""
  for p in \
    "$(npm prefix -g 2>/dev/null)/lib/node_modules/@donghae0414/codex-gemini-mcp/dist" \
    "/usr/local/lib/node_modules/@donghae0414/codex-gemini-mcp/dist" \
    "/usr/lib/node_modules/@donghae0414/codex-gemini-mcp/dist"; do
    if [ -d "$p" ] 2>/dev/null; then
      FOUND_PATH="$p"
      break
    fi
  done

  if [ -n "$FOUND_PATH" ]; then
    for check in \
      "$FOUND_PATH/tools/schema.js:session_id:session_id param" \
      "$FOUND_PATH/providers/gemini.js:\"-y\":gemini -y flag" \
      "$FOUND_PATH/providers/codex.js:\"resume\":codex resume"; do
      FILE="${check%%:*}"
      REST="${check#*:}"
      PATTERN="${REST%%:*}"
      LABEL="${REST##*:}"
      if grep -q "$PATTERN" "$FILE" 2>/dev/null; then
        echo "  [OK] $LABEL"
      else
        echo "  [FAIL] $LABEL"
        VERIFY_ERRORS=$((VERIFY_ERRORS + 1))
      fi
    done
  else
    echo "  [WARN] codex-gemini-mcp dist not found for verification"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo "  [WARN] codex-mcp not on PATH"
  WARNINGS=$((WARNINGS + 1))
fi

# [4] Gemini swarm
if command -v gemini &>/dev/null; then
  if gemini --list-extensions 2>&1 | grep -q "gemini-swarm"; then
    echo "  [OK] gemini-swarm extension"
  else
    echo "  [WARN] gemini-swarm not installed"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

echo ""

# ============================================================
# Summary
# ============================================================
echo "============================================================"
if [ $VERIFY_ERRORS -eq 0 ]; then
  echo "  cc-bootstrap COMPLETE — all checks passed"
else
  echo "  cc-bootstrap COMPLETE — $VERIFY_ERRORS error(s)"
fi
if [ $WARNINGS -gt 0 ]; then
  echo "  $WARNINGS warning(s) (optional components)"
fi
echo ""
echo "  Installed:"
echo "    Codex instructions:  ~/.codex/instructions.md"
echo "    Gemini instructions: ~/.gemini/GEMINI.md"
echo "    Skills:              $CONFIG_DIR/commands/"
echo "    Statusline:          $CONFIG_DIR/hud/my-statusline.mjs"
echo "    codex-gemini-mcp:    $(which codex-mcp 2>/dev/null || echo 'not installed')"
echo "    gemini-mcp:          $(which gemini-mcp 2>/dev/null || echo 'not installed')"
echo ""
echo "  Restart Claude Code to apply all changes."
echo "============================================================"

if [ $VERIFY_ERRORS -gt 0 ]; then
  exit 1
fi
