'use strict';

const fs = require('fs');
const path = require('path');
const readline = require('readline');

// ── ANSI helpers ─────────────────────────────────────────────────────────────
const c = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  green: '\x1b[32m', yellow: '\x1b[33m', cyan: '\x1b[36m', red: '\x1b[31m',
};
const ok = (s) => `  ${c.green}✓${c.reset} ${s}`;

// ── Harness file map ──────────────────────────────────────────────────────────
// dest path → source path relative to harness/ root
const STANDARD_FILES = [
  ['CLAUDE.md',                              'CLAUDE.md'],
  ['.claude/CLAUDE.md',                      '.claude/CLAUDE.md'],
  ['.claude/rules/thinking-framework.md',    '.claude/rules/thinking-framework.md'],
  ['.claude/rules/graceful-degradation.md',  '.claude/rules/graceful-degradation.md'],
  ['.claude/hooks/deploy-guard.sh',          '.claude/hooks/deploy-guard.sh'],
  ['.claude/hooks/circuit-breaker.sh',       '.claude/hooks/circuit-breaker.sh'],
  ['.claude/hooks/circuit-breaker-gate.sh',  '.claude/hooks/circuit-breaker-gate.sh'],
  ['.claude/hooks/circuit-breaker-reset.sh', '.claude/hooks/circuit-breaker-reset.sh'],
];

const STRICT_EXTRA_FILES = [
  ['.claude/rules/cognitive-protection.md',  '.claude/rules/cognitive-protection.md'],
  ['.claude/hooks/cognitive-protection.sh',  '.claude/hooks/cognitive-protection.sh'],
  ['.claude/hooks/input-sanitizer.sh',       '.claude/hooks/input-sanitizer.sh'],
  ['.claude/hooks/decision-audit.sh',        '.claude/hooks/decision-audit.sh'],
];

const EXAMPLE_SKILLS = [
  ['.claude/skills/research.md',    '.claude/skills/research.md'],
  ['.claude/skills/build.md',       '.claude/skills/build.md'],
  ['.claude/skills/code-review.md', '.claude/skills/code-review.md'],
];

const HOOK_SCRIPTS = new Set([
  '.claude/hooks/deploy-guard.sh',
  '.claude/hooks/circuit-breaker.sh',
  '.claude/hooks/circuit-breaker-gate.sh',
  '.claude/hooks/circuit-breaker-reset.sh',
  '.claude/hooks/cognitive-protection.sh',
  '.claude/hooks/input-sanitizer.sh',
  '.claude/hooks/decision-audit.sh',
]);

// ── Settings.json builders ────────────────────────────────────────────────────
function buildSettings(level, projectType) {
  const formatCmd = projectType === 'python'
    ? 'FILE="$CLAUDE_TOOL_INPUT_FILE_PATH"; EXT="${FILE##*.}"; case "$EXT" in py) ruff format "$FILE" 2>/dev/null ;; esac; exit 0'
    : projectType === 'typescript'
    ? 'FILE="$CLAUDE_TOOL_INPUT_FILE_PATH"; EXT="${FILE##*.}"; case "$EXT" in js|ts|tsx|jsx) npx --no-install prettier --write "$FILE" 2>/dev/null ;; esac; exit 0'
    : 'FILE="$CLAUDE_TOOL_INPUT_FILE_PATH"; EXT="${FILE##*.}"; case "$EXT" in py) ruff format "$FILE" 2>/dev/null ;; js|ts|tsx|jsx) npx --no-install prettier --write "$FILE" 2>/dev/null ;; esac; exit 0';

  const preHooks = [
    { matcher: 'Bash', hooks: [{ type: 'command', command: '.claude/hooks/deploy-guard.sh', timeout: 5, statusMessage: 'Deploy safety check...' }] },
    { matcher: 'Bash|Edit|Write|NotebookEdit|WebFetch|mcp__*', hooks: [{ type: 'command', command: '.claude/hooks/circuit-breaker-gate.sh', timeout: 3, statusMessage: 'Checking consecutive failures...' }] },
  ];

  if (level === 'strict') {
    preHooks.push(
      { matcher: 'Bash|Edit|Write|NotebookEdit', hooks: [{ type: 'command', command: '.claude/hooks/cognitive-protection.sh', timeout: 3, statusMessage: 'Sensitive operation check...' }] },
      { matcher: 'Bash|WebFetch|mcp__*', hooks: [{ type: 'command', command: '.claude/hooks/input-sanitizer.sh', timeout: 3, statusMessage: 'Input validation...' }] }
    );
  }

  const postHooks = [
    { matcher: 'Write|Edit|MultiEdit', hooks: [{ type: 'command', command: formatCmd, timeout: 10, statusMessage: 'Formatting...' }] },
    { hooks: [{ type: 'command', command: '.claude/hooks/circuit-breaker-reset.sh', timeout: 3 }] },
  ];

  if (level === 'strict') {
    postHooks.unshift({ matcher: 'Bash|Edit|Write|NotebookEdit|WebFetch|Agent', hooks: [{ type: 'command', command: '.claude/hooks/decision-audit.sh', timeout: 3 }] });
  }

  return {
    hooks: {
      PreToolUse: preHooks,
      PostToolUse: postHooks,
      PostToolUseFailure: [{ hooks: [{ type: 'command', command: '.claude/hooks/circuit-breaker.sh', timeout: 3, statusMessage: 'Tracking failure...' }] }],
    },
  };
}

