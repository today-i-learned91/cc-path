# Context Engineering Is Not Prompt Engineering: Introducing Harness Engineering

**TL;DR**
- Prompt engineering crafts individual queries. Harness engineering designs the *system* that shapes every query your AI coding assistant receives.
- Most CLAUDE.md files are cargo-culted prompt dumps. A principled harness uses a three-layer architecture (always / conditional / on-demand) to manage token budgets like a real engineering constraint.
- We open-sourced a reference implementation with traced citations from Anthropic's published philosophy and Claude Code's source code: [claude-code-harness-engineering](https://github.com/ziho/claude-code-harness-engineering).

---

## The Problem Nobody Talks About

Open any Claude Code community forum and you will find people sharing CLAUDE.md snippets. "Add this to make Claude write better tests." "Copy this rule to prevent force-pushes." "Here is my 400-line CLAUDE.md that makes Claude Code amazing."

Nobody asks the obvious question: *why does that rule work?*

And nobody mentions the obvious failure mode: by turn 47 of a long session, after context compaction has compressed your conversation history, Claude starts ignoring half of those carefully crafted instructions. Your 400-line CLAUDE.md becomes a 400-line tax on every single request, burning through your context window while delivering diminishing returns.

I have seen this pattern hundreds of times. The CLAUDE.md grows. The results get worse. The developer adds more rules. The results get even worse.

There is a better way.

## The DevOps Analogy

Remember when deployment meant SSH-ing into a production server and running commands by hand? Some developers had personal deploy scripts. They shared bash snippets. Everyone had their own artisanal process.

Then DevOps emerged -- not as a collection of scripts, but as a *systems discipline*. Infrastructure as code. CI/CD pipelines. Reproducible environments. The shift was not from bad scripts to good scripts. It was from ad-hoc scripting to principled engineering.

Harness Engineering is that same shift, applied to AI coding assistants.

The term "harness" is deliberate. In testing, a test harness is the scaffolding that sets up context, runs the system under test, and verifies results. Your CLAUDE.md files, rules, skills, and hooks are the harness for your AI coding assistant. They set up context, shape behavior, and enforce constraints.

The question is whether you are engineering that harness or just accumulating it.

## From Prompt Engineering to Context Engineering to Harness Engineering

Let me draw the distinction clearly:

**Prompt engineering** is about crafting individual queries. "How do I ask Claude to write better TypeScript?" This is a useful skill, but it operates at the wrong level of abstraction for a tool you use 8 hours a day.

**Context engineering** is about designing the system that shapes every query. Anthropic's own engineering blog talks about this: "Find the smallest set of high-signal tokens that maximize the likelihood of your desired outcome." This is closer, but still abstract.

**Harness engineering** is context engineering applied to AI coding assistants as a systems discipline. It has concrete mechanisms, measurable constraints, and traceable design decisions.

Here is what that looks like in practice.

## The Three-Layer Architecture

Claude Code loads context files in a specific order, defined in `getMemoryFiles` in `claudemd.ts`:

```
Managed -> User -> Project (root->CWD) -> Local -> AutoMem
```

A principled harness exploits this architecture with three layers plus a governance plane:

```
Layer 1: Always-loaded (CLAUDE.md + .claude/CLAUDE.md)
  Design principles, cognitive cycle, safety standards.
  ~2-3K tokens. Loaded on every single request.

Layer 2: Conditional (.claude/rules/*.md with paths: frontmatter)
  Thinking framework, cognitive protection matrix.
  0 tokens until a matching file is accessed.

Layer 3: On-demand (.claude/skills/*.md)
  Research protocol, build workflow, code review checklist.
  ~70 tokens each (frontmatter only). Body loads on invocation.

Layer G: Governance (.claude/hooks/)
  Deploy guard, circuit breaker, input sanitizer.
  0 context tokens. 100% enforcement via PreToolUse/PostToolUse.
```

This is not an arbitrary structure. It maps directly to how Claude Code actually loads and processes configuration files. Layer 1 is your constitution -- the principles that govern all behavior. Layer 2 is case law -- specific applications triggered by context. Layer 3 is playbooks -- deep guidance available on demand. Layer G is enforcement -- deterministic constraints the model cannot override.

## Token Budget: A Real Engineering Constraint

Here is the part most CLAUDE.md authors ignore: LLMs have quadratic attention cost. Every token in your context window affects how the model attends to every other token. A 600-line CLAUDE.md is not just "a lot of text." It is approximately 4,000 tokens of instruction that dilute the model's attention on your actual code, on every single request.

The harness uses measured budgets:

| Layer | Budget | Rationale |
|-------|--------|-----------|
| CLAUDE.md (root) | 80 lines / 4KB | Constitution -- always loaded, so every token must earn its place |
| .claude/CLAUDE.md | 60 lines / 3KB | Conventions -- separated from principles for override semantics |
| .claude/rules/ (each) | 30 lines / 1.5KB | Case law -- focused, single-concern rules |
| .claude/skills/ (idle) | ~70 tokens each | Frontmatter only -- body loads on invocation |
| .claude/hooks/ | 0 tokens | Runs outside model context entirely |

A workspace with 10 rules where 6 use conditional `paths:` loading saves thousands of tokens per session compared to loading everything unconditionally. That is not a theoretical savings. It is the difference between Claude reading your code carefully and Claude skimming because its attention is spread across a bloated context.

## Why Most CLAUDE.md Files Fail

The failure modes are predictable once you understand the architecture:

**1. No separation of guidance from governance.** Everything lives in CLAUDE.md -- suggestions and hard safety rules alike. When the model is under token pressure late in a conversation, it treats all instructions equally, which means safety-critical rules get skimmed just like style preferences. The fix: hooks for safety, prose for guidance.

**2. No principled basis.** The rule says "read before write" but the author does not know it derives from Chris Olah's interpretability research methodology and is enforced in Claude Code's `coordinatorMode.ts:255-268`. Without understanding *why* a rule works, you cannot adapt it, debug it, or decide when to override it.

**3. Token waste from unstructured loading.** A rule about SQL migrations loads on every Python request. A skill's 50-line research protocol sits in context during a simple formatting task. Progressive loading eliminates this waste.

**4. Copy-paste without understanding.** The most common failure. Someone shares a CLAUDE.md on Twitter. It gets copied 500 times. Nobody can explain why it is structured the way it is. When Claude Code updates its loading behavior, all 500 copies break and nobody knows why.

## What This Project Provides

[claude-code-harness-engineering](https://github.com/ziho/claude-code-harness-engineering) is not a template to copy. It is a reference implementation with citations.

Every design decision traces from an Anthropic paper or Claude Code source file through a principle to a concrete mechanism:

- **Fail Closed, Default Safe** (from `Tool.ts:748`) becomes the hook architecture where new tools are blocked by default.
- **Progressive Compression** (from `getMemoryFiles` in `claudemd.ts`) becomes the three-layer context system with measured token budgets.
- **Never Delegate Understanding** (from `coordinatorMode.ts:255-268`) becomes the requirement to prove comprehension with file:line references before delegating work.

The project includes:
- A drop-in `harness/` directory you can copy into any project
- Seven design principles extracted from Claude Code's source with exact citations
- Safety hooks (deploy guard, circuit breaker, input sanitizer) with real shell scripts
- Deep reference documentation mapping Anthropic's philosophy to workspace mechanisms
- This blog series explaining the thinking behind every decision

## Getting Started

```bash
git clone https://github.com/ziho/claude-code-harness-engineering.git
cd claude-code-harness-engineering

# Copy the harness into your project
cp harness/CLAUDE.md your-project/CLAUDE.md
cp -r harness/.claude your-project/.claude
```

Then customize. The harness is a starting point, not a straitjacket. But before you change anything, read the `docs/WHY.md` file. It explains the rationale behind every decision. Understanding the *why* is what separates harness engineering from prompt engineering.

## What Is Next

This is the first in a five-part series:

1. **This post**: What harness engineering is and why it matters
2. [Your CLAUDE.md Is Not Enough](02-guidance-vs-governance.md): Why AI safety needs code, not text
3. [From Machines of Loving Grace to settings.json](03-anthropic-philosophy-in-practice.md): How Anthropic's philosophy becomes your workspace
4. [Circuit Breakers for AI Agents](04-circuit-breakers-for-ai-agents.md): Lessons from Claude Code's source
5. [Your CLAUDE.md Is a Constitution](05-constitutional-ai-meets-claude-md.md): What Constitutional AI teaches about workspace design

---

*Context Engineering is not prompt engineering. It is a systems discipline. The [reference implementation](https://github.com/ziho/claude-code-harness-engineering) is open source and waiting for your contributions.*
