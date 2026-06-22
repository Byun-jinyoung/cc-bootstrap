#!/usr/bin/env node
/**
 * Byun's Custom Statusline (omc-free, OMC-style layout)
 *
 * Reproduces the OMC HUD look — Model | branch | 5h/wk usage bars | session |
 * ctx bar — WITHOUT oh-my-claudecode. Data sources:
 *   - stdin JSON (Claude Code statusline payload): model, context_window, cwd,
 *     transcript_path (session start = first transcript timestamp)
 *   - ~/.claude/statusline_cache.json: 5h / 7d usage windows, populated by
 *     cc-alchemy-statusline's OAuth fetch (reused here purely as the fetcher).
 * A background `cc-alchemy-statusline --fetch-only` keeps that cache fresh.
 *
 * Omitted vs the original OMC HUD (engine-internal, no source without omc):
 *   [OMC#version] label, the "sn" window, agents/todos/ralph operational state.
 *
 * Install: statusLine in ~/.claude/settings.json:
 *   { "type": "command", "command": "node $HOME/.claude/hud/my-statusline.mjs" }
 */

import { readFileSync, openSync, readSync, closeSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { execSync, spawn } from "node:child_process";

const HOME = homedir();
const CACHE_FILE = join(HOME, ".claude", "statusline_cache.json");

// --- Colors (Catppuccin-ish, matching the prior HUD palette) ---
const rgb = (r, g, b) => `\x1b[38;2;${r};${g};${b}m`;
const RST = "\x1b[0m";
const DIM = rgb(108, 112, 134);
const TEXT = rgb(205, 214, 244);
const MODEL = rgb(147, 153, 178);
const BRANCH = rgb(137, 180, 250);
const GREEN = rgb(166, 227, 161);
const YELLOW = rgb(249, 226, 175);
const RED = rgb(243, 139, 168);
const pcolor = (p) => (p < 50 ? GREEN : p < 90 ? YELLOW : RED);

function readStdin() {
  try {
    return readFileSync(0, "utf-8");
  } catch {
    return "";
  }
}

function gitBranch(cwd) {
  try {
    return execSync("git rev-parse --abbrev-ref HEAD 2>/dev/null", {
      cwd: cwd || process.cwd(),
      encoding: "utf-8",
      timeout: 2000,
    }).trim();
  } catch {
    return "";
  }
}

function readCache() {
  try {
    return JSON.parse(readFileSync(CACHE_FILE, "utf-8"));
  } catch {
    return {};
  }
}

// Refresh the usage cache in the background (cc-alchemy rate-limits its own
// fetches, so calling this every render is cheap and usually a no-op).
function refreshCache() {
  try {
    const child = spawn("cc-alchemy-statusline", ["--fetch-only"], {
      detached: true,
      stdio: "ignore",
    });
    child.unref();
  } catch {
    // cc-alchemy not installed — render with whatever cache exists.
  }
}

// Session duration = now - first transcript entry timestamp. Reads only the
// first chunk of the (append-only) transcript, so cost is O(1) regardless of
// transcript size.
function sessionMins(transcriptPath) {
  if (!transcriptPath) return null;
  let fd;
  try {
    fd = openSync(transcriptPath, "r");
    // Read a bounded chunk (the first few lines are meta entries without a
    // timestamp; the first real entry that has one is the session start).
    const buf = Buffer.alloc(16384);
    const n = readSync(fd, buf, 0, buf.length, 0);
    for (const line of buf.toString("utf-8", 0, n).split("\n")) {
      if (!line.trim()) continue;
      let ts;
      try { ts = JSON.parse(line).timestamp; } catch { continue; }
      if (ts) return Math.max(0, Math.floor((Date.now() - new Date(ts).getTime()) / 60000));
    }
    return null;
  } catch {
    return null;
  } finally {
    if (fd !== undefined) try { closeSync(fd); } catch {}
  }
}

function fmtDuration(mins) {
  if (mins < 60) return `${mins}m`;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return m ? `${h}h${m}m` : `${h}h`;
}

function bar(pct, n) {
  const filled = Math.max(0, Math.min(n, Math.round((pct / 100) * n)));
  return "[" + "█".repeat(filled) + "░".repeat(n - filled) + "]";
}

function resetTxt(resetsAt) {
  if (!resetsAt) return "";
  const secs = Math.max(0, Math.floor((new Date(resetsAt).getTime() - Date.now()) / 1000));
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  if (h > 24) return `(${Math.floor(h / 24)}d${h % 24}h)`;
  if (h > 0) return `(${h}h${m}m)`;
  return `(${m}m)`;
}

function usageSeg(label, period) {
  if (!period || period.utilization == null) {
    return `${DIM}${label}:${bar(0, 8)}${RST} ${DIM}--${RST}`;
  }
  const u = Math.round(period.utilization);
  return `${DIM}${label}:${pcolor(u)}${bar(u, 8)}${u}%${DIM}${resetTxt(period.resets_at)}${RST}`;
}

function main() {
  let data = {};
  try {
    const raw = readStdin();
    if (raw.trim()) data = JSON.parse(raw);
  } catch {
    // malformed stdin — render with defaults
  }

  const m = data.model || {};
  const name = (m.display_name || m.id || "Claude").replace("Claude ", "");
  const cwd = data.workspace?.current_dir || data.cwd || process.cwd();
  const branch = gitBranch(cwd);
  const ctxPct = Math.round(data.context_window?.used_percentage || 0);

  const cache = readCache();
  const mins = sessionMins(data.transcript_path);

  const SEP = ` ${DIM}|${RST} `;
  const parts = [`${DIM}Model: ${MODEL}${name}${RST}`];
  if (branch) parts.push(`${DIM}branch:${BRANCH}${branch}${RST}`);
  parts.push(`${usageSeg("5h", cache.five_hour)} ${usageSeg("wk", cache.seven_day)}`);
  if (mins != null) parts.push(`${DIM}session:${TEXT}${fmtDuration(mins)}${RST}`);
  parts.push(`${DIM}ctx:${pcolor(ctxPct)}${bar(ctxPct, 10)}${ctxPct}%${RST}`);

  console.log(parts.join(SEP));
  refreshCache();
}

main();
