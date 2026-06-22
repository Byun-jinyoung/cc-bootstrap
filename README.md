# oh-my-agent-env

One-command Claude Code environment setup for multiple machines.

## Quick Start

```bash
git clone https://github.com/Byun-jinyoung/oh-my-agent-env.git
cd oh-my-agent-env
bash setup.sh
```

## What It Installs

| Component | Description |
|---|---|
| **codex-gemini-mcp** (fork) | MCP servers `codex-mcp` + `antigravity-mcp` with multi-turn `session_id` resume (Gemini provider removed 2026-06-18) |
| **my-statusline.mjs** | Custom statusline (omc-free, OMC-style bars): `Model: \| branch: \| 5h/wk usage bars \| session \| ctx` — renders from the cc-alchemy usage cache + transcript |
| **GEMINI.md** | Global reliability rules for Antigravity (agy reads `~/.gemini/GEMINI.md` via gemini-cli inheritance) |
| **instructions.md** | Global reliability rules for Codex CLI |
| **LazyCodex** | Codex plugin `omo@sisyphuslabs` installed via `npx lazycodex-ai@latest install --no-tui` |
| **oh-my-agent (oma)** | Per-project multi-agent harness (first-fluke/oh-my-agent), installed via `setup.sh oma <path>` |
| **Graphify** | Knowledge graph CLI (`graphifyy` package, `graphify` command), Claude/Codex skills, and project hooks |

## Directory Structure

```
oh-my-agent-env/
├── setup.sh                              # Entry: globals, .env source, dispatcher, small cmd_*
├── lib/                                  # setup.sh helpers (sourced after globals)
│   ├── common.sh                         #   shared helpers (log, link, MCP verify/cleanup, codex hooks, ...)
│   ├── sync.sh                           #   cmd_sync orchestrator, stable phase order
│   ├── sync/
│   │   ├── core.sh                       #   Claude commands/hooks
│   │   ├── rules.sh                      #   Codex/Gemini dirs + global rules
│   │   ├── skills.sh                     #   registry.yaml skill links + statusline
│   │   ├── external-tools.sh             #   context-mode, Codex CLI, LazyCodex, fork install
│   │   ├── plugins-mcp.sh                #   Claude plugins + Claude MCP registration
│   │   └── frameworks.sh                 #   Codex/Antigravity MCPs, Serena, GSD/RTK/Graphify/CRG/codegraph
│   ├── doctor.sh                         #   cmd_doctor loader
│   └── doctor/
│       ├── local-prereqs.sh              #   npm prefix, state dirs, CLI tools, symlinks
│       ├── claude.sh                     #   Claude plugins + Claude MCP surfaces
│       ├── codex-integrity.sh            #   codex-gemini-mcp fork and codex CLI integrity
│       ├── lazycodex.sh                  #   LazyCodex / omo@sisyphuslabs plugin check
│       ├── agent-mcp.sh                  #   Codex/Antigravity MCP and context-mode checks
│       ├── frameworks.sh                 #   managed skills, GSD, RTK, Graphify, CRG
│       └── main.sh                       #   cmd_doctor orchestration
├── ui/statusline/
│   └── my-statusline.mjs                 # Custom statusline (omc-free; reuses cc-alchemy-statusline)
├── runtimes/
│   ├── claude/commands/                  # Claude Code slash commands
│   │   ├── analyze-paper.md
│   │   └── debate-loop.md
│   ├── codex/
│   │   ├── instructions.md               # Codex global rules
│   │   └── tools.md                      # Codex tool guidance
│   └── antigravity/
│       ├── tools.md                      # Antigravity (agy) tool guidance
│       └── skills/
├── rules/                                # SRP-split global rule modules (Layer A)
├── skills/                               # Shared oh-my-agent-env skills (codebase-scan, triangle-review, ...)
├── scripts/                              # Helper shell scripts (apply-project-template, snapshot, ...)
└── tests/
    └── smoke-refactor.sh                 # Source graph + isolated HOME validate smoke test
```

`setup.sh` is intentionally kept as the stable user-facing entrypoint. The
`sync` and `doctor` loaders preserve command names while domain files make
runtime parity easier to review: setup mutating domains and diagnostic domains
are now visible in the file tree instead of being hidden in monolithic scripts.

## Prerequisites

- Node.js >= 20
- git, npm
- Claude Code CLI
- (Optional) Antigravity (agy): see https://antigravity.google.com — gemini-cli successor
- (Optional) Codex CLI: `npm install -g @openai/codex`

## LazyCodex for Codex

`setup.sh sync` installs LazyCodex on each machine through its upstream npx
installer:

```bash
npx --yes lazycodex-ai@latest install --no-tui
```

LazyCodex registers in Codex as `omo@sisyphuslabs`, so the expected verification
surface is:

```bash
codex plugin list | grep 'omo@sisyphuslabs'
~/.local/bin/omo --version
```

After the first sync on a new machine, restart Codex App/CLI and approve the
`omo@sisyphuslabs` hooks when Codex asks.

## Project Graphify Setup

`setup.sh sync` installs the global Graphify CLI and links the managed skill into Claude Code and Codex-compatible `~/.agents/skills`.

For each project, run:

```bash
bash setup.sh init-project /path/to/project
```

This appends the Graphify guidance section to `AGENTS.md` and `CLAUDE.md`, installs `.codex/hooks.json` and `.claude/settings.json` hooks, and creates `.graphifyignore` defaults.

## Related Repos

- [codex-gemini-mcp (fork)](https://github.com/Byun-jinyoung/codex-gemini-mcp) — `codex-mcp` + `antigravity-mcp` with session resume + multi-turn
- [oh-my-agent](https://github.com/first-fluke/oh-my-agent) — per-project multi-agent harness (installed via `setup.sh oma <path>`)
