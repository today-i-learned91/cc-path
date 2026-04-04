# cc-path

**Philosophy as Architecture** -- the principled approach to AI coding assistant workspaces.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> "We want Claude to be genuinely helpful to the humans it works with, as well as to society at large, while avoiding actions that are unsafe or unethical. We want Claude to have good values and be a good AI assistant, in the same way that a person can have good values while also being good at their job."
>
> -- Anthropic, *Claude's Character* (2024)

---

## The Problem

Most CLAUDE.md files are cargo-culted. People copy prompt snippets from blog posts, bolt on rules until the file hits 500 lines, and wonder why Claude ignores half of it.

The failure modes are predictable:

- **No separation of guidance vs governance.** Everything lives in CLAUDE.md -- suggestions and hard rules alike -- so nothing is reliably enforced.
- **No principled basis.** Configuration is vibes-driven. Why this rule? Why this structure? Nobody can trace a design decision back to *why it works*.
- **Token waste from unstructured loading.** Every rule loads on every request. A 600-line CLAUDE.md burns ~4K tokens before Claude reads a single line of your code.
- **Copy-paste without understanding.** The rule says "read before write" but the author doesn't know it derives from Chris Olah's interpretability research and is a core principle in Anthropic's engineering methodology.

There is a better way.

## The Solution

**Harness Engineering** is a systems discipline for designing AI coding assistant workspaces. Like DevOps transformed deployment from artisanal SSH sessions into reproducible infrastructure, Harness Engineering transforms CLAUDE.md from a prompt dump into a principled architecture.

The core insight: Anthropic already published the philosophy. The Claude Code team already shared the engineering principles. This project connects the two -- tracing every design decision from Anthropic's published papers and engineering blog to practical workspace mechanism.

What you get is not a template. It is a *reference implementation* with citations.

## Quick Install

```bash
# One-line setup
curl -fsSL https://raw.githubusercontent.com/today-i-learned91/cc-path/main/setup.sh | bash

# Or clone and copy manually
git clone https://github.com/today-i-learned91/cc-path.git
cp -r cc-path/harness/.claude your-project/
cp cc-path/harness/CLAUDE.md your-project/
```

## Architecture

The harness uses a three-layer context system with a separate governance plane:

```
                        TOKEN BUDGET
                        ============
Layer 1: Always         CLAUDE.md + .claude/CLAUDE.md        ~2-3K tokens
         (Constitution) Design principles, cognitive cycle,
                        safety standards -- loaded every request

Layer 2: Conditional    .claude/rules/*.md (with paths:)     0 tokens until triggered
         (Case Law)     Thinking framework, cognitive
                        protection -- loaded when relevant
                        files are accessed

Layer 3: On-demand      .claude/skills/*.md                  ~70 tokens each (frontmatter)
         (Playbooks)    Workflows, templates -- only
                        frontmatter in context, body
                        loaded on invocation

Layer G: Governance     .claude/hooks/                       0 context tokens
         (Enforcement)  deploy-guard, circuit-breaker,
                        input-sanitizer -- 100% enforcement
                        via PreToolUse/PostToolUse hooks
```

This is not an arbitrary design. It maps directly to Claude Code's internal loading order (`getMemoryFiles` in `claudemd.ts`):

```
Managed -> User -> Project (root->CWD) -> Local -> AutoMem
```

Later layers override earlier ones. Sub-project CLAUDE.md overrides parent. The architecture makes this explicit.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/ziho/cc-path.git
cd cc-path

# Copy the harness into your project
cp harness/CLAUDE.md your-project/CLAUDE.md
cp -r harness/.claude your-project/.claude

