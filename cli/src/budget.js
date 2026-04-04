'use strict';

const fs = require('fs');
const path = require('path');

// ── ANSI helpers ─────────────────────────────────────────────────────────────

const c = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
};

const PASS = `${c.green}\u2713${c.reset}`;
const WARN = `${c.yellow}\u26A0${c.reset}`;
const FAIL = `${c.red}\u2717${c.reset}`;

// ── Token estimation ─────────────────────────────────────────────────────────

// CJK Unicode ranges
const CJK_RE = /[\u3000-\u9fff\uac00-\ud7af\uff00-\uffef]/g;

function estimateTokens(text) {
  const cjkChars = (text.match(CJK_RE) || []).length;
  const nonCjkChars = text.length - cjkChars;
  // ~4 chars per token for English/ASCII, ~2 chars per token for CJK
  return Math.ceil(nonCjkChars / 4 + cjkChars / 2);
}

// ── Utility functions ────────────────────────────────────────────────────────

function fileExists(fp) {
  try { return fs.statSync(fp).isFile(); } catch { return false; }
}

function dirExists(dp) {
  try { return fs.statSync(dp).isDirectory(); } catch { return false; }
}

function readFile(fp) {
  try { return fs.readFileSync(fp, 'utf8'); } catch { return ''; }
}

function listFiles(dp, ext) {
  try {
    return fs.readdirSync(dp).filter((f) => {
      if (ext && !f.endsWith(ext)) return false;
      return fs.statSync(path.join(dp, f)).isFile();
    });
  } catch { return []; }
}

function hasFrontmatterKey(content, key) {
  const fmMatch = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!fmMatch) return false;
  const re = new RegExp(`^${key}\\s*:`, 'm');
  return re.test(fmMatch[1]);
}

function extractFrontmatter(content) {
  const fmMatch = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!fmMatch) return '';
  return fmMatch[0];
}

function progressBar(ratio, width) {
  const filled = Math.round(ratio * width);
  const empty = width - filled;
  const bar = '\u2588'.repeat(filled) + '\u2591'.repeat(empty);
  const pct = Math.round(ratio * 100);
  return `${bar} (${pct}%)`;
}

function pad(label, width) {
  const dots = Math.max(2, width - label.length);
  return label + ' ' + '.'.repeat(dots);
}

function formatTokens(n) {
  if (n >= 1000) return `${(n / 1000).toFixed(1)}K`;
  return `${n}`;
}

// ── Budget categories ────────────────────────────────────────────────────────

const BUDGETS = {
  'CLAUDE.md': 2000,
  '.claude/CLAUDE.md': 1500,
};

// ── Main ─────────────────────────────────────────────────────────────────────

