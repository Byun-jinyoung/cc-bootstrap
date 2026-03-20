#!/bin/bash
# cc-bootstrap: AI development environment bootstrap
# Usage:
#   git clone https://github.com/Byun-jinyoung/cc-bootstrap.git ~/.cc-bootstrap
#   cd ~/.cc-bootstrap && ./setup.sh sync
#
# Subcommands:
#   sync      — Create/update symlinks from runtime dirs to this repo
#   doctor    — Check dependencies (system packages, Python libs, CLIs)
#   validate  — Validate skill frontmatter
#   update    — git pull → validate → sync → doctor
#   install   — Legacy copy-based install (environments where symlinks don't work)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CODEX_DIR="$HOME/.codex"
GEMINI_DIR="$HOME/.gemini"
WARNINGS=0
ERRORS=0
SUBCMD="${1:-sync}"

make_link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then rm "$dst"
  elif [ -e "$dst" ]; then mv "$dst" "${dst}.bak.$(date +%s)"; echo "    [BACKUP] $dst"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "    [LINK] $(basename "$dst") → $src"
}

cmd_sync() {
  echo "=== cc-bootstrap sync ==="
  echo ""
  # Dependencies
  for cmd in git node npm python3; do
    command -v $cmd &>/dev/null || { echo "[FAIL] $cmd not found"; ERRORS=$((ERRORS+1)); }
  done
  [ $ERRORS -gt 0 ] && echo "FATAL: missing deps" && exit 1

  # Claude commands
  echo "[1] Claude commands"
  mkdir -p "$CONFIG_DIR/commands"
  for f in "$SCRIPT_DIR/runtimes/claude/commands/"*.md; do
    [ -f "$f" ] && make_link "$f" "$CONFIG_DIR/commands/$(basename "$f")"
  done

  # Claude hooks
  if ls "$SCRIPT_DIR/runtimes/claude/hooks/"* &>/dev/null 2>&1; then
    echo "[2] Claude hooks"
    mkdir -p "$CONFIG_DIR/hooks"
    for f in "$SCRIPT_DIR/runtimes/claude/hooks/"*; do
      [ -f "$f" ] && make_link "$f" "$CONFIG_DIR/hooks/$(basename "$f")"
    done
  fi

  # Codex
  echo "[3] Codex"
  mkdir -p "$CODEX_DIR"
  [ -f "$SCRIPT_DIR/runtimes/codex/instructions.md" ] && \
    make_link "$SCRIPT_DIR/runtimes/codex/instructions.md" "$CODEX_DIR/instructions.md"

  # Gemini
  echo "[4] Gemini"
  mkdir -p "$GEMINI_DIR"
  [ -f "$SCRIPT_DIR/runtimes/gemini/GEMINI.md" ] && \
    make_link "$SCRIPT_DIR/runtimes/gemini/GEMINI.md" "$GEMINI_DIR/GEMINI.md"

  # Shared skills (from registry.yaml)
  echo "[5] Shared skills"
  if [ -f "$SCRIPT_DIR/skills/registry.yaml" ] && command -v python3 &>/dev/null; then
    python3 << PYEOF
import sys, os
try:
    import yaml
except ImportError:
    print("    [WARN] PyYAML missing. pip install pyyaml")
    sys.exit(0)
with open("$SCRIPT_DIR/skills/registry.yaml") as f:
    reg = yaml.safe_load(f)
dirs = {"claude": "$CONFIG_DIR/skills", "codex": "$CODEX_DIR/skills", "gemini": "$GEMINI_DIR/skills"}
for name, info in reg.items():
    for rt in info.get("runtimes", []):
        if rt not in dirs: continue
        src = os.path.join("$SCRIPT_DIR", info["path"], rt)
        if not os.path.exists(src): src = os.path.join("$SCRIPT_DIR", info["path"])
        dst = os.path.join(dirs[rt], name)
        os.makedirs(dirs[rt], exist_ok=True)
        if os.path.islink(dst): os.remove(dst)
        elif os.path.exists(dst): os.rename(dst, dst+".bak")
        os.symlink(src, dst)
        print(f"    [LINK] {rt}/{name} → {src}")
PYEOF
  fi

  # Statusline
  echo "[6] Statusline"
  if [ -f "$SCRIPT_DIR/ui/statusline/my-statusline.mjs" ]; then
    mkdir -p "$CONFIG_DIR/hud"
    make_link "$SCRIPT_DIR/ui/statusline/my-statusline.mjs" "$CONFIG_DIR/hud/my-statusline.mjs"
  fi

  # External tools
  echo "[7] External tools"
  # codex-gemini-mcp
  if command -v codex-mcp &>/dev/null; then
    echo "    [OK] codex-mcp installed"
  else
    echo "    Installing codex-gemini-mcp fork..."
    curl -sL https://raw.githubusercontent.com/Byun-jinyoung/codex-gemini-mcp/main/install.sh | bash
  fi
  # gemini-swarm
  if command -v gemini &>/dev/null; then
    if gemini --list-extensions 2>&1 | grep -q "gemini-swarm"; then
      echo "    [OK] gemini-swarm installed"
    else
      gemini extensions install https://github.com/tmdgusya/gemini-swarm --consent 2>&1 | tail -1
    fi
  fi
  # OMC patches
  [ -f "$SCRIPT_DIR/patches/omc/omc-render-model-first.sh" ] && \
    bash "$SCRIPT_DIR/patches/omc/omc-render-model-first.sh" 2>&1 | sed 's/^/    /'

  echo ""
  echo "=== sync complete. Restart Claude Code to apply. ==="
}

