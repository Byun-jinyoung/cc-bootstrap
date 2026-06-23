#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1] shell syntax"
bash -n "$ROOT/setup.sh" "$ROOT/lib/common.sh" "$ROOT/lib/sync.sh" "$ROOT"/lib/sync/*.sh "$ROOT/lib/doctor.sh" "$ROOT"/lib/doctor/*.sh

echo "[2] required sync domains"
for f in \
  "$ROOT/lib/sync/core.sh" \
  "$ROOT/lib/sync/rules.sh" \
  "$ROOT/lib/sync/skills.sh" \
  "$ROOT/lib/sync/external-tools.sh" \
  "$ROOT/lib/sync/plugins-mcp.sh" \
  "$ROOT/lib/sync/frameworks.sh"; do
  test -f "$f"
done

echo "[3] required doctor domains"
for f in \
  "$ROOT/lib/doctor/local-prereqs.sh" \
  "$ROOT/lib/doctor/claude.sh" \
  "$ROOT/lib/doctor/codex-integrity.sh" \
  "$ROOT/lib/doctor/lazycodex.sh" \
  "$ROOT/lib/doctor/agent-mcp.sh" \
  "$ROOT/lib/doctor/frameworks.sh" \
  "$ROOT/lib/doctor/main.sh"; do
  test -f "$f"
done

echo "[4] public command functions"
grep -q '^cmd_sync()' "$ROOT/lib/sync.sh"
grep -q '^cmd_doctor()' "$ROOT/lib/doctor/main.sh"
grep -q '^sync_external_tools()' "$ROOT/lib/sync/external-tools.sh"
grep -q '^sync_plugins_mcp()' "$ROOT/lib/sync/plugins-mcp.sh"
grep -q '^sync_agent_mcp_frameworks()' "$ROOT/lib/sync/frameworks.sh"
grep -q '^doctor_lazycodex()' "$ROOT/lib/doctor/lazycodex.sh"
grep -q '^doctor_agent_mcp_surfaces()' "$ROOT/lib/doctor/agent-mcp.sh"

echo "[5] isolated HOME validate"
tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT
HOME="$tmp_home" bash "$ROOT/setup.sh" validate >/tmp/oh-my-agent-env-validate.out
grep -q '=== oh-my-agent-env validate ===' /tmp/oh-my-agent-env-validate.out

echo "[6] oma subcommand isolated smoke (stubbed bunx, no network)"
oma_tmp="$(mktemp -d)"
trap 'rm -rf "$tmp_home" "$oma_tmp"' EXIT
stub_bin="$oma_tmp/bin"; mkdir -p "$stub_bin" "$oma_tmp/home"
# offline stub: oma install just materializes .agents/ in the project cwd
cat > "$stub_bin/bunx" <<'STUB'
#!/usr/bin/env bash
mkdir -p "$PWD/.agents"
echo "stub: oma installed"
STUB
chmod +x "$stub_bin/bunx"
oma_proj="$oma_tmp/proj"; mkdir -p "$oma_proj"
run_oma() { PATH="$stub_bin:$PATH" HOME="$oma_tmp/home" bash "$ROOT/setup.sh" oma "$oma_proj" >/dev/null 2>&1; }
run_oma
# a) oma-config.yaml overlaid byte-identical to the tracked template (managed)
cmp -s "$oma_proj/.agents/oma-config.yaml" "$ROOT/templates/oma/oma-config.yaml"
# b) statusLine pinned in settings.local.json -> our unified script
python3 -c "import json,sys; d=json.load(open('$oma_proj/.claude/settings.local.json')); sys.exit(0 if d.get('statusLine',{}).get('command','').endswith('my-statusline.mjs') else 1)"
# c) idempotent: a second run leaves both outputs byte-stable
cp "$oma_proj/.claude/settings.local.json" "$oma_tmp/sl1"
run_oma
cmp -s "$oma_proj/.claude/settings.local.json" "$oma_tmp/sl1"
cmp -s "$oma_proj/.agents/oma-config.yaml" "$ROOT/templates/oma/oma-config.yaml"

echo "smoke-refactor OK"
