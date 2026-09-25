#!/usr/bin/env node
/**
 * Cost Tracker Hook — v2
 *
 * Fires on Stop (after each response) and UserPromptSubmit (before each response).
 * Scans ALL assistant turns in the transcript(s) and logs any not yet recorded,
 * using message.id as the deduplication key. This catches:
 *   - The just-completed turn (normal Stop flow)
 *   - All prior turns that Stop missed due to session crash/kill
 *   - Turns from recently-crashed OTHER sessions (UserPromptSubmit scans recent files)
 *
 * Output after each response (Stop hook only):
 *   💰 This response: ~$0.0124 (12.4k in / 0.8k out / 87.9k cached) | Session: ~$0.48
 *
 * NOTE: Costs are estimated using standard Anthropic API list prices. Actual charges
 * on paid Claude Code plans may differ (plan discounts, subscription credits, etc.).
 */

'use strict';

const fs   = require('fs');
const path = require('path');
const os   = require('os');

const MAX_STDIN        = 1024 * 1024;
const MAX_METRICS_SIZE = 50 * 1024 * 1024;
let raw = '';

function toNum(v) { const n = Number(v); return Number.isFinite(n) ? n : 0; }

function estimateCost(model, inputTokens, outputTokens, cacheWriteTokens, cacheReadTokens) {
  const rates = {
    haiku:  { in: 1.00,  out: 5.00,  cacheWrite: 1.25,  cacheRead: 0.10  },
    sonnet: { in: 3.00,  out: 15.00, cacheWrite: 3.75,  cacheRead: 0.30  },
    opus:   { in: 5.00,  out: 25.00, cacheWrite: 6.25,  cacheRead: 0.50  },
    fable:  { in: 10.00, out: 50.00, cacheWrite: 12.50, cacheRead: 1.00  },
  };
  const m = String(model || '').toLowerCase();
  let r = rates.sonnet;
  if (m.includes('haiku')) r = rates.haiku;
  if (m.includes('opus'))  r = rates.opus;
  if (m.includes('fable') || m.includes('mythos')) r = rates.fable;
  return Math.round((
    (inputTokens      / 1e6) * r.in         +
    (outputTokens     / 1e6) * r.out        +
    (cacheWriteTokens / 1e6) * r.cacheWrite +
    (cacheReadTokens  / 1e6) * r.cacheRead
  ) * 1e6) / 1e6;
}

function ensureDir(d) { if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true }); }

// Find transcript path for a session_id by searching project dirs
function findTranscriptBySessionId(sessionId) {
  const projectsDir = path.join(os.homedir(), '.claude', 'projects');
  try {
    for (const proj of fs.readdirSync(projectsDir)) {
      const candidate = path.join(projectsDir, proj, `${sessionId}.jsonl`);
      if (fs.existsSync(candidate)) return candidate;
    }
  } catch {}
  return null;
}

// All top-level transcript files modified within last 24h (skips subagent subdirs)
function getRecentTranscripts() {
  const projectsDir = path.join(os.homedir(), '.claude', 'projects');
  const cutoff = Date.now() - 24 * 60 * 60 * 1000;
  const result = [];
  try {
    for (const proj of fs.readdirSync(projectsDir)) {
      const projDir = path.join(projectsDir, proj);
      try { if (!fs.statSync(projDir).isDirectory()) continue; } catch { continue; }
      try {
        for (const file of fs.readdirSync(projDir)) {
          if (!file.endsWith('.jsonl')) continue;
          const fp = path.join(projDir, file);
          try { if (fs.statSync(fp).mtimeMs > cutoff) result.push(fp); } catch {}
        }
      } catch {}
    }
  } catch {}
  return result;
}

// Extract all assistant turns with message IDs from a transcript
function extractTurns(transcriptPath) {
  const turns = [];
  const basename = path.basename(transcriptPath, '.jsonl');
  const fileSessionId = /^[0-9a-f]{8}-[0-9a-f]{4}/.test(basename) ? basename : null;
  try {
    const lines = fs.readFileSync(transcriptPath, 'utf8').trim().split('\n').filter(Boolean);
    for (const line of lines) {
      try {
        const e = JSON.parse(line);
        if (e.type !== 'assistant') continue;
        const msg = e.message || {};
        if (!msg.usage || !msg.id) continue;
        turns.push({
          messageId: msg.id,
          sessionId: e.sessionId || fileSessionId || 'unknown',
          model:     msg.model || '',
          usage:     msg.usage,
          timestamp: e.timestamp || null,
        });
      } catch {}
    }
  } catch {}
  return turns;
}