cmd_doctor() {
  echo "=== cc-bootstrap doctor ==="
  for cmd in git node npm python3 uv claude codex gemini; do
    if command -v $cmd &>/dev/null; then echo "  [OK] $cmd"
    else echo "  [MISS] $cmd"; WARNINGS=$((WARNINGS+1)); fi
  done
  echo ""
  echo "[ Symlinks ]"
  for f in "$CONFIG_DIR/commands/analyze-paper.md" "$CONFIG_DIR/commands/update-feeds.md" \
    "$CODEX_DIR/instructions.md" "$GEMINI_DIR/GEMINI.md"; do
    if [ -L "$f" ] || [ -f "$f" ]; then echo "  [OK] $(basename "$f")"
    else echo "  [MISS] $f"; WARNINGS=$((WARNINGS+1)); fi
  done
  [ $WARNINGS -gt 0 ] && echo "  $WARNINGS item(s) missing." || echo "  All checks passed."
}

cmd_validate() {
  echo "=== cc-bootstrap validate ==="
  for skill_dir in "$SCRIPT_DIR/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"
    found=false
    for sub in "$skill_dir"*/SKILL.md; do [ -f "$sub" ] && found=true && break; done
    $found && echo "  [OK] $name" || echo "  [FAIL] $name: no SKILL.md"
  done
  for f in "$SCRIPT_DIR/runtimes/claude/commands/"*.md; do
    [ -f "$f" ] || continue
    head -5 "$f" | grep -q "description:" && echo "  [OK] $(basename "$f")" || echo "  [WARN] $(basename "$f"): no description"
  done
}

cmd_update() {
  echo "=== cc-bootstrap update ==="
  echo "[1/4] git pull"
  git -C "$SCRIPT_DIR" pull --ff-only 2>&1 | sed 's/^/  /'
  echo "[2/4] validate" && cmd_validate
  echo "[3/4] sync" && cmd_sync
  echo "[4/4] doctor" && cmd_doctor
}

cmd_install() {
  echo "=== cc-bootstrap install (legacy copy mode) ==="
  mkdir -p "$CONFIG_DIR/commands" "$CONFIG_DIR/hud" "$CODEX_DIR" "$GEMINI_DIR"
  cp "$SCRIPT_DIR/runtimes/claude/commands/"*.md "$CONFIG_DIR/commands/" 2>/dev/null || true
  cp "$SCRIPT_DIR/runtimes/codex/instructions.md" "$CODEX_DIR/" 2>/dev/null || true
  cp "$SCRIPT_DIR/runtimes/gemini/GEMINI.md" "$GEMINI_DIR/" 2>/dev/null || true
  cp "$SCRIPT_DIR/ui/statusline/my-statusline.mjs" "$CONFIG_DIR/hud/" 2>/dev/null || true
  for rt in codex gemini; do
    for sd in "$SCRIPT_DIR/skills/"*/; do
      [ -d "$sd/$rt" ] && mkdir -p "$HOME/.$rt/skills/$(basename "$sd")" && \
        cp "$sd/$rt/"* "$HOME/.$rt/skills/$(basename "$sd")/" 2>/dev/null
    done
  done
  echo "  Legacy install complete."
}

case "$SUBCMD" in
  sync) cmd_sync ;; doctor) cmd_doctor ;; validate) cmd_validate ;;
  update) cmd_update ;; install) cmd_install ;;
  *) echo "Usage: ./setup.sh {sync|doctor|validate|update|install}"; exit 1 ;;
esac