# That's it. Your project now has:
# - 7 design principles traced from Anthropic's source code
# - Safety hooks (deploy guard, circuit breaker)
# - Cognitive protection decision matrix
# - Three-layer context architecture with measured token budgets
# - Evidence hierarchy for claim classification
```

Customize from there. The harness is a starting point, not a straitjacket.

## Core Principles

Seven engineering principles extracted from Claude Code's source code. Each one is traceable to a specific implementation decision in the codebase.

| # | Principle | Source | What It Means |
|---|-----------|--------|---------------|
| 1 | **Fail Closed, Default Safe** | `Tool.ts:748` | When uncertain, default to restrictive. Assume operations are NOT safe unless proven otherwise. |
| 2 | **Prompt Is Architecture** | `claudemd.ts` (loading order) | CLAUDE.md layers are not prompts -- they encode system behavior with defined override semantics. |
| 3 | **Progressive Compression** | `getMemoryFiles` in `claudemd.ts` | Three-layer context (always / conditional / on-demand) with measured token budgets per layer. |
| 4 | **Never Delegate Understanding** | `coordinatorMode.ts:255-268` | Prove comprehension with file:line references before delegating. No "based on your findings, fix it." |
| 5 | **Verification = Proof, Not Confirmation** | `coordinatorMode.ts:220-227` | Run tests with the feature enabled. Investigate errors -- don't dismiss as "unrelated." Be skeptical. |
| 6 | **Data-Driven Circuit Breakers** | `PreToolUse` hook chain | Thresholds from measurement, not intuition. Three consecutive failures disable, not arbitrary limits. |
| 7 | **Explicit Over Clever** | `coordinatorMode.ts:200-209` | No implicit dependencies. No magic. Each sub-problem self-contained with clear input/output/criteria. |

## The Guidance vs Governance Split

This is the insight that separates harness engineering from prompt engineering:

```
CLAUDE.md  = Guidance  (~80%)    "You should read before you write"
                                  Claude follows this most of the time.
                                  Flexible. Contextual. Overridable.

Hooks      = Governance (100%)   "You cannot deploy with --force"
                                  Enforced by PreToolUse/PostToolUse.
                                  No exceptions. No context cost.
                                  The safety net that never breaks.
```

Source: this separation mirrors Anthropic's Constitutional AI structure -- principles (guidance) combined with RLHF constraints (governance). In Claude Code, `settings.json` hooks execute *before* the model sees the tool call. The model cannot override them.

## Philosophy Layer

The harness traces its design to five threads of Anthropic's published thinking:

| Thinker | Work | Harness Mechanism |
|---------|------|-------------------|
| **Dario Amodei** | *Machines of Loving Grace* (2024) | Cognitive Cycle (ORIENT-ANALYZE-PLAN-EXECUTE-VERIFY-LEARN) -- AI as amplifier of human judgment, not replacement |
| **Amanda Askell** | *Claude's Character* (2024) | Character over rules -- the harness encodes *values* (verify before claim, read before write) not just instructions |
| **Chris Olah** | *Zoom In* (Distill, 2020) | "Read before write" principle -- understand the system before modifying it, derived from interpretability research |
| **Boris Cherny** | Claude Code engineering | "Do the simple thing first" -- Glob+Grep over RAG, direct file reads over embeddings, composition over abstraction |
| **Jan Leike** | Alignment research | Minimal-friction safety -- hooks enforce without burdening the developer or consuming context tokens |

The full mapping lives in [`docs/ANTHROPIC-PHILOSOPHY.md`](docs/ANTHROPIC-PHILOSOPHY.md).

## Constitutional AI Analogy

The CLAUDE.md hierarchy *is* a constitution:

```
Constitution (CLAUDE.md)
    Principles that govern all behavior.
    "Fail closed. Read before write. Verify before claim."
        |
        v
Case Law (.claude/rules/)
    Specific applications of principles to contexts.
    "When touching auth code, apply hard-confirm friction."
        |
        v
Self-Critique (Cognitive Cycle)
    Every action passes through ORIENT -> VERIFY.
    The system critiques its own outputs before delivering.
        |
        v
Feedback Loop (hooks + memory)
    Governance hooks enforce hard limits.
    Memory captures learnings for future sessions.