// Load already-logged message IDs from costs.jsonl
function getLoggedMessageIds(metricsFile) {
  const ids = new Set();
  if (!fs.existsSync(metricsFile)) return ids;
  try {
    for (const line of fs.readFileSync(metricsFile, 'utf8').split('\n')) {
      try {
        const e = JSON.parse(line);
        if (e.message_id) ids.add(e.message_id);
      } catch {}
    }
  } catch {}
  return ids;
}

process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => {
  if (raw.length < MAX_STDIN) raw += chunk.substring(0, MAX_STDIN - raw.length);
});

process.stdin.on('end', () => {
  try {
    const input      = raw.trim() ? JSON.parse(raw) : {};
    const sessionId  = String(input.session_id || process.env.CLAUDE_SESSION_ID || 'default');
    const isStopHook = !!input.transcript_path;

    const metricsDir  = path.join(os.homedir(), '.claude', 'metrics');
    ensureDir(metricsDir);
    const metricsFile = path.join(metricsDir, 'costs.jsonl');

    try {
      if (fs.existsSync(metricsFile) && fs.statSync(metricsFile).size > MAX_METRICS_SIZE) {
        process.stdout.write(raw); return;
      }
    } catch {}

    // Collect transcript paths to scan
    const transcriptPaths = new Set();
    if (isStopHook && fs.existsSync(input.transcript_path)) {
      transcriptPaths.add(input.transcript_path);
    }
    // Always also find current session's transcript by ID (in case path differs)
    const byId = findTranscriptBySessionId(sessionId);
    if (byId) transcriptPaths.add(byId);
    // On UserPromptSubmit scan all recent transcripts for crash recovery
    if (!isStopHook) {
      for (const tp of getRecentTranscripts()) transcriptPaths.add(tp);
    }

    if (transcriptPaths.size === 0) { process.stdout.write(raw); return; }

    const loggedIds  = getLoggedMessageIds(metricsFile);
    const newEntries = [];

    for (const tp of transcriptPaths) {
      for (const turn of extractTurns(tp)) {
        if (loggedIds.has(turn.messageId)) continue;
        const u    = turn.usage;
        const cost = estimateCost(
          turn.model,
          toNum(u.input_tokens), toNum(u.output_tokens),
          toNum(u.cache_creation_input_tokens), toNum(u.cache_read_input_tokens),
        );
        if (cost === 0) continue;
        newEntries.push({
          timestamp:          turn.timestamp || new Date().toISOString(),
          session_id:         turn.sessionId,
          message_id:         turn.messageId,
          model:              turn.model,
          input_tokens:       toNum(u.input_tokens),
          output_tokens:      toNum(u.output_tokens),
          cache_write_tokens: toNum(u.cache_creation_input_tokens),
          cache_read_tokens:  toNum(u.cache_read_input_tokens),
          estimated_cost_usd: cost,
        });
        loggedIds.add(turn.messageId);
      }
    }

    if (newEntries.length > 0) {
      fs.appendFileSync(metricsFile, newEntries.map(e => JSON.stringify(e)).join('\n') + '\n');

      // Session total for current session
      let sessionTotal = 0;
      try {
        sessionTotal = fs.readFileSync(metricsFile, 'utf8').trim().split('\n')
          .filter(Boolean)
          .map(l => { try { return JSON.parse(l); } catch { return null; } })
          .filter(e => e && e.session_id === sessionId)
          .reduce((sum, e) => sum + (e.estimated_cost_usd || 0), 0);
      } catch {}

      // Delta display on Stop hook only (show the last new entry = current response)
      if (isStopHook) {
        const last      = newEntries[newEntries.length - 1];
        const kIn       = (last.input_tokens / 1000).toFixed(1);
        const kOut      = (last.output_tokens / 1000).toFixed(1);
        const kCache    = (last.cache_read_tokens / 1000).toFixed(1);
        const cacheNote = last.cache_read_tokens > 0 ? ` / ${kCache}k cached` : '';
        const catchup   = newEntries.length > 1 ? ` [+${newEntries.length - 1} recovered]` : '';
        const deltaLine = `💰 This response: ~$${last.estimated_cost_usd.toFixed(4)} (${kIn}k in / ${kOut}k out${cacheNote})${catchup} | Session: ~$${sessionTotal.toFixed(4)}\n`;
        process.stderr.write(`\n${deltaLine}`);
        try {
          fs.appendFileSync(path.join(metricsDir, 'delta.log'), `${new Date().toISOString()} ${deltaLine}`);
        } catch {}
      }
    }
  } catch (err) {
    if (process.env.COST_TRACKER_DEBUG) {
      process.stderr.write(`[cost-tracker] Error: ${err.message}\n${err.stack}\n`);
    }
  }

  process.stdout.write(raw);
});
