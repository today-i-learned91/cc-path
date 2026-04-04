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

// ── Utility functions ────────────────────────────────────────────────────────

function fileExists(fp) {
  try { return fs.statSync(fp).isFile(); } catch { return false; }
}

function dirExists(dp) {
  try { return fs.statSync(dp).isDirectory(); } catch { return false; }
}

function countLines(fp) {
  try { return fs.readFileSync(fp, 'utf8').split('\n').length; } catch { return 0; }
}

function listFiles(dp, ext) {
  try {
    return fs.readdirSync(dp).filter((f) => {
      if (ext && !f.endsWith(ext)) return false;
      return fs.statSync(path.join(dp, f)).isFile();
    });
  } catch { return []; }
}

function hasFrontmatterKey(fp, key) {
  try {
    const content = fs.readFileSync(fp, 'utf8');
    const fmMatch = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
    if (!fmMatch) return false;
    const re = new RegExp(`^${key}\\s*:`, 'm');
    return re.test(fmMatch[1]);
  } catch { return false; }
}

function isExecutable(fp) {
  try {
    fs.accessSync(fp, fs.constants.X_OK);
    return true;
  } catch { return false; }
}

function pad(label, width) {
  const dots = Math.max(2, width - label.length);
  return label + ' ' + '.'.repeat(dots);
}

// ── Check functions ──────────────────────────────────────────────────────────

function checkClaudeMd(cwd, issues) {
  const fp = path.join(cwd, 'CLAUDE.md');
  let score = 0;
  const exists = fileExists(fp);
  const lines = exists ? countLines(fp) : 0;

  if (exists) {
    score += 1.0;
    if (lines <= 80) {
      score += 0.5;
    } else {
      issues.push({ level: 'WARNING', msg: `CLAUDE.md: ${lines} lines exceeds recommended 80 lines` });
    }
  } else {
    issues.push({ level: 'ERROR', msg: 'CLAUDE.md not found — this is your primary harness file' });
  }

  let status;
  if (!exists) status = `${FAIL} NOT FOUND`;
  else if (lines > 80) status = `FOUND (${lines} lines) ${WARN} exceeds 80-line budget`;
  else status = `FOUND (${lines} lines) ${PASS}`;

  return { label: 'CLAUDE.md', status, score };
}

function checkDotClaudeMd(cwd, issues) {
  const fp = path.join(cwd, '.claude', 'CLAUDE.md');
  let score = 0;
  const exists = fileExists(fp);
  const lines = exists ? countLines(fp) : 0;

  if (exists) {
    score += 1.0;
    if (lines > 60) {
      issues.push({ level: 'WARNING', msg: `.claude/CLAUDE.md: ${lines} lines exceeds recommended 60 lines` });
    }
  }

  let status;
  if (!exists) status = `${FAIL} NOT FOUND`;
  else if (lines > 60) status = `FOUND (${lines} lines) ${WARN} exceeds 60-line budget`;
  else status = `FOUND (${lines} lines) ${PASS}`;

  return { label: '.claude/CLAUDE.md', status, score };
}

function checkRules(cwd, issues) {
  const dir = path.join(cwd, '.claude', 'rules');
  const files = listFiles(dir, '.md');
  let score = 0;
  let conditional = 0;
  let unconditional = 0;

  if (files.length >= 1) {
    score += 1.0;
  }

  for (const f of files) {
    if (hasFrontmatterKey(path.join(dir, f), 'paths')) {
      conditional++;
    } else {
      unconditional++;
    }
  }

  if (conditional > 0) {
    score += 0.5;
  } else if (files.length > 0) {
    issues.push({ level: 'INFO', msg: `${unconditional} unconditional rules \u2014 consider adding paths: frontmatter` });
  }

  let status;
  if (files.length === 0) status = `${FAIL} NONE`;
  else status = `${files.length} rules (${conditional} conditional, ${unconditional} unconditional) ${PASS}`;

  return { label: '.claude/rules/', status, score };
}

function checkHooks(cwd, issues) {
  const dir = path.join(cwd, '.claude', 'hooks');
  const files = listFiles(dir);
  let score = 0;
  let execCount = 0;
  let hasDeployGuard = false;
  let hasCircuitBreaker = false;

  for (const f of files) {
    const fp = path.join(dir, f);
    if (isExecutable(fp)) execCount++;
    const lower = f.toLowerCase();
    if (lower.includes('deploy') && lower.includes('guard')) hasDeployGuard = true;
    if (lower.includes('circuit') && lower.includes('breaker')) hasCircuitBreaker = true;

    // Also check file content for patterns
    try {
      const content = fs.readFileSync(fp, 'utf8').toLowerCase();
      if (content.includes('deploy') && content.includes('guard')) hasDeployGuard = true;
      if (content.includes('circuit') && content.includes('breaker')) hasCircuitBreaker = true;
    } catch { /* ignore */ }
  }

  if (files.length >= 1) score += 2.0;
  if (hasDeployGuard) score += 1.0;
  if (hasCircuitBreaker) score += 1.0;

  if (files.length > 0 && execCount < files.length) {
    const nonExec = files.length - execCount;
    issues.push({ level: 'WARNING', msg: `${nonExec} hook(s) missing executable permission` });
  }
  if (files.length > 0 && !hasDeployGuard) {
    issues.push({ level: 'INFO', msg: 'No deploy-guard hook detected (+1.0 potential)' });
  }
  if (files.length > 0 && !hasCircuitBreaker) {
    issues.push({ level: 'INFO', msg: 'No circuit-breaker hook detected (+1.0 potential)' });
  }

  let status;
  if (files.length === 0) status = `${FAIL} NONE`;
  else status = `${files.length} hooks ${PASS}`;

  return { label: '.claude/hooks/', status, score };
}