```

This is not a metaphor. Constitutional AI works by training models to critique their own outputs against a set of principles. The harness does the same thing: CLAUDE.md defines principles, the Cognitive Cycle enforces self-critique, hooks provide the hard boundary.

## Cognitive Protection Matrix

One of the harness's most practical mechanisms. Before any action, classify it on two axes:

|  | **Reversible** | **Irreversible** |
|---|---|---|
| **Objective** (clear right answer) | Auto-pass | Soft confirm |
| **Subjective** (judgment call) | Soft confirm | Hard confirm |

Real examples:

| Action | Classification | Friction |
|--------|---------------|----------|
| Format code | Reversible + Objective | Auto-pass |
| Delete a file | Irreversible + Objective | Soft confirm |
| Choose architecture | Reversible + Subjective | Soft confirm |
| Deploy to production | Irreversible + Subjective | **Hard confirm** |

Escalation triggers override the matrix: anything touching auth, payments, PII, or batch operations (10+ files) always requires hard confirm.

## Project Structure

```
cc-path/
|
+-- README.md                  You are here
+-- LICENSE                    MIT
|
+-- harness/                   Drop-in harness for any project
|   +-- CLAUDE.md              Layer 1: Always-loaded principles
|   +-- .claude/
|       +-- CLAUDE.md          Development conventions
|       +-- rules/             Layer 2: Conditional rules
|       |   +-- thinking-framework.md
|       |   +-- cognitive-protection.md
|       +-- skills/            Layer 3: On-demand workflows
|       +-- hooks/             Layer G: Governance enforcement
|           +-- deploy-guard.sh
|           +-- circuit-breaker.sh
|
+-- docs/                      Deep reference (read on demand)
|   +-- ANTHROPIC-PHILOSOPHY.md    Philosophy-to-code lineage
|   +-- CLAUDE-CODE-PRINCIPLES.md  15 principles with source citations
|   +-- GUIDE.md                   Implementation walkthrough
|
+-- examples/                  Sub-project templates
|   +-- python-api/
|   +-- typescript-webapp/
|
+-- blog/                      Companion articles
```

## Documentation

| Document | Purpose |
|----------|---------|
| [`docs/ANTHROPIC-PHILOSOPHY.md`](docs/ANTHROPIC-PHILOSOPHY.md) | Maps Anthropic's published philosophy (Constitutional AI, RSP, Machines of Loving Grace, Claude's Character) to concrete harness mechanisms. The *why* behind every design decision. |
| [`docs/CLAUDE-CODE-PRINCIPLES.md`](docs/CLAUDE-CODE-PRINCIPLES.md) | 15 engineering principles extracted from Claude Code's source code with exact `file:line` citations. The *what* that drives the implementation. |
| [`docs/GUIDE.md`](docs/GUIDE.md) | Step-by-step guide to adopting the harness in your project. Covers customization, sub-project setup, hook configuration, and token budget management. |

## Evidence Hierarchy

A core practice encoded in the harness. Before acting on any claim, classify it:

- **FACT** -- directly observable in code, docs, or test output. Cite with `file:line`.
- **INTERPRETATION** -- reasonable inference from facts. State the reasoning chain.
- **ASSUMPTION** -- unverified. Flag explicitly. Validate before building on it.

This README follows its own rule. Source citations throughout are FACTs. The Constitutional AI analogy is an INTERPRETATION. You can verify every claim.

## Contributing

Contributions are welcome. The bar is simple:

1. **Every principle must have a source citation.** No vibes. Link to the Anthropic paper, Claude Code source file, or blog post.
2. **Harness changes must fit the token budget.** Layer 1 stays under 3K tokens. Rules stay under 1.5KB each.
3. **Test your harness changes.** Copy the modified harness into a real project. Verify Claude Code behaves as expected.

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/cc-path.git

# Make your changes in harness/ or docs/

# Submit a PR with:
# - What changed
# - Why (with source citation)
# - How you tested it
```

## FAQ

**Is this only for Claude Code?**
The harness files are Claude Code-specific (CLAUDE.md, `.claude/` directory, hooks). But the *principles* -- layered context, guidance vs governance, evidence hierarchy -- apply to any AI coding assistant. The methodology transfers even if the file format doesn't.

**Won't this become outdated when Claude Code updates?**
The principles are derived from Anthropic's published philosophy, which is stable. The implementation details (file paths, loading order) track Claude Code's documented behavior. When Claude Code changes, we update the citations. The architecture stays.

**How is this different from awesome-claude-code lists?**
Those are collections of tips. This is an architecture. The difference is the same as between a collection of shell aliases and a proper CI/CD pipeline. Both use bash. One is engineering.

## License

[MIT](LICENSE) -- use it, fork it, adapt it, ship it.

## Acknowledgments

- **Anthropic** -- for publishing their philosophy openly. Constitutional AI, RSP, Claude's Character, and Machines of Loving Grace are all publicly available. This project builds on that foundation.
- **Claude Code team** (Boris Cherny et al.) -- for "do the simple thing first" and for building an architecture that rewards principled configuration.
- **[oh-my-claudecode](https://github.com/nicobailey/oh-my-claudecode)** -- for the plugin ecosystem that made rapid experimentation with harness patterns possible.
- **The Claude Code community** -- for surfacing the patterns that this project formalizes.

---

*Context Engineering is not prompt engineering. It is a systems discipline. This project is the reference implementation.*