// ── Prompt helpers ────────────────────────────────────────────────────────────
function ask(rl, question) {
  return new Promise((resolve) => rl.question(question, resolve));
}

async function selectFromList(rl, label, choices) {
  process.stdout.write(`${c.cyan}?${c.reset} ${c.bold}${label}${c.reset} ${c.dim}(Use arrow keys or number)${c.reset}\n`);
  choices.forEach((ch, i) => process.stdout.write(`  ${c.dim}${i + 1})${c.reset} ${ch.label}\n`));
  process.stdout.write(`  ${c.dim}(default: 1)${c.reset}\n`);
  const answer = await ask(rl, `  Enter choice [1-${choices.length}]: `);
  const idx = parseInt(answer.trim(), 10);
  const selected = (idx >= 1 && idx <= choices.length) ? idx - 1 : 0;
  process.stdout.write(`  ${c.green}>${c.reset} ${choices[selected].label}\n\n`);
  return choices[selected].value;
}

async function confirm(rl, question, defaultYes = true) {
  const hint = defaultYes ? '(Y/n)' : '(y/N)';
  const answer = await ask(rl, `${c.cyan}?${c.reset} ${c.bold}${question}${c.reset} ${c.dim}${hint}${c.reset} `);
  const trimmed = answer.trim().toLowerCase();
  if (trimmed === '') return defaultYes;
  return trimmed === 'y' || trimmed === 'yes';
}

// ── Harness root resolution ───────────────────────────────────────────────────
function resolveHarnessRoot() {
  // Try sibling harness/ (dev scenario: package lives in cc-path/cli/)
  const sibling = path.resolve(__dirname, '../../harness');
  if (fs.existsSync(sibling)) return sibling;

  // Try adjacent harness/ next to this file
  const adjacent = path.resolve(__dirname, '../harness');
  if (fs.existsSync(adjacent)) return adjacent;

  return null;
}

