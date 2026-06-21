# oh-my-agent-env: sync domain - core.sh
# Sourced by lib/sync.sh; not standalone.

# [1][2][2b] Claude commands, hooks, rules-enforcement
sync_claude() {
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

  # [2b] Rules-enforcement: compressed-rule file + settings.json hook wiring.
  # rules-core.md is read by inject-core-rules.js at $CONFIG_DIR/rules-core.md.
  if [ -f "$SCRIPT_DIR/runtimes/claude/rules-core.md" ]; then
    make_link "$SCRIPT_DIR/runtimes/claude/rules-core.md" "$CONFIG_DIR/rules-core.md"
  fi
  echo "[2b] Rules-enforcement hooks (settings.json)"
  ensure_rules_enforcement_hooks
}
