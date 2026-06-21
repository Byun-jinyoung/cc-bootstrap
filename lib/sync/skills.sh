# oh-my-agent-env: sync domain - skills.sh
# Sourced by lib/sync.sh; not standalone.

# [5][6] Shared skills (registry.yaml) + statusline
sync_skills_statusline() {
  # Shared skills (from registry.yaml)
  echo "[5] Shared skills"
  if [ -f "$SCRIPT_DIR/skills/registry.yaml" ] && command -v python3 &>/dev/null; then
    python3 << PYEOF
import sys, os
try:
    import yaml
except ImportError:
    yaml = None

registry_path = "$SCRIPT_DIR/skills/registry.yaml"
if yaml:
    with open(registry_path) as f:
        reg = yaml.safe_load(f)
else:
    print("    [WARN] PyYAML missing. Using minimal registry parser.")
    reg = {}
    current = None
    with open(registry_path) as f:
        for raw in f:
            line = raw.split("#", 1)[0].rstrip()
            if not line:
                continue
            if not line.startswith(" ") and line.endswith(":"):
                current = line[:-1]
                reg[current] = {}
            elif current and line.strip().startswith("path:"):
                reg[current]["path"] = line.split(":", 1)[1].strip()
            elif current and line.strip().startswith("runtimes:"):
                value = line.split(":", 1)[1].strip()
                reg[current]["runtimes"] = [x.strip() for x in value.strip("[]").split(",") if x.strip()]
dirs = {"claude": "$CONFIG_DIR/skills", "codex": "$CODEX_DIR/skills", "agents": "$AGENTS_DIR/skills", "antigravity": "$GEMINI_DIR/skills"}
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

# Prune stale oh-my-agent-env symlinks no longer in the registry, so that
# dropping a runtime from registry.yaml self-cleans on every machine.
# Only oh-my-agent-env-managed symlinks are removed; real dirs / foreign
# links are left untouched.
skills_root = os.path.realpath(os.path.join("$SCRIPT_DIR", "skills"))
desired = {(rt, name) for name, info in reg.items()
           for rt in info.get("runtimes", []) if rt in dirs}
for rt, d in dirs.items():
    if not os.path.isdir(d): continue
    for entry in os.listdir(d):
        p = os.path.join(d, entry)
        if not os.path.islink(p): continue
        if os.path.realpath(p).startswith(skills_root) and (rt, entry) not in desired:
            os.remove(p)
            print(f"    [PRUNE] {rt}/{entry} (stale)")
PYEOF
  fi

  # Statusline
  echo "[6] Statusline"
  if [ -f "$SCRIPT_DIR/ui/statusline/my-statusline.mjs" ]; then
    mkdir -p "$CONFIG_DIR/hud"
    make_link "$SCRIPT_DIR/ui/statusline/my-statusline.mjs" "$CONFIG_DIR/hud/my-statusline.mjs"
  fi
}
