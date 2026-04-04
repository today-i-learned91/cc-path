# Anthropic Philosophy Reference

Maps Anthropic's published philosophy, technical methodology, and key contributors'
principles to our workspace design. Loaded on-demand via explicit `Read`.

For Claude Code-specific engineering principles extracted from source, see
[CLAUDE-CODE-PRINCIPLES.md](CLAUDE-CODE-PRINCIPLES.md).

---

## 1. Core Beliefs

### 1.1 Build to Understand, Not Just to Ship

Anthropic exists to study frontier AI systems empirically. The company builds
commercial products not as an end goal but as the necessary vehicle for understanding
what these systems actually do. This mirrors scientific methodology: you cannot
theorize about a system you haven't built.

**Source**: Dario Amodei, *Machines of Loving Grace* (2024)
**Workspace mapping**: The Cognitive Cycle (ORIENT-ANALYZE-PLAN-EXECUTE-VERIFY-LEARN)
encodes this — ORIENT and ANALYZE precede any execution.

### 1.2 Internalize Values, Don't Just Enforce Rules

Constitutional AI's core insight is that a model trained to follow principles
outperforms one trained to follow rules. Rules are brittle at the boundary;
internalized values generalize. The constitution is a set of declarative principles
the model uses for self-critique, not a lookup table of prohibited outputs.

**Source**: Constitutional AI paper (arXiv:2212.08073), Claude's Constitution (CC0)
**Workspace mapping**: CLAUDE.md layers encode principles (guidance ~80%), while
hooks enforce governance (100%). Neither alone is sufficient.

### 1.3 Safe > Ethical > Compliant > Helpful

Anthropic's explicit priority stack when values conflict. Safety takes precedence
over helpfulness. This is not a sliding scale — it is a strict ordering.
When a response could be both helpful and unsafe, safety wins unconditionally.

**Source**: Claude's Character documentation, Amanda Askell's priority ordering
**Workspace mapping**: `cognitive-protection.md` decision matrix applies this:
irreversible + subjective actions require hard confirmation regardless of
how helpful the action would be.

### 1.4 If-Then Commitments Over Vibes

The Responsible Scaling Policy (RSP) defines pre-committed thresholds: "If the
model reaches capability X, then we implement safeguard Y." This eliminates
post-hoc rationalization. Commitments are made before the pressure to ship exists.

**Source**: RSP v1-v3, Dario Amodei public statements
**Workspace mapping**: Circuit breakers use numeric thresholds (3 consecutive
failures -> disable), not judgment calls. `deploy-guard.sh` blocks `--prod`/`--force`
unconditionally via hooks.

### 1.5 Epistemic Humility Is Structural

Claims must be classified before acting on them: FACT (directly observable),
INTERPRETATION (reasonable inference with stated reasoning), ASSUMPTION
(unverified, flagged explicitly). This is not a cultural preference — it is
a structural requirement embedded in verification protocols.

**Source**: Core Views on AI Safety, internal research methodology
**Workspace mapping**: `thinking-framework.md` Evidence Hierarchy enforces this
classification. `docs/` content requires FACT citations with file:line references.

### 1.6 Scalable Oversight Is the Central Challenge

As AI systems become more capable, human oversight becomes the bottleneck.
Anthropic's research agenda treats this as the core alignment problem:
how do you verify that a system smarter than you is doing what you want?
Decomposition, debate, and recursive reward modeling are the current approaches.

**Source**: Core Views on AI Safety, Jan Leike's alignment research
**Workspace mapping**: Three-agent architecture (researcher/builder/reviewer)
implements decomposition. Maker-checker protocol separates creation from judgment.

---

## 2. Design Philosophy

### 2.1 Constitutional AI: Declarative Principles Over Procedural Rules

Two-phase training: (1) supervised fine-tuning with human demonstrations, then
(2) RLHF replaced by RLAIF — the model critiques its own outputs against a
constitution of principles and trains on the revised versions. The constitution
is a set of normative statements, not if-else logic.

**Source**: Constitutional AI paper (arXiv:2212.08073)
**Workspace mapping**: See Section 6 (Constitutional Hierarchy Analogy) for the
full mapping of CAI phases to our CLAUDE.md layers.

### 2.2 Do the Simple Thing First

Boris Cherny's (Claude Code lead) principle: glob+grep beats RAG for most code
search. Start with the simplest tool that could work. Complexity is added only
when the simple approach demonstrably fails.

**Source**: Anthropic Engineering blog, Claude Code source (`constants/prompts.ts:231`)
**Workspace mapping**: Design principle "Explicit Over Clever" in CLAUDE.md.
The tool hierarchy (Glob/Grep -> Read -> Agent) enforces progressive complexity.