function runBudget(cwd) {
  process.stdout.write(`\n${c.bold}cc-path budget${c.reset}\n`);
  process.stdout.write('==============\n\n');

  let totalAlways = 0;
  const COL = 28;
  const BAR_WIDTH = 10;

  // ── Layer 1: Always loaded ───────────────────────────────────────────────

  process.stdout.write(`${c.bold}Layer 1 (Always loaded):${c.reset}\n`);

  const alwaysFiles = [
    { label: 'CLAUDE.md', fp: path.join(cwd, 'CLAUDE.md'), budget: BUDGETS['CLAUDE.md'] },
    { label: '.claude/CLAUDE.md', fp: path.join(cwd, '.claude', 'CLAUDE.md'), budget: BUDGETS['.claude/CLAUDE.md'] },
  ];

  // Unconditional rules (no paths: frontmatter)
  const rulesDir = path.join(cwd, '.claude', 'rules');
  const ruleFiles = listFiles(rulesDir, '.md');
  for (const f of ruleFiles) {
    const content = readFile(path.join(rulesDir, f));
    if (!hasFrontmatterKey(content, 'paths')) {
      alwaysFiles.push({
        label: `rules/${f}`,
        fp: path.join(rulesDir, f),
        budget: null,
      });
    }
  }

  for (const entry of alwaysFiles) {
    if (!fileExists(entry.fp)) {
      process.stdout.write(`  ${pad(entry.label, COL)} ${c.dim}not found${c.reset}\n`);
      continue;
    }
    const content = readFile(entry.fp);
    const tokens = estimateTokens(content);
    totalAlways += tokens;

    if (entry.budget) {
      const ratio = Math.min(tokens / entry.budget, 1.0);
      const bar = progressBar(ratio, BAR_WIDTH);
      const budgetStr = formatTokens(entry.budget);
      const color = ratio > 0.8 ? c.yellow : c.green;
      process.stdout.write(`  ${pad(entry.label, COL)} ${color}${tokens} tokens${c.reset}  ${bar}\n`);
    } else {
      process.stdout.write(`  ${pad(entry.label, COL)} ${tokens} tokens\n`);
    }
  }

  // ── Layer 2: Conditional ─────────────────────────────────────────────────

  const conditionalFiles = [];
  for (const f of ruleFiles) {
    const content = readFile(path.join(rulesDir, f));
    if (hasFrontmatterKey(content, 'paths')) {
      const tokens = estimateTokens(content);
      conditionalFiles.push({ label: f, tokens });
    }
  }

  if (conditionalFiles.length > 0) {
    process.stdout.write(`\n${c.bold}Layer 2 (Conditional):${c.reset}\n`);
    for (const entry of conditionalFiles) {
      process.stdout.write(`  ${pad(entry.label, COL)} ${entry.tokens} tokens  ${c.dim}(loads when matching file accessed)${c.reset}\n`);
    }
  }

  // ── Layer 3: On-demand (skills — frontmatter only) ───────────────────────

  const skillsDir = path.join(cwd, '.claude', 'skills');
  const skillFiles = listFiles(skillsDir, '.md');
  let totalSkillFm = 0;

  if (skillFiles.length > 0) {
    process.stdout.write(`\n${c.bold}Layer 3 (On-demand):${c.reset}\n`);
    for (const f of skillFiles) {
      const content = readFile(path.join(skillsDir, f));
      const fm = extractFrontmatter(content);
      const fmTokens = fm ? estimateTokens(fm) : 0;
      totalSkillFm += fmTokens;
      process.stdout.write(`  ${pad(f, COL)} ~${fmTokens} tokens  ${c.dim}(frontmatter only in context)${c.reset}\n`);
    }
    process.stdout.write(`  ${c.dim}${skillFiles.length} skills total: ~${totalSkillFm} tokens frontmatter${c.reset}\n`);
  }

  // ── Layer 3: On-demand (agents — frontmatter only) ─────────────────────

  const agentsDirs = [
    path.join(cwd, '.claude', 'agents'),
    path.join(cwd, 'agents'),
  ];
  let agentsDir = null;
  for (const d of agentsDirs) {
    if (dirExists(d)) { agentsDir = d; break; }
  }
  const agentFiles = agentsDir ? listFiles(agentsDir, '.md') : [];
  let totalAgentFm = 0;

  if (agentFiles.length > 0) {
    process.stdout.write(`\n${c.bold}Layer 3 (On-demand — Agents):${c.reset}\n`);
    for (const f of agentFiles) {
      const content = readFile(path.join(agentsDir, f));
      const fm = extractFrontmatter(content);
      const fmTokens = fm ? estimateTokens(fm) : 0;
      totalAgentFm += fmTokens;
      process.stdout.write(`  ${pad(f, COL)} ~${fmTokens} tokens  ${c.dim}(frontmatter only in context)${c.reset}\n`);
    }
    process.stdout.write(`  ${c.dim}${agentFiles.length} agents total: ~${totalAgentFm} tokens frontmatter${c.reset}\n`);
  }

  // ── Governance: hooks (zero context cost) ────────────────────────────────

  const hooksDir = path.join(cwd, '.claude', 'hooks');
  const hookFiles = dirExists(hooksDir) ? listFiles(hooksDir) : [];

  process.stdout.write(`\n${c.bold}Governance (Zero context cost):${c.reset}\n`);
  if (hookFiles.length > 0) {
    process.stdout.write(`  ${pad(`${hookFiles.length} hooks`, COL)} 0 tokens    ${c.dim}(shell scripts, not in context)${c.reset}\n`);
  } else {
    process.stdout.write(`  ${c.dim}No hooks found${c.reset}\n`);
  }

  // ── Summary ──────────────────────────────────────────────────────────────

  const RECOMMENDED_MAX = 3000;
  const utilization = totalAlways / RECOMMENDED_MAX;

  process.stdout.write(`\n${'─'.repeat(40)}\n`);
  process.stdout.write(`${c.bold}Total always-loaded:${c.reset}  ${totalAlways} tokens\n`);
  process.stdout.write(`${c.bold}Recommended max:${c.reset}      ${formatTokens(RECOMMENDED_MAX)} tokens\n`);

  let statusIcon, statusText, statusColor;
  if (utilization <= 0.7) {
    statusIcon = PASS;
    statusText = 'HEALTHY';
    statusColor = c.green;
  } else if (utilization <= 1.0) {
    statusIcon = WARN;
    statusText = 'ELEVATED';
    statusColor = c.yellow;
  } else {
    statusIcon = FAIL;
    statusText = 'OVER BUDGET';
    statusColor = c.red;
  }

  const pct = Math.round(utilization * 100);
  process.stdout.write(`${c.bold}Status:${c.reset} ${statusIcon} ${statusColor}${statusText}${c.reset} (${pct}% utilization)\n\n`);
}

module.exports = { runBudget };