function checkSkills(cwd, issues) {
  const dir = path.join(cwd, '.claude', 'skills');
  const files = listFiles(dir, '.md');
  let score = 0;
  let wellFormed = 0;

  if (files.length >= 1) score += 0.5;

  for (const f of files) {
    const fp = path.join(dir, f);
    const hasModel = hasFrontmatterKey(fp, 'model');
    const hasTools = hasFrontmatterKey(fp, 'allowed-tools') || hasFrontmatterKey(fp, 'allowed_tools');
    if (hasModel && hasTools) wellFormed++;
  }

  if (files.length > 0 && wellFormed === files.length) {
    score += 0.5;
  } else if (files.length > 0 && wellFormed < files.length) {
    const missing = files.length - wellFormed;
    issues.push({ level: 'INFO', msg: `${missing} skill(s) missing allowed-tools or model in frontmatter` });
  }

  let status;
  if (files.length === 0) status = `${c.dim}NONE${c.reset}`;
  else if (wellFormed === files.length) status = `${files.length} skills ${PASS}`;
  else status = `${files.length} skills ${WARN} (${wellFormed}/${files.length} well-formed)`;

  return { label: '.claude/skills/', status, score };
}

function checkSettings(cwd, issues) {
  const fp = path.join(cwd, '.claude', 'settings.json');
  let score = 0;
  const exists = fileExists(fp);
  let hooksWired = false;

  if (exists) {
    try {
      const content = fs.readFileSync(fp, 'utf8');
      const json = JSON.parse(content);
      if (json.hooks && Object.keys(json.hooks).length > 0) {
        hooksWired = true;
        score += 1.0;
      }
    } catch {
      issues.push({ level: 'WARNING', msg: 'settings.json exists but failed to parse' });
    }
  }

  let status;
  if (!exists) status = `${c.dim}NOT FOUND${c.reset}`;
  else if (hooksWired) status = `FOUND (hooks wired) ${PASS}`;
  else status = `FOUND (no hooks wired) ${WARN}`;

  return { label: '.claude/settings.json', status, score };
}

// ── Main ─────────────────────────────────────────────────────────────────────

function runDoctor(cwd) {
  process.stdout.write(`\n${c.bold}cc-path doctor${c.reset}\n`);
  process.stdout.write('==============\n\n');
  process.stdout.write(`Scanning ${c.cyan}${cwd}${c.reset}...\n\n`);

  const issues = [];
  const COL = 30;

  const checks = [
    checkClaudeMd(cwd, issues),
    checkDotClaudeMd(cwd, issues),
    checkRules(cwd, issues),
    checkHooks(cwd, issues),
    checkSkills(cwd, issues),
    checkSettings(cwd, issues),
  ];

  let total = 0;
  for (const check of checks) {
    process.stdout.write(`  ${pad(check.label, COL)} ${check.status}\n`);
    total += check.score;
  }

  // Cap at 10
  total = Math.min(total, 10);

  const scoreColor = total >= 8 ? c.green : total >= 5 ? c.yellow : c.red;
  process.stdout.write(`\n${c.bold}Score: ${scoreColor}${total.toFixed(1)}/10${c.reset}\n`);

  // Print issues
  const errors = issues.filter((i) => i.level === 'ERROR');
  const warnings = issues.filter((i) => i.level === 'WARNING');
  const infos = issues.filter((i) => i.level === 'INFO');

  if (issues.length > 0) {
    process.stdout.write(`\n${c.bold}Issues:${c.reset}\n`);
    for (const issue of [...errors, ...warnings, ...infos]) {
      const tag = issue.level === 'ERROR' ? `${c.red}[ERROR]${c.reset}`
        : issue.level === 'WARNING' ? `${c.yellow}[WARNING]${c.reset}`
        : `${c.dim}[INFO]${c.reset}   `;
      process.stdout.write(`  ${tag} ${issue.msg}\n`);
    }
  }

  // Recommendations
  const recs = [];
  if (issues.some((i) => i.msg.includes('CLAUDE.md') && i.msg.includes('80 lines'))) {
    recs.push('Trim CLAUDE.md to 80 lines (+0.5 points)');
  }
  if (issues.some((i) => i.msg.includes('.claude/CLAUDE.md') && i.msg.includes('60 lines'))) {
    recs.push('Trim .claude/CLAUDE.md to 60 lines');
  }
  if (issues.some((i) => i.msg.includes('unconditional rules'))) {
    recs.push('Add paths: frontmatter to unconditional rules (+0.5 points)');
  }
  if (issues.some((i) => i.msg.includes('deploy-guard'))) {
    recs.push('Add a deploy-guard hook (+1.0 points)');
  }
  if (issues.some((i) => i.msg.includes('circuit-breaker'))) {
    recs.push('Add a circuit-breaker hook (+1.0 points)');
  }
  if (issues.some((i) => i.msg.includes('executable permission'))) {
    recs.push('Fix hook permissions: chmod +x .claude/hooks/*');
  }
  if (issues.some((i) => i.msg.includes('allowed-tools or model'))) {
    recs.push('Add allowed-tools and model to skill frontmatter (+0.5 points)');
  }
  if (!fileExists(path.join(cwd, 'CLAUDE.md'))) {
    recs.push('Create a CLAUDE.md at project root (+1.5 points)');
  }

  if (recs.length > 0) {
    process.stdout.write(`\n${c.bold}Recommendations:${c.reset}\n`);
    recs.forEach((r, i) => {
      process.stdout.write(`  ${i + 1}. ${r}\n`);
    });
  }

  process.stdout.write('\n');
}

module.exports = { runDoctor };