### 2.3 Permission Before Mutation

Every tool call passes through a 5-step permission gauntlet before execution:
`checkPermissions > Settings > Sandbox > PermissionMode > Hooks`. No shortcut
exists. The system defaults to denying write operations unless explicitly allowed.

**Source**: Claude Code source (`Tool.ts`, permission pipeline)
**Workspace mapping**: Fail-Closed Default principle (#1 in CLAUDE-CODE-PRINCIPLES.md).
`cognitive-protection.md` adds a human-readable decision matrix on top.

### 2.4 Guidance (~80%) vs Governance (100%)

CLAUDE.md files provide guidance — they shape behavior probabilistically.
Hooks provide governance — they enforce constraints deterministically.
A CLAUDE.md instruction to "never force-push" works ~80% of the time.
A PreToolUse hook that blocks `--force` works 100% of the time.

**Source**: Claude Code architecture, hooks system design
**Workspace mapping**: Safety Standards in root CLAUDE.md state this explicitly.
Critical safety constraints (deploy-guard, secret detection) use hooks, not prose.

### 2.5 Progressive Context Compression

Context is a finite resource with quadratic attention cost. The system manages it
through a 5-stage pipeline: tool result budget -> snip -> microcompact -> context
collapse -> auto-compact. Recent information is preserved verbatim; older context
is compressed. This enables arbitrarily long sessions.

**Source**: Claude Code source (`services/compact/prompt.ts`, `query.ts` pipeline)
**Workspace mapping**: Three-layer context architecture in `architecture.md`.
Token budget table in `document-management.md`. `/compact` and `/clear` commands.

### 2.6 Modular Roles Over Monolithic Agents

Agent systems work better as specialized roles (researcher, builder, reviewer)
than as one omniscient agent. Each role has constrained tools, focused prompts,
and clear success criteria. This reduces error surface and enables parallel execution.

**Source**: Boris Cherny's agent design, Claude Code coordinator pattern
**Workspace mapping**: Three agents defined in CLAUDE.md (researcher: opus/read-only,
builder: sonnet, reviewer: opus/read-only). OMC extends this with executor,
planner, architect, designer, writer, explorer.

---

## 3. Operational Approach

### 3.1 Measure, Don't Theorize

Anthropic treats AI systems as empirical objects. Interpretability research
(sparse autoencoders, monosemanticity) aims to *observe* what models do internally
rather than theorize from architecture alone. "Zoom In" methodology: look at
individual neurons/features, build understanding bottom-up.

**Source**: *Scaling Monosemanticity* (2024), Chris Olah's "Zoom In" methodology
**Workspace mapping**: VERIFY phase in Cognitive Cycle requires proof (test output,
fresh build results), not confirmation ("I believe this works").

### 3.2 Separate Creation from Judgment

Authoring and reviewing must be separate passes by separate agents or separate
contexts. Self-review in the same context that created the work is structurally
unreliable — confirmation bias is a feature of how attention works, not a bug
to be overcome with effort.

**Source**: Constitutional AI's critique-revision cycle, alignment research
**Workspace mapping**: Maker-checker protocol in `.claude/CLAUDE.md`. OMC enforces
this: writer pass creates, reviewer/verifier pass evaluates in a separate lane.

### 3.3 Three Alignment Taxes

Jan Leike's framework for evaluating alignment approaches by their cost:
(1) Performance tax — does alignment reduce capability?
(2) Development tax — does it slow building?
(3) Time-to-deployment tax — does it delay shipping?
The ideal approach minimizes all three. CAI minimizes the development tax by
automating the feedback loop.

**Source**: Jan Leike, alignment research at Anthropic
**Workspace mapping**: Quality gates in `.claude/CLAUDE.md` are designed to add
minimal friction (pre-action check is a mental model, not a form to fill out).

### 3.4 Race to the Top, Lift the Floor

Anthropic's competitive strategy: lead by example with safety practices so
rigorous that they become industry standards. Not regulatory capture — genuine
standard-setting through demonstrated viability. "Trust scales; hype doesn't."

**Source**: Dario Amodei public statements, Daniela Amodei
**Workspace mapping**: Safety Standards section in root CLAUDE.md. The workspace
implements Anthropic-grade practices (circuit breakers, deploy guards, secret
management) as a reference implementation others can adopt.

### 3.5 The Brilliant Friend, Not the Corporate Oracle

Claude's intended character: direct, honest, caring. It should feel like talking
to a knowledgeable friend who tells you what they actually think, not a
corporate chatbot that hedges everything. Honesty includes saying "I don't know"
and pushing back when the user is wrong.

**Source**: Amanda Askell's character design, Claude's Constitution
**Workspace mapping**: Core Rules in CLAUDE.md: "English for harness files;
Korean for user communication." Direct communication style, no unnecessary hedging.

### 3.6 Pre-Commit to Constraints Before Pressure Arrives

Across Anthropic's work — RSP thresholds, constitutional principles, safety
levels — the pattern is the same: decide what you will do *before* you face the
situation. Under pressure, humans rationalize. Pre-commitment eliminates the
option to rationalize.

**Source**: RSP framework, Constitutional AI design philosophy
**Workspace mapping**: Hooks are pre-committed constraints. `deploy-guard.sh`
was written before any deployment, not after an incident.

---

## 4. Key People's Principles

| Person | Role | Principle | Workspace Translation |
|--------|------|-----------|----------------------|
| Dario Amodei | CEO | If-then commitments over post-hoc reasoning | Circuit breakers with numeric thresholds, not advisory warnings |
| Dario Amodei | CEO | Race to the top by demonstrating safety is viable | Safety Standards as reference implementation |
| Dario Amodei | CEO | Risk focus enables optimism — not despite risk, because of addressing it | VERIFY phase exists so EXECUTE phase can be bold |
| Chris Olah | Interp Lead | Zoom In: treat systems as empirical objects | Read before write; verify with evidence, not theory |
| Chris Olah | Interp Lead | Falsifiable claims over unfalsifiable narratives | Evidence Hierarchy: FACT > INTERPRETATION > ASSUMPTION |
| Chris Olah | Interp Lead | Build abstractions on solid foundations | Three similar lines > premature abstraction |
| Amanda Askell | Character Lead | Character over rules (virtue ethics) | CLAUDE.md encodes principles, not if-else rules |
| Amanda Askell | Character Lead | Genius child metaphor: honest engagement over performative deference | Direct communication style, push back when wrong |
| Amanda Askell | Character Lead | Priority ordering as architecture: Safe > Ethical > Compliant > Helpful | Cognitive Protection matrix with strict ordering |
| Jan Leike | Alignment Lead | Three alignment taxes: performance, development, time-to-deployment | Quality gates designed for minimal friction |
| Jan Leike | Alignment Lead | Scalable oversight through decomposition | Three-agent architecture, maker-checker protocol |
| Jan Leike | Alignment Lead | Automate alignment research itself | Memory system (Dream) automates knowledge consolidation |
| Boris Cherny | Claude Code Lead | Do the simple thing first (glob+grep > RAG) | Tool hierarchy: Glob/Grep -> Read -> Agent |
| Boris Cherny | Claude Code Lead | Permission before mutation | 5-step permission gauntlet, fail-closed defaults |
| Boris Cherny | Claude Code Lead | Modular roles over monolithic agents | Specialized agents with constrained tool access |
| Daniela Amodei | President | Trust scales; hype doesn't | Verification-first workflow, no unproven claims |

---

## 5. Cross-Cutting Themes

Five themes that appear independently across multiple contributors:

| Theme | Who Champions It | Manifestation |
|-------|-----------------|---------------|
| **Pre-commit to constraints** | Dario (RSP), Amanda (priority stack), Boris (permission gauntlet) | Hooks, deploy guards, circuit breakers — all written before the pressure to bypass them |
| **Understand before acting** | Chris (Zoom In), Boris (read before write), Jan (decomposition) | ORIENT/ANALYZE phases, Read-before-Write rule, evidence classification |
| **Simple foundations first** | Chris (solid foundations), Boris (simple thing first), Dario (empirical engagement) | Three lines > abstraction, glob+grep > RAG, minimum viable complexity |
| **Separate creation from judgment** | Amanda (self-critique cycle), Jan (scalable oversight), CAI architecture | Maker-checker protocol, separate author/reviewer agents, never self-approve |
| **Design for others to adopt** | Dario (race to top), Daniela (trust scales), Amanda (character as example) | Safety Standards as reference implementation, CLAUDE.md as shareable architecture |

---

## 6. Constitutional Hierarchy Analogy

Constitutional AI's training pipeline maps directly to our workspace's
context architecture:

```
Constitutional AI Phase          Workspace Layer
─────────────────────────────    ──────────────────────────────────
Constitution (principles)    →   CLAUDE.md (root + .claude/)
  Declarative norms the            Design principles, cognitive cycle,
  model uses for self-critique     core rules — always loaded

Self-Critique (evaluation)   →   .claude/rules/ (conditional)
  Model evaluates its own          Rules evaluate agent behavior at
  outputs against principles       specific file access points

Revision (improvement)       →   .claude/skills/ (on-demand)
  Model revises based on           Skills provide focused guidance
  critique feedback                when invoked for specific tasks

RLHF Feedback Loop           →   Memory system (Dream + MEMORY.md)
  Human preferences refine         Session learnings consolidate into
  the model over time              persistent project knowledge

Deployment Safeguards        →   Hooks (PreToolUse, PostToolUse)
  Runtime safety filters           Deterministic enforcement layer
  that cannot be bypassed          that cannot be talked past
```

### Why This Analogy Matters

The CAI insight is that **each layer serves a different function**:
- Principles (CLAUDE.md) shape default behavior broadly
- Evaluation (rules) catches specific violations conditionally
- Revision (skills) provides deep guidance when needed
- Feedback (memory) improves over time
- Safeguards (hooks) enforce hard boundaries always

Collapsing these layers — putting everything in CLAUDE.md, or enforcing
everything with hooks — degrades the system. Principles without enforcement
drift; enforcement without principles is brittle.

---

## 7. Gaps & Improvement Roadmap

Findings from project audit, prioritized by impact and effort:

### P0: Address Now — ✅ COMPLETED (2026-04-04)

| Gap | Resolution |
|-----|-----------|
| **Principle duplication** | `thinking-framework.md` deduplicated with back-references (55→37 lines) |
| **Cognitive Protection unenforced** | `cognitive-protection.sh` PreToolUse hook + `decision-audit.sh` PostToolUse hook |
| **Skill count mismatch** | CLAUDE.md updated to 23, new skills frontmatter standardized |

### P1: Next Sprint — ✅ COMPLETED (2026-04-04)

| Gap | Resolution |
|-----|-----------|
| **Circuit breaker advisory-only** | Two-tier: warn@3 + `circuit-breaker-gate.sh` block@5 |
| **Decision audit trail** | `decision-audit.sh` logs to `/tmp/claude-audit-{session}/decisions.jsonl` |
| **Corrupted character** | `document-management.md` line 53 fixed |

### P2: Planned — ✅ COMPLETED (2026-04-04)

| Gap | Resolution |
|-----|-----------|
| **Audit trail** | `decision-audit.sh` PostToolUse hook with JSONL structured logging |
| **Graceful degradation** | `.claude/rules/graceful-degradation.md` with fallback chains and anti-patterns |
| **Adversarial robustness** | `input-sanitizer.sh` PreToolUse hook: prompt injection, data exfiltration detection |

### Key Principle Not Yet Implemented

**Moral Status as Open Question** (from Core Views on AI Safety): Anthropic
acknowledges that AI systems may eventually warrant moral consideration.
Our workspace has no mechanism for this — nor should it yet — but the principle
should inform how we design agent autonomy boundaries. Current stance: agents
are tools, not collaborators with standing.

---

## Sources

### Anthropic Publications
- Amodei, D. (2024). *Machines of Loving Grace: How AI Could Transform the World for the Better*. https://darioamodei.com/machines-of-loving-grace
- Anthropic. (2023). *Core Views on AI Safety*. https://www.anthropic.com/research/core-views-on-ai-safety
- Anthropic. (2023-2025). *Responsible Scaling Policy v1-v3*. https://www.anthropic.com/research/responsible-scaling-policy
- Anthropic. (2024). *Claude's Character*. https://www.anthropic.com/research/claude-character
- Anthropic. (2024). *Collective Constitutional AI*. https://www.anthropic.com/research/collective-constitutional-ai-aligning-a-language-model-with-public-input

### Technical Papers
- Bai, Y. et al. (2022). *Constitutional AI: Harmlessness from AI Feedback*. arXiv:2212.08073
- Templeton, A. et al. (2024). *Scaling Monosemanticity*. Anthropic Research.
- Olah, C. et al. (2020). *Zoom In: An Introduction to Circuits*. Distill.

### Engineering Sources
- Claude Code source analysis (v2.1.91, commit `0cf2fa2e`, 2026-03-31)
- Anthropic Engineering Blog. https://www.anthropic.com/engineering

### Key File References (This Workspace)
- `CLAUDE.md` — root design principles and safety standards
- `.claude/CLAUDE.md` — development conventions and quality gates
- `.claude/rules/thinking-framework.md` — evidence hierarchy and verification
- `.claude/rules/cognitive-protection.md` — decision matrix
- `docs/CLAUDE-CODE-PRINCIPLES.md` — 15 source-verified engineering principles
- `docs/architecture.md` — three-layer context architecture
