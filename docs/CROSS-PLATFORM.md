# Cross-Platform Compatibility

cc-path is built for Claude Code. The principles transfer universally;
the file format and hook wiring do not. This guide maps each component
to the nearest equivalent in Cursor, GitHub Copilot, and Codex.

---

## What Transfers vs. What Does Not

| Component | Transfers? | Notes |
|-----------|:----------:|-------|
| Cognitive cycle (ORIENT/ANALYZE/PLAN/EXECUTE/VERIFY/LEARN) | Yes | Universal |
| Evidence hierarchy (FACT / INTERPRETATION / ASSUMPTION) | Yes | Tool-agnostic |
| 7 design principles | Yes | Format changes, methodology stays |
| Token budget concept | Yes | Every tool has a finite context window |
| `.claude/` directory structure | No | Claude Code-specific |
| `settings.json` hook wiring | No | Claude Code-specific |
| PreToolUse / PostToolUse hooks | No | Claude Code API only |
| Conditional rule loading via `paths:` | No | Claude Code-specific |
| Skill frontmatter progressive disclosure | No | Claude Code-specific |

---

## 1. Cursor

Cursor reads `.cursorrules` (or `.cursor/rules/` in newer versions) instead
of CLAUDE.md. There is no equivalent to `.claude/rules/` conditional loading
or `settings.json` hook wiring.

**Mapping: CLAUDE.md -> .cursorrules**

Copy the root CLAUDE.md content directly into `.cursorrules`. Apply the same
token discipline: cognitive cycle, design principles, safety standards -- under
80 lines. Content that belongs in conditional rules has no Cursor equivalent;
fold the most critical conventions inline and accept the rest requires manual
discipline.

**Governance without hooks**

Cursor does not support PreToolUse / PostToolUse hooks natively. Implement
governance at the git layer instead -- `.git/hooks/pre-commit` for secret
detection, `.git/hooks/pre-push` for force-push blocking. Git hooks fire
outside the model's control; a non-zero exit prevents the operation, same as
Claude Code's PreToolUse exit 2. Coverage is narrower (git operations only),
but the enforcement guarantee holds for deploy-class operations.

**What you lose**

- Circuit breaker (no mid-session failure loop protection)
- Conditional rule loading (all guidance loads unconditionally)
- Skills with progressive disclosure

---

## 2. GitHub Copilot

Copilot reads `.github/copilot-instructions.md` for repository-level guidance.
There is no hook system and no conditional loading.

**Mapping: CLAUDE.md -> copilot-instructions.md**

Copy the cognitive cycle and design principles into `.github/copilot-instructions.md`.
Keep it under 60 lines -- Copilot injects this into every completion context and
the token cost applies to every suggestion.

**Governance without hooks**

No runtime hook equivalent exists. Implement safety constraints in CI/CD:
GitHub Actions workflow rejecting PRs with secret patterns, branch protection
blocking direct pushes to main, required status checks before merge. These
enforce at the PR boundary -- weaker real-time coverage, same architectural
principle: constraints external to the model's judgment.

**What you lose**

- All runtime hook enforcement (deploy guard, circuit breaker, input sanitizer)
- Conditional loading
- Skills system

---

## 3. Codex (OpenAI)

Codex uses `AGENTS.md` for agent definitions and task-level guidance. Some
deployments also support `codex.md` for project-level instructions.

**Mapping: CLAUDE.md -> AGENTS.md**

`AGENTS.md` is oriented toward defining agents and their capabilities. Map
the cc-path agent roles (researcher / builder / reviewer) with their tool
constraints and the evidence hierarchy as inline instructions per agent.
Include the cognitive cycle as a shared instruction section.

**Hooks and sandboxing**

Codex runs in a sandboxed environment where filesystem and network access
are controlled at the infrastructure level. Deploy guard and circuit breaker
do not map directly -- work with Codex's built-in sandboxing rather than
replicating shell hooks.

**What transfers cleanly**

- Agent definitions with tool constraints
- Evidence hierarchy
- Cognitive cycle per agent

**What you lose**

- `.claude/` directory structure
- PreToolUse hooks
- Conditional rule loading

---

## 4. Generic Adaptation

For any tool not listed above:

1. **Extract the principles** -- copy the 7 design principles and cognitive
   cycle into whatever project instructions file the tool supports.
2. **Map to target format** -- rules inline or as referenced docs; skills as
   manually-invoked workflow docs; hooks as CI/CD checks or git hooks.
3. **Implement governance in CI** -- deploy guard becomes a CI validation step;
   secret detection becomes a pre-commit scanner; circuit breaker has no generic
   equivalent, document the manual reset procedure.
4. **Accept the tradeoff** -- Claude Code's PreToolUse hooks fire on every tool
   call and cannot be bypassed by the model. No other tool offers this today.
   On other platforms, governance degrades to CI-boundary enforcement. The
   principles stay the same; the coverage narrows.

The token budget concept applies everywhere. A 600-line instructions file wastes
tokens on every request regardless of platform. Design for minimum necessary
context at each layer.

---

## Sources

- Cursor documentation: cursor.com/docs (`.cursorrules` format)
- GitHub Copilot documentation: docs.github.com/en/copilot/customizing-copilot
- OpenAI Codex documentation: platform.openai.com/docs/codex (`AGENTS.md` format)
- FAQ.md: "Does cc-path work with Cursor, Windsurf, or other AI coding tools?"
- GUIDE.md Phase 3: Governance (Hooks) -- rationale for hooks over CLAUDE.md