// ── File writer ───────────────────────────────────────────────────────────────
async function writeFile(rl, destDir, destRel, harnessRoot, srcRel) {
  const dest = path.join(destDir, destRel);
  const destDirPath = path.dirname(dest);

  if (fs.existsSync(dest)) {
    const overwrite = await confirm(rl, `${destRel} exists. Overwrite?`, false);
    if (!overwrite) {
      process.stdout.write(`  ${c.dim}↷ Skipped ${destRel}${c.reset}\n`);
      return false;
    }
  }

  fs.mkdirSync(destDirPath, { recursive: true });

  if (harnessRoot) {
    const src = path.join(harnessRoot, srcRel);
    if (fs.existsSync(src)) {
      fs.copyFileSync(src, dest);
      return true;
    }
  }

  // Fallback: write embedded minimal stub so install never fails silently
  fs.writeFileSync(dest, `# ${path.basename(dest)}\n# cc-path harness file — populate from https://github.com/cc-path/cc-path\n`);
  return true;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function runInit(cwd) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

  process.stdout.write(`\n${c.bold}cc-path init${c.reset}\n${'='.repeat(44)}\n\n`);
  process.stdout.write(`Welcome to ${c.bold}cc-path${c.reset} — the principled path for AI-assisted development.\n\n`);

  // 1. Project directory
  const dirAnswer = await ask(rl, `${c.cyan}?${c.reset} ${c.bold}Project directory:${c.reset} ${c.dim}(.)${c.reset} `);
  const targetDir = path.resolve(cwd, dirAnswer.trim() || '.');
  process.stdout.write('\n');

  // 2. Project type
  const projectType = await selectFromList(rl, 'Project type:', [
    { label: 'general', value: 'general' },
    { label: 'python',  value: 'python' },
    { label: 'typescript', value: 'typescript' },
  ]);

  // 3. Safety level
  const safetyLevel = await selectFromList(rl, 'Safety level:', [
    { label: 'standard (deploy guard + circuit breaker)', value: 'standard' },
    { label: 'strict   (+ cognitive protection + input sanitizer + decision audit)', value: 'strict' },
  ]);

  // 4. Example skills
  const includeSkills = await confirm(rl, 'Include example skills?', true);
  process.stdout.write('\n');

  rl.close();

  // ── Collect files to write ──────────────────────────────────────────────────
  let files = [...STANDARD_FILES];
  if (safetyLevel === 'strict') files = files.concat(STRICT_EXTRA_FILES);
  if (includeSkills) files = files.concat(EXAMPLE_SKILLS);

  const harnessRoot = resolveHarnessRoot();

  process.stdout.write(`${c.bold}Setting up harness...${c.reset}\n\n`);

  const written = [];
  const rl2 = readline.createInterface({ input: process.stdin, output: process.stdout });

  for (const [destRel, srcRel] of files) {
    const didWrite = await writeFile(rl2, targetDir, destRel, harnessRoot, srcRel);
    if (didWrite) {
      process.stdout.write(ok(`Created ${destRel}`) + '\n');
      written.push(destRel);
    }
  }

  // ── Write settings.json ─────────────────────────────────────────────────────
  const settingsDest = path.join(targetDir, '.claude/settings.json');
  let writeSettings = true;
  if (fs.existsSync(settingsDest)) {
    const rl3 = readline.createInterface({ input: process.stdin, output: process.stdout });
    writeSettings = await confirm(rl3, '.claude/settings.json exists. Overwrite?', false);
    rl3.close();
  }
  if (writeSettings) {
    fs.mkdirSync(path.join(targetDir, '.claude'), { recursive: true });
    fs.writeFileSync(settingsDest, JSON.stringify(buildSettings(safetyLevel, projectType), null, 2) + '\n');
    process.stdout.write(ok('Created .claude/settings.json (hooks wired)') + '\n');
  } else {
    process.stdout.write(`  ${c.dim}↷ Skipped .claude/settings.json${c.reset}\n`);
  }

  rl2.close();

  // ── chmod +x on hook scripts ────────────────────────────────────────────────
  let chmodCount = 0;
  for (const destRel of [...written]) {
    if (HOOK_SCRIPTS.has(destRel)) {
      try {
        fs.chmodSync(path.join(targetDir, destRel), 0o755);
        chmodCount++;
      } catch (_) { /* non-fatal */ }
    }
  }
  if (chmodCount > 0) {
    process.stdout.write(ok(`Set executable permissions on ${chmodCount} hook${chmodCount > 1 ? 's' : ''}`) + '\n');
  }

  // ── Done ────────────────────────────────────────────────────────────────────
  process.stdout.write(`\n${c.green}${c.bold}Done!${c.reset} Your harness is ready.\n`);
  process.stdout.write(`
${c.bold}Next steps:${c.reset}
  1. Open your project in Claude Code
  2. Try: "push this to production" ${c.dim}→ deploy guard will block it${c.reset}
  3. Run: ${c.cyan}npx cc-path doctor${c.reset} ${c.dim}→ check your harness health${c.reset}
`);
}

module.exports = { runInit };
