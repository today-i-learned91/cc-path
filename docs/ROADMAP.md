# cc-path Roadmap

> Last updated: 2026-04-05
> Current version: 0.1.0

---

## Completed (v0.1.0)

- [x] 12 agents (4-tier Anthropic org mapping)
- [x] 7 governance hooks (English, deploy-guard through decision-audit)
- [x] 5 conditional rules (thinking-framework through graceful-degradation)
- [x] 3 skills (research, build, code-review)
- [x] CLI tools (doctor, budget, init)
- [x] 66 hook tests (5 suites)
- [x] Plugin format (.claude-plugin/ manifest)
- [x] Docs: ANTHROPIC-PHILOSOPHY, CLAUDE-CODE-PRINCIPLES, GUIDE, WHY
- [x] Adoption guides (OMC, Superpowers)
- [x] Examples (python-api, typescript-webapp)
- [x] README (EN + KO) with Before/After, Quick Install
- [x] CONTRIBUTING.md
- [x] GitHub repo live

## Completed (v0.2.0 — 2026-04-05)

- [x] Hook hardening: cognitive-protection.sh pipeline parsing (subshell, redirection, echo removal)
- [x] Hook hardening: input-sanitizer.sh expanded exfiltration (16 pattern categories)
- [x] Hook hardening: decision-audit.sh per-tool rolling window (replaced tail-5)
- [x] Security review: Critical/High findings fixed (subshell bypass, redirection bypass, TOOL_NAME sanitization)
- [x] 5 new skills: plan, deploy, debug, critique, decision (3 → 8 total)
- [x] Integration tests: 3 suites (pipeline, exfil, rolling window) + run-all.sh updated
- [x] npm publish prep: package.json hardened, VERSION dynamic, GitHub Actions workflow
- [x] Decision-audit TOOL_NAME sanitization (path traversal prevention)

---

## P0 — Completed (2026-04-05)

All P0 items shipped. See "Completed (v0.2.0)" above.

### Remaining from Security Review (Medium/Low)

| # | Severity | Issue | Status |
|---|----------|-------|--------|
| 5 | Medium | Race condition on counter files (concurrent hooks) | Deferred — low real-world impact |
| 7 | Medium | sed pipe splitting breaks regex in grep args | Known limitation — document |
| 8 | Medium | Prompt injection evasion via Unicode/encoding | Defense-in-depth accepted |
| 9 | Low | /tmp state files world-readable | P1 |
| 10 | Low | Inconsistent JSON parsing (jq vs raw grep) | P2 |
| 11 | Low | Destructive pattern list gaps (terraform, docker) | P1 |

### npm Publish (manual step remaining)

- [x] package.json hardened (type, publishConfig, prepublishOnly)
- [x] VERSION dynamic loading from package.json
- [x] GitHub Actions workflow (Trusted Publishing / OIDC)
- [ ] `npm publish --access public` from `cli/` (interactive 2FA)
- [ ] Configure Trusted Publisher on npmjs.com
- [ ] Verify `npx cc-path doctor` works

---

## P1 — This Week

### Language-Specific Conditional Rules

| Rule | `paths:` trigger | Content |
|------|-----------------|---------|
| `rules/python.md` | `*.py` | PEP 8, type hints, virtual env, ruff |
| `rules/typescript.md` | `*.ts, *.tsx` | Strict mode, ESLint, Prettier, barrel exports |
| `rules/go.md` | `*.go` | gofmt, error handling, interface patterns |

### CLI Improvements

| Feature | Current | Target |
|---------|---------|--------|
| `doctor.js` | File existence check | + hook execution test, settings.json validation |
| `budget.js` | Char-based estimation | + skill/agent frontmatter token counting |
| `init.js` | File copy | + plugin install command option |

### Community Launch

- [ ] Submit PR to [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)
- [ ] Post on Claude Code Discord/community
- [ ] Consider dev.to article (standalone, not the removed blog drafts)

---

## P2 — This Month

### Agent Enhancements

- [ ] Agent interaction protocol doc (`docs/AGENT-PROTOCOLS.md`)
- [ ] Maker-checker matrix visualization
- [ ] Agent selection guide based on task complexity
- [ ] Orchestration examples with real task scenarios

### Advanced Hooks

- [ ] `rate-limiter.sh` — prevent excessive API calls
- [ ] `secret-scanner.sh` — detect hardcoded secrets before commit
- [ ] `scope-guard.sh` — warn when changes exceed N files

### Documentation

- [ ] `docs/COOKBOOK.md` — common recipes and patterns
- [ ] `docs/FAQ.md` — frequently asked questions
- [ ] `docs/TROUBLESHOOTING.md` — common issues and fixes
- [ ] Architecture SVG diagram for README

### Testing

- [ ] CI/CD with GitHub Actions (shellcheck + hook tests)
- [ ] CLI unit tests (Node.js test runner)
- [ ] Integration test: install plugin → run doctor → verify score

---

## P3 — Future

### TUI Dashboard
- Interactive terminal UI for harness management
- Agent on/off toggles, hook log viewer, token budget bars
- Depends on adoption metrics justifying the investment

### Cross-Platform Support
- Cursor compatibility guide
- Codex compatibility guide
- Generic AI coding assistant adaptation

### Benchmarks
- Measure instruction-following rate with/without cc-path
- Token efficiency comparison
- Before/after case studies with real projects

### i18n
- Japanese README
- Chinese README
- Spanish README

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-04 | Plugin format over npm-only | Bypasses 2FA, native Claude Code integration |
| 2026-04-04 | 12 agents, not 8 or 16 | Anthropic org mapping + 7±2 cognitive limit per task |
| 2026-04-04 | Remove blog from repo | Better suited for external publication |
| 2026-04-04 | Remove competitive comparison | Other maintainers not consulted |
| 2026-04-04 | "structural analogy" not "not a metaphor" | Accuracy per Anthropic researcher feedback |
| 2026-04-04 | Hook messages in English | Global audience, project declares English-only |
| 2026-04-04 | Zero external dependencies for CLI | Matches "do the simple thing first" principle |
