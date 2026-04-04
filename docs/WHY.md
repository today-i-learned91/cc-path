# Why: Decision Rationale

Every decision in this harness traces from an Anthropic principle through
Claude Code's source architecture to a concrete implementation choice.

## Format

- **Decision**: what we chose
- **Alternatives**: what else we could have done
- **Why**: the principle that decided it
- **Source**: Anthropic paper, source file:line, or engineering blog

---

## Architecture Decisions

### Why Three Layers (Always / Conditional / On-Demand)?

**Decision**: Three loading tiers -- Layer 1 (CLAUDE.md, always), Layer 2
(rules with `paths:`, conditional), Layer 3 (skills, frontmatter-only until invoked).

**Alternatives**: (a) Single flat file, load everything. (b) Two layers, no conditional tier.

**Why**: LLMs have quadratic attention cost. Every unnecessary token degrades quality
across ALL tokens. A 600-line CLAUDE.md burns ~4K tokens before Claude reads your code.
Two layers are insufficient because skills have large bodies (30+ lines) but are invoked
rarely. Frontmatter-only loading (~70 tokens each) lets Claude know a skill exists without
paying the full body cost on every request.

**Source**: Anthropic Engineering Blog, "Building effective agents" (2025);
`getMemoryFiles` in `claudemd.ts`; `loadSkillsDir.ts` (frontmatter-only behavior)

---

### Why CLAUDE.md as Constitution, Not a Rule List?

**Decision**: Encode principles (why) instead of rules (what). The root reads
"Fail Closed, Default Safe" not "do not use rm -rf."

**Alternatives**: Do/don't instruction lists, which is how most CLAUDE.md files are written.

**Why**: Amanda Askell's Constitutional AI insight -- models trained on principles generalize
better than models trained on rules. "Don't use rm -rf" fails when the command is
`find . -delete`. "Fail Closed, Default Safe" covers both and every future variant.

**Source**: Constitutional AI (arXiv:2212.08073); Claude's Character design;
`constants/prompts.ts` -- system prompt encodes behavioral norms, not command blacklists

---

### Why Separate Guidance (~80%) from Governance (100%)?

**Decision**: CLAUDE.md = guidance (probabilistic). Hooks = governance (deterministic).
Safety-critical constraints live in hooks, not prose.

**Alternatives**: Everything in CLAUDE.md. Simpler, single source of truth.

**Why**: Under token pressure -- late in conversation, after compaction -- the model may
skip CLAUDE.md instructions. This is how attention architectures degrade under load, not
a bug. A PreToolUse hook exiting with code 2 blocks the action with 100% reliability
regardless of context state. The model cannot override it.

**Source**: Claude Code hooks documentation; Boris Cherny's permission gauntlet (`Tool.ts`);
`settings.json` -- `deploy-guard.sh` (governance) blocks `--prod`/`--force` while
CLAUDE.md (guidance) says "read before write"

---

### Why Seven Design Principles?

**Decision**: Seven: Fail Closed, Prompt Is Architecture, Progressive Compression,
Never Delegate Understanding, Data-Driven Circuit Breakers, Feature Flags as Dead
Code Elimination, Explicit Over Clever.

**Alternatives**: Fewer (too abstract) or the full 15 from CLAUDE-CODE-PRINCIPLES.md
(too many for working memory).

**Why**: 7 +/- 2 is the cognitive limit (Miller, 1956). Each maps to a concrete source
pattern. Two ("Data-Driven Circuit Breakers" and "Explicit Over Clever") are interpretations,
not direct quotes -- acknowledged honestly in CLAUDE-CODE-PRINCIPLES.md:218-221.

**Source**: `Tool.ts:748`, `coordinatorMode.ts:200-227`, `claudemd.ts`,
`constants/prompts.ts:201-203`

---

### Why Three Circuit Breaker Scripts, Not One?

**Decision**: `circuit-breaker.sh` (track, PostToolUseFailure) +
`circuit-breaker-gate.sh` (block, PreToolUse) +
`circuit-breaker-reset.sh` (reset, PostToolUse).

**Alternatives**: Single script that branches on which hook type invoked it.

**Why**: Claude Code's hook architecture enforces this. PostToolUseFailure can only inject
context (advisory). PreToolUse can block (exit 2 = deny). PostToolUse handles cleanup.
A single script detecting its invocation context violates "Explicit Over Clever." Each
script has one job and one hook binding.

**Source**: `autoCompact.ts:67-70` (failure tracking/reset as separate functions);
`settings.json` lines 3-93 (three scripts bound to three hook types)

---

