#!/usr/bin/env node

'use strict';

const path = require('path');

// ANSI color helpers (no external dependencies)
const color = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
};

const VERSION = require('../package.json').version;

const HELP = `
${color.bold}cc-path${color.reset} — The principled path for AI-assisted development

${color.bold}USAGE${color.reset}
  cc-path <command> [options]

${color.bold}COMMANDS${color.reset}
  doctor    Scan project harness health and score it (0-10)
  budget    Estimate token budget for context layers
  init      Initialize a cc-path harness (coming soon)

${color.bold}OPTIONS${color.reset}
  --help      Show this help message
  --version   Show version number

${color.bold}EXAMPLES${color.reset}
  ${color.dim}$ npx cc-path doctor${color.reset}
  ${color.dim}$ npx cc-path budget${color.reset}
  ${color.dim}$ npx cc-path --version${color.reset}
`;

function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command || command === '--help' || command === '-h') {
    process.stdout.write(HELP + '\n');
    process.exit(0);
  }

  if (command === '--version' || command === '-v') {
    process.stdout.write(`cc-path v${VERSION}\n`);
    process.exit(0);
  }

  const cwd = process.cwd();

  switch (command) {
    case 'doctor': {
      const { runDoctor } = require('../src/doctor');
      runDoctor(cwd);
      break;
    }
    case 'budget': {
      const { runBudget } = require('../src/budget');
      runBudget(cwd);
      break;
    }
    case 'init': {
      const { runInit } = require('../src/init');
      runInit(cwd);
      break;
    }
    default: {
      process.stderr.write(`${color.red}Unknown command: ${command}${color.reset}\n`);
      process.stderr.write(`Run ${color.bold}cc-path --help${color.reset} for usage.\n`);
      process.exit(1);
    }
  }
}

main();
