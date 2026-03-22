#!/usr/bin/env node
/**
 * Byun's Custom Statusline
 *
 * Wrapper around OMC HUD with personalized configuration.
 * Combines cc-alchemy-style metrics (model, branch, 5h/7d usage bars)
 * with OMC operational state (ralph, agents, todos, skills).
 *
 * Install: Set statusLine in ~/.claude/settings.json to:
 *   { "type": "command", "command": "node $HOME/.claude/hud/my-statusline.mjs" }
 */

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const HOME = homedir();
const CONFIG_DIR = process.env.CLAUDE_CONFIG_DIR || join(HOME, ".claude");
const SETTINGS_FILE = join(CONFIG_DIR, "settings.json");

/**
 * Custom HUD configuration preset.
 * Merges into settings.json omcHud key on first run.
 */
const MY_HUD_CONFIG = {
  preset: "custom",
  elements: {
    // Git + Model (top line)
    cwd: false,
    gitRepo: false,
    gitBranch: true,
    gitInfoPosition: "above",
    model: true,
    modelFormat: "versioned",

    // Main HUD line
    omcLabel: true,
    rateLimits: true,
    useBars: true,
    contextBar: true,
    sessionHealth: true,
    promptTime: true,
    showCallCounts: true,
    thinking: true,
    thinkingFormat: "text",

    // OMC operational state
    ralph: true,
    autopilot: true,
    activeSkills: true,
    lastSkill: true,
    prdStory: true,

    // Agents + Tasks
    agents: true,
    agentsFormat: "multiline",
    agentsMaxLines: 5,
    backgroundTasks: true,
    todos: true,

    // Disabled
    apiKeySource: false,
    profile: true,
    permissionStatus: false,
    missionBoard: false,
    showTokens: false,
    safeMode: false,
    maxOutputLines: 6,
  },
  thresholds: {
    contextWarning: 70,
    contextCompactSuggestion: 80,
    contextCritical: 85,
    ralphWarning: 7,
  },
  staleTaskThresholdMinutes: 30,
  contextLimitWarning: {
    threshold: 80,
    autoCompact: false,
  },
  wrapMode: "truncate",
};

/**
 * Inject custom omcHud config into settings.json if not already set.
 */
function ensureConfig() {
  try {
    let settings = {};
    if (existsSync(SETTINGS_FILE)) {
      settings = JSON.parse(readFileSync(SETTINGS_FILE, "utf-8"));
    }

    // Only inject if omcHud is missing or marked as custom
    if (!settings.omcHud || settings.omcHud.preset === "custom") {
      const current = JSON.stringify(settings.omcHud || {});
      const desired = JSON.stringify(MY_HUD_CONFIG);
      if (current !== desired) {
        settings.omcHud = MY_HUD_CONFIG;
        writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
      }
    }
  } catch {
    // Silent failure - don't break statusline
  }
}

/**
 * Find and import OMC HUD engine.
 * Same resolution logic as omc-hud.mjs.
 */
async function runOmcHud() {
  // Plugin cache
  const pluginCacheBase = join(CONFIG_DIR, "plugins", "cache", "omc", "oh-my-claudecode");
  if (existsSync(pluginCacheBase)) {
    try {
      const { readdirSync } = await import("node:fs");
      const versions = readdirSync(pluginCacheBase)
        .filter(v => existsSync(join(pluginCacheBase, v, "dist/hud/index.js")))
        .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
        .reverse();

      if (versions.length > 0) {
        const hudPath = join(pluginCacheBase, versions[0], "dist/hud/index.js");
        await import(pathToFileURL(hudPath).href);
        return;
      }
    } catch { /* continue */ }
  }

  // npm package fallback
  try {
    await import("oh-my-claudecode/dist/hud/index.js");
    return;
  } catch { /* continue */ }

  // Fallback: pipe stdin through to cc-alchemy-statusline
  try {
    const { readFileSync } = await import("node:fs");
    const { execSync } = await import("node:child_process");
    const stdin = readFileSync(0, "utf-8");
    if (stdin.trim()) {
      const output = execSync("cc-alchemy-statusline", {
        input: stdin,
        encoding: "utf-8",
        timeout: 5000,
      }).trim();
      if (output && output !== "No data") {
        console.log(output);
        return;
      }
    }
  } catch { /* continue */ }

  // Final fallback: minimal statusline
  const { execSync: exec } = await import("node:child_process");
  const parts = [];
  try {
    const branch = exec("git rev-parse --abbrev-ref HEAD 2>/dev/null", { encoding: "utf-8" }).trim();
    if (branch) parts.push(`⎇ ${branch}`);
  } catch { /* no git */ }
  try {
    const model = process.env.CLAUDE_MODEL || "opus";
    parts.push(`◆ ${model}`);
  } catch { /* skip */ }
  console.log(parts.length > 0 ? parts.join("  ") : "cc-bootstrap");
}

// Main
ensureConfig();
await runOmcHud();
