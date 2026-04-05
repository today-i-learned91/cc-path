# Changelog

All notable changes to cc-path are documented here.

## [0.2.0] - 2026-04-05

### Added

- **3 advanced hooks**: rate-limiter (API call throttling), secret-scanner (hardcoded secret detection), scope-guard (file count warning)
- **5 new skills** (8 total): plan, deploy, debug, critique, decision
- **3 language-specific rules**: python.md, typescript.md, go.md with `paths:` conditional loading
- **4 documentation files**: COOKBOOK.md, FAQ.md, TROUBLESHOOTING.md, AGENT-PROTOCOLS.md
- **2 reference docs**: CROSS-PLATFORM.md (Cursor/Copilot/Codex compatibility), BENCHMARKS.md (measurement framework)
- **CI/CD workflow**: shellcheck + hook tests + CLI verification on push/PR
- **GitHub Actions publish**: Trusted Publishing with NPM_TOKEN for automated npm releases
- **Integration tests**: 34 test cases across 3 suites (pipeline, exfil, rolling window)
- **README Before/After**: token waste and secret exposure examples

### Fixed

- **Hook hardening**: cognitive-protection pipeline parsing (subshell/redirection bypass), input-sanitizer expanded to 16 exfiltration pattern categories, decision-audit per-tool rolling window
- **Security**: TOOL_NAME filesystem sanitization, /tmp directory permissions (chmod 700), destructive pattern gaps (git clean, terraform destroy, docker prune, kubectl apply)
- **Test paths**: all unit tests now reference flat layout (`hooks/`) instead of phantom `harness/.claude/hooks/`
- **init.js**: source paths updated to flat layout, resolveHarnessRoot → resolveRepoRoot
- **CLI**: VERSION now reads from package.json dynamically

### Changed

- **CLI doctor**: added hook execution test (+0.5 score) and settings.json validation (+0.5 score)
- **CLI budget**: added agent frontmatter token counting section
- **CLI init**: expanded from 3 to 8 skills, language rule selection by project type
- **harness/CLAUDE.md**: updated to 8 skills

## [0.1.0] - 2026-04-04

### Added

- Initial release
- 12 agents (4-tier Anthropic org mapping)
- 7 governance hooks (deploy-guard through decision-audit)
- 5 conditional rules (thinking-framework through graceful-degradation)
- 3 skills (research, build, code-review)
- CLI tools: doctor (health check), budget (token analyzer), init (interactive setup)
- Plugin format (.claude-plugin/ manifest)
- Docs: ANTHROPIC-PHILOSOPHY, CLAUDE-CODE-PRINCIPLES, GUIDE, WHY
- Adoption guides (OMC, Superpowers)
- Examples (python-api, typescript-webapp)
- README (EN + KO)
