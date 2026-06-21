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

echo "smoke-refactor OK"