### Why Two-Tier Circuit Breaker (Warn at 3, Block at 5)?

**Decision**: Warn at 3 consecutive failures via `additionalContext`. Block at 5 via exit 2.

**Alternatives**: (a) Block at 3 (too aggressive). (b) Warn-only (advisory, fails under
pressure). (c) Single threshold.

**Why**: Warn tier gives the model a chance to self-correct ("Diagnose Before Retrying,"
principle #7). Block tier provides a hard stop when self-correction fails ("Fail Closed").
Threshold of 3 comes from Claude Code's `MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3`.
Doubled to 5 for blocking because halting all tool use is severe.

**Source**: `autoCompact.ts:67-70`; Anthropic RSP (graduated response);
`circuit-breaker.sh` lines 11-12

---

### Why Conditional Loading with `paths:` Frontmatter?

**Decision**: Rules that apply only to specific files use `paths:` so they load
only when those files are accessed.

**Alternatives**: Load all rules always. Simpler.

**Why**: "Feature Flags as Dead Code Elimination." A rule for `.claude/` files loaded
during Python debugging wastes ~100 tokens and adds cognitive noise. Claude Code
natively supports `paths:` in rules frontmatter; using it costs nothing.

**Source**: Rules loading logic in Claude Code; Anthropic Engineering Blog:
"Find the smallest set of high-signal tokens that maximize the likelihood
of your desired outcome"

---

### Why Skills Have `allowed-tools` and `model` Fields?

**Decision**: Each skill declares its tool set and model. Research: opus, read tools +
web. Build: sonnet, read-write tools. Code-review: opus, read-only -- no Write access.

**Alternatives**: Every skill uses all tools with the default model.

**Why**: "Fail Closed, Default Safe." A code-review skill with Write access can modify
the code it reviews. Without constraints the default is "allow everything" -- fail-open.
Each skill encodes least privilege: minimum capability needed for the job.

**Source**: `Tool.ts:748-755` (fail-closed defaults); harness `research.md`, `build.md`,
`code-review.md`

---

### Why Token Budget Limits?

**Decision**: CLAUDE.md = 80 lines/4KB. Rules = 30 lines/1.5KB each. Docs = 800 lines/40KB.

**Alternatives**: No limits. Trust authors to be concise.

**Why**: More context does not equal better results. Beyond a point, additional tokens
actively degrade performance by diluting attention. Concrete limits force prioritization.
A rule that cannot fit in 30 lines covers too many concerns and should be split.

**Source**: Anthropic Engineering Blog on context engineering; Claude Code
`MAX_ENTRYPOINT_LINES` (200) and `MAX_MEMORY_CHARACTER_COUNT` (40,000) in `claudemd.ts`

---

### Why Evidence Hierarchy (FACT / INTERPRETATION / ASSUMPTION)?

**Decision**: Every claim must be classified as FACT, INTERPRETATION, or ASSUMPTION.

**Alternatives**: Trust model judgment without classification. Faster.

**Why**: Anthropic Core Views on AI Safety: "No one knows how to train very powerful AI
systems to be robustly helpful, honest, and harmless." If Anthropic acknowledges this
uncertainty, treating model outputs as trustworthy by default is building on sand.
Epistemic humility must be structural, not performative.

**Source**: Anthropic Core Views on AI Safety; Chris Olah's interpretability research
("Zoom In" -- understand by observation); Claude's Constitution (honesty as core value)

---

### Why the Cognitive Protection Matrix (2x2)?

**Decision**: Classify actions on Reversible/Irreversible x Objective/Subjective.
Apply graduated friction: auto-pass, soft confirm, hard confirm.

**Alternatives**: Binary "dangerous = confirm, safe = proceed."

**Why**: Formatting code (reversible, objective) needs zero friction -- confirming it
trains users to click "yes" reflexively. Deploying to production (irreversible, subjective)
needs explicit approval. Binary systems either over-confirm (alert fatigue) or under-confirm
(miss edge cases). The 2x2 mirrors Anthropic's RSP, where ASL levels apply graduated
safeguards proportional to capability -- not a single on/off switch.

**Source**: RSP framework (ASL-1 through ASL-4); `constants/prompts.ts:256-266`
(reversibility-aware actions); `cognitive-protection.md` and `cognitive-protection.sh`

---

### Why Escalation Triggers Override the Matrix?

**Decision**: Auth, payments, PII, and batch operations (10+ files) always trigger
hard confirm regardless of matrix position.

**Alternatives**: Let the matrix handle everything uniformly.

**Why**: Amanda Askell's priority ordering: Safe > Ethical > Compliant > Helpful. A
"reversible" auth change that leaks a token is not reversible in any meaningful sense.
The escalation triggers encode domain knowledge the matrix's two axes cannot capture.

**Source**: Claude's Character priority ordering; `cognitive-protection.sh` lines 21-32
(SENSITIVE_PATTERNS regex)

---

### Why a Decision Audit Trail?

**Decision**: Log every mutation tool use to JSONL. Use the log to detect repeated
delegation (AI Dependency Check: flag after 3+ consecutive same-tool calls).

**Alternatives**: No logging. Trust model, review outputs manually.

**Why**: You cannot improve what you cannot observe. The audit trail enables post-hoc
review and catches runaway loops where the model makes changes without human oversight,
directly implementing "Scalable Oversight."

**Source**: Chris Olah's interpretability research; `decision-audit.sh` lines 17-29;
`cognitive-protection.md` AI Dependency Check

---

### Why an Input Sanitizer?

**Decision**: PreToolUse hook detecting system prompt overrides, hidden instruction
injection in MCP/WebFetch results, and data exfiltration attempts.

**Alternatives**: Rely entirely on Claude's built-in safety training.

**Why**: Defense in depth. MCP tool results and WebFetch responses can contain adversarial
content crafted to manipulate the model. The sanitizer adds a deterministic layer that
does not depend on the model recognizing the attack. It flags (`decision: ask`) rather
than blocks -- false positives on legitimate content are likely, so the user decides.

**Source**: "Fail Closed, Default Safe"; `input-sanitizer.sh` (three pattern categories);
`settings.json` matcher `Bash|WebFetch|mcp__*` (external-facing tools only)

---

### Why Deploy Guard Separate from Cognitive Protection?

**Decision**: `deploy-guard.sh` handles deployment patterns (exit 2 = hard deny).
`cognitive-protection.sh` handles sensitive data (decision: ask = user override).

**Alternatives**: Merge into a single safety gate.

**Why**: Different risk profiles require different responses. Production deployments should
never happen through an AI tool call (hard deny). Sensitive data operations are sometimes
legitimate (soft deny). The partial pattern overlap (`--force`, `--prod`) is intentional
defense in depth.

**Source**: `deploy-guard.sh` (exit 2); `cognitive-protection.sh` (decision: ask);
`settings.json` matchers (Bash-only vs Bash|Edit|Write|NotebookEdit)

---

### Why Graceful Degradation as a Rule, Not a Hook?

**Decision**: Fallback guidance in `.claude/rules/graceful-degradation.md`, not a hook.

**Alternatives**: PostToolUseFailure hooks that automatically retry with alternative tools.

**Why**: Fallback decisions are contextual and subjective. A hook that substitutes `Grep`
for `knowledge_search` might miss the semantic intent. This is guidance (~80%), not
governance (100%). The rule provides a fallback table; the model applies judgment.

**Source**: Guidance vs governance split; `graceful-degradation.md`; Boris Cherny's
"do the simple thing first" -- fall back to simpler tools, not more complex ones

---

### Why Three Agents (Researcher / Builder / Reviewer)?

**Decision**: Researcher (opus, read-only), builder (sonnet, read-write),
reviewer (opus, read-only).

**Alternatives**: (a) One omniscient agent. (b) Many fine-grained roles.

**Why**: Maps to Maker-Checker: builder creates, reviewer evaluates, researcher gathers
context. Reviewer is read-only because its judgment is compromised if it can fix the
issues it finds. More than three roles adds coordination overhead exceeding specialization
benefits for most projects.

**Source**: Coordinator pattern in `coordinatorMode.ts`; CAI critique-revision cycle;
Jan Leike's scalable oversight through decomposition

---

### Why Conventional Commits?

**Decision**: Enforce `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:` prefixes.

**Alternatives**: Freeform messages. Less friction.

**Why**: Machine-parseable history. When an agent reads `git log`, a conventional commit
tells it the category of change without reading the diff. Progressive Compression applied
to version history: maximum signal in minimum tokens.

**Source**: Conventional Commits specification; `constants/prompts.ts`;
`.claude/CLAUDE.md` Git Protocol section

---

## Meta-Decision: Why Document Decisions at All?

Anthropic's philosophy is empirical: measure, record, improve. A harness without
documented rationale is a black box -- it works until it doesn't, and nobody knows
why it was built that way or whether the original reasoning still holds.

Every design decision has a half-life. Without recorded rationale, you cannot
distinguish "deliberate choice" from "accident that nobody questioned."

This document is the interpretability layer for the harness itself.

**Source**: Chris Olah's interpretability research; Anthropic Core Views on AI Safety
