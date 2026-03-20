---
name: gemini-swarm
description: Use when the user requests multi-agent parallel research, analysis, or task execution via Gemini CLI with gemini-swarm extension. Triggers include "swarm", "parallel agents", "multi-agent research", or requests to spawn multiple Gemini agents.
---

# Gemini Swarm

Multi-agent parallel execution via Gemini CLI + gemini-swarm extension.

## Execution Modes

Choose **foreground** for quick tasks (<60s), **background** for longer tasks or when you need to do other work while waiting.

## Foreground (Synchronous)

### New session
```bash
PROMPT="$(cat <<'SWARM_EOF'
You have gemini-swarm extension tools. Follow these steps:
1. Call swarm_init to start coordination server
2. Create tasks via swarm_create_tasks
3. Call swarm_spawn with count=AGENT_COUNT
4. Wait for completion, then call swarm_status
5. Collect results with swarm_results
6. Synthesize and report final combined results.

IMPORTANT: Do NOT fabricate answers. If you don't know, say so. Ground all work in facts, code, or documentation.

Task: USER_PROMPT_HERE
SWARM_EOF
)"
timeout 600 gemini -p "$PROMPT" -y --model gemini-2.5-pro -o json 2>/dev/null
```

### Resume session
```bash
PROMPT="$(cat <<'SWARM_EOF'
Follow-up prompt here
SWARM_EOF
)"
timeout 600 gemini --resume SESSION_UUID -p "$PROMPT" -y -o json 2>/dev/null
```

## Background (Asynchronous)

### Submit job
```bash
JOB_DIR="/tmp/gemini-swarm-jobs"
JOB_ID=$(date +%s%N | md5sum | head -c8)
mkdir -p "$JOB_DIR"

PROMPT="$(cat <<'SWARM_EOF'
You have gemini-swarm extension tools. Follow these steps:
1. Call swarm_init to start coordination server
2. Create tasks via swarm_create_tasks
3. Call swarm_spawn with count=AGENT_COUNT
4. Wait for completion, then call swarm_status
5. Collect results with swarm_results
6. Synthesize and report final combined results.

IMPORTANT: Do NOT fabricate answers. If you don't know, say so. Ground all work in facts, code, or documentation.

Task: USER_PROMPT_HERE
SWARM_EOF
)"

echo "{\"status\":\"running\",\"pid\":0,\"started\":\"$(date -Iseconds)\"}" > "$JOB_DIR/$JOB_ID.status.json"
(
  timeout 600 gemini -p "$PROMPT" -y --model gemini-2.5-pro -o json \
    > "$JOB_DIR/$JOB_ID.out.json" 2>"$JOB_DIR/$JOB_ID.err.log"
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 0 ]; then
    echo "{\"status\":\"completed\",\"completed\":\"$(date -Iseconds)\"}" > "$JOB_DIR/$JOB_ID.status.json"
  else
    echo "{\"status\":\"failed\",\"exit_code\":$EXIT_CODE,\"completed\":\"$(date -Iseconds)\"}" > "$JOB_DIR/$JOB_ID.status.json"
  fi
) &
BG_PID=$!
echo "{\"status\":\"running\",\"pid\":$BG_PID,\"started\":\"$(date -Iseconds)\"}" > "$JOB_DIR/$JOB_ID.status.json"
echo "JOB_ID=$JOB_ID PID=$BG_PID"
```

### Check status
```bash
cat /tmp/gemini-swarm-jobs/JOB_ID.status.json
```

### Get results
```bash
python3 -c "import json,sys; d=json.load(open('/tmp/gemini-swarm-jobs/JOB_ID.out.json')); print(d.get('response','(no response)'))"
```

### Kill job
```bash
kill $(python3 -c "import json; print(json.load(open('/tmp/gemini-swarm-jobs/JOB_ID.status.json'))['pid'])")
echo '{"status":"killed"}' > /tmp/gemini-swarm-jobs/JOB_ID.status.json
```

## Output Format

Success (`-o json`):
```json
{"session_id": "uuid", "response": "...", "stats": {...}}
```
- Extract `response` field for the answer
- Save `session_id` for potential follow-up with `--resume`

Error: non-zero exit code, or JSON with `error` field.

## Session Management

- **Do NOT track sessions in files.** Hold `session_id` in conversation context.
- **New session**: default for new topics.
- **Resume**: only when user explicitly asks to continue previous swarm work, or when adding follow-up tasks to an existing swarm.
- **List sessions**: `gemini --list-sessions` to discover previous sessions.
- If swarm coordination server is down on resume, Gemini agent auto-restarts it via `swarm_init`.

## Key Flags

| Flag | Purpose | Required |
|---|---|---|
| `-p` | Headless mode (non-interactive) | Yes |
| `-y` | Auto-approve all tool calls (YOLO) | Yes, swarm tools need this |
| `-o json` | Structured JSON output | Yes |
| `--model` | Model selection | Optional (default: gemini-2.5-pro) |
| `--resume UUID` | Continue previous session | Only for follow-up |
| `timeout 600` | Prevent indefinite hang | Recommended |

## Agent Count Guidelines

| Task type | Agents | Example |
|---|---|---|
| Simple comparison | 2 | Compare two approaches |
| Multi-topic research | 3-5 | Research 3-5 independent subtopics |
| Comprehensive analysis | 5-8 | Analyze multiple files/systems in parallel |
| Max parallel | 10 | Hard limit in gemini-swarm |

## Error Handling

1. Non-zero exit: check stderr, report to user
2. Timeout (600s): swarm may be stuck, suggest reducing agent count or simplifying tasks
3. Empty response: retry once, then report failure
4. Parse error on JSON: fall back to raw stdout text
5. Background job failed: check `JOB_ID.err.log` for details

## What NOT to Do

- Do NOT use `mcp__gemini-mcp__ask_gemini` for swarm tasks (missing `-y` flag)
- Do NOT embed raw user text directly in shell arguments without heredoc
- Do NOT resume sessions for unrelated topics
- Do NOT spawn more agents than independent subtasks
