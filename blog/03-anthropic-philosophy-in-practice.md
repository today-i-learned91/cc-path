# From Machines of Loving Grace to settings.json: How Anthropic's Philosophy Becomes Your Workspace

**TL;DR**
- Anthropic's published philosophy is not abstract -- it directly maps to workspace design decisions that make your AI coding assistant measurably better.
- Five key thinkers at Anthropic each contributed a principle that translates into a concrete mechanism: cognitive cycles, character-over-rules, read-before-write, simplicity-first, and minimal-friction safety.
- Your CLAUDE.md hierarchy is a constitution in the Constitutional AI sense. The priority stack Safe > Ethical > Compliant > Helpful is not a platitude -- it is an architecture.

---

## The Gap Between Philosophy and Practice

Anthropic publishes a remarkable amount of their thinking. Dario Amodei's "Machines of Loving Grace" essay. Amanda Askell's work on Claude's character. Chris Olah's interpretability research. The Constitutional AI paper. The Responsible Scaling Policy.

Most developers glance at these, nod appreciatively, and go back to writing CLAUDE.md rules by trial and error.

This is a missed opportunity. Every one of those publications contains a design principle that, once understood, makes your workspace configuration better. Not in a vague "inspired by" sense. In a "this specific mechanism exists because of that specific insight" sense.

Let me trace five threads from Anthropic's published philosophy through Claude Code's source code to concrete workspace mechanisms.

## Thread 1: Dario Amodei -- Build to Understand

**Source**: [Machines of Loving Grace](https://darioamodei.com/machines-of-loving-grace) (2024)

Amodei's essay is often read as an optimistic vision of AI's potential. The deeper insight is methodological: Anthropic builds commercial products not as an end goal but as the necessary vehicle for understanding what AI systems actually do. You cannot theorize about a system you have not built. You cannot align a system you have not studied empirically.

**Workspace mechanism: The Cognitive Cycle**

```
1. ORIENT  -- What is the actual problem? Read existing code/docs first.
2. ANALYZE -- Gather evidence. Classify as FACT / INTERPRETATION / ASSUMPTION.
3. PLAN    -- Decompose into phases. Parallelize independent work.
4. EXECUTE -- Small verified steps. No speculative abstractions.
5. VERIFY  -- Prove, don't confirm. Run tests with feature enabled.
6. LEARN   -- Update docs only for non-obvious insights.
```

ORIENT and ANALYZE precede any execution. This is "build to understand" encoded as a workflow. The AI assistant does not jump to fixing code -- it first understands the system it is modifying. The VERIFY phase requires proof (fresh test output, actual build results), not confirmation ("I believe this works").

This maps to Claude Code's coordinator pattern in `coordinatorMode.ts:220-227`:

> "Run tests with the feature enabled -- not just 'tests pass'. Run typechecks and investigate errors -- don't dismiss as 'unrelated'. Be skeptical. Test independently -- prove the change works, don't rubber-stamp."

## Thread 2: Amanda Askell -- Character Over Rules

**Source**: [Claude's Character](https://www.anthropic.com/research/claude-character) (2024)

Amanda Askell leads Claude's character design. Her core insight, drawn from virtue ethics: a model trained to follow principles outperforms one trained to follow rules. Rules are brittle at the boundary. "Do not use rm -rf" fails when the command is `find . -delete`. A model with the *character* to be cautious about destructive operations handles both cases and every future variant.

The Constitutional AI paper (arXiv:2212.08073) formalizes this: the constitution is a set of declarative principles the model uses for self-critique, not a lookup table of prohibited outputs.

**Workspace mechanism: Principles in CLAUDE.md, not rules**

Bad CLAUDE.md:
```
- Do not use rm -rf
- Do not use git push --force
- Do not delete production databases
- Do not run npm publish without confirmation
```

Good CLAUDE.md:
```
## Design Principles
- **Fail Closed, Default Safe** -- restrictive defaults, opt-in only
- **Explicit Over Clever** -- no implicit dependencies, no magic

## Safety Standards
- Principle: "CLAUDE.md = guidance (~80%), Hooks = governance (100%)"
```

The first version is a rule list. It covers four specific cases and misses everything else. The second version encodes *character* -- a way of thinking that generalizes to novel situations. "Fail Closed" covers `rm -rf`, `find . -delete`, `docker system prune`, and every destructive command that has not been invented yet.

Askell also established the priority stack: **Safe > Ethical > Compliant > Helpful**. This is not a sliding scale. It is a strict ordering. When Claude could be both helpful and unsafe, safety wins unconditionally. The harness implements this through the Cognitive Protection matrix, where irreversible + subjective actions always require hard confirmation, regardless of how helpful the action would be.

## Thread 3: Chris Olah -- Zoom In

**Source**: [Zoom In: An Introduction to Circuits](https://distill.pub/2020/circuits/zoom-in/) (Distill, 2020)

Chris Olah leads Anthropic's interpretability research. His "Zoom In" methodology treats neural networks as empirical objects: look at individual neurons and features, build understanding bottom-up from observation, not top-down from theory.

The practical translation for coding: you cannot modify what you do not understand. Before changing a system, observe it.

**Workspace mechanism: Read Before Write**

This principle appears in Claude Code's system prompt at `constants/prompts.ts:230`:

> "In general, do not propose changes to code you haven't read. If a user asks about or wants you to modify a file, read it first."

It seems obvious. It is also the single most commonly violated principle in AI-assisted development. Developers ask "fix this bug" and expect the AI to start writing code. A well-configured harness makes the AI read first, understand the file's structure, dependencies, and existing patterns, then propose changes.

The Evidence Hierarchy reinforces this:
- **FACT**: directly observable in code, docs, or test output. Cite with `file:line`.
- **INTERPRETATION**: reasonable inference from facts. State the reasoning chain.
- **ASSUMPTION**: unverified. Flag explicitly. Validate before building on it.

This is Olah's empirical methodology applied to everyday coding. Do not assume. Observe. Cite your observations. Build on solid foundations.

## Thread 4: Boris Cherny -- Do the Simple Thing First

**Source**: Anthropic Engineering Blog; Claude Code source (`constants/prompts.ts:231`)

Boris Cherny leads the Claude Code team. His engineering philosophy: start with the simplest tool that could work. Glob+grep beats RAG for most code search. Direct file reads beat embeddings. Composition beats abstraction.

From the Claude Code source:

> "Go straight to the point. Try the simplest approach first without going in circles. Do not overdo it. Be extra concise."

**Workspace mechanism: Tool hierarchy and minimum viable complexity**

The harness encodes a tool preference order:

```
Glob/Grep  ->  Read  ->  Agent
(simplest)     (more)    (most complex)
```

When searching code, start with glob patterns and grep. Only escalate to reading full files when you need more context. Only spawn sub-agents when the task genuinely requires parallel exploration.

This extends to code quality rules:

> "Don't create helpers, utilities, or abstractions for one-time operations. Don't design for hypothetical future requirements. Three similar lines of code is better than a premature abstraction."
> -- `constants/prompts.ts:201-203`

The three-line rule is one of the most practical insights in the entire harness. Developers reflexively abstract. AI coding assistants, trained on codebases full of abstractions, reflexively abstract even harder. Explicitly encoding "three similar lines > premature abstraction" fights this tendency.

## Thread 5: Jan Leike -- Minimal-Friction Safety

**Source**: Alignment research at Anthropic

Jan Leike's framework evaluates alignment approaches by three "taxes":
1. **Performance tax** -- does alignment reduce capability?
2. **Development tax** -- does it slow building?
3. **Time-to-deployment tax** -- does it delay shipping?

The ideal approach minimizes all three. Constitutional AI minimizes the development tax by automating the feedback loop (the model critiques itself, no human labelers needed for every example).

**Workspace mechanism: Hooks that enforce without burdening**

The harness's hooks are designed for zero friction in the common case:

- Deploy guard: 0 tokens of context. Adds ~50ms of latency on Bash calls. You never notice it -- until it saves you from a force-push.
- Circuit breaker: 0 tokens idle. Only surfaces when failures compound. Does not slow down successful operations at all.
- Input sanitizer: Pattern match runs in <50ms. No false positives on normal tool inputs.

The quality gates in `.claude/CLAUDE.md` follow the same principle:

```
- Pre-action:  Do I understand the problem? Have I read the code?
- Execution:   Am I making the minimal correct change?
- Post-action: Does this work? Can I prove it?
- Failure:     What's the root cause before retrying?
```

These are a mental model, not a form to fill out. Minimal performance tax. Minimal development tax. The safety benefit comes from shaping how the model thinks, not from adding bureaucratic overhead.

## The Constitutional AI Analogy

All five threads converge in one structural insight: your CLAUDE.md hierarchy *is* a constitution in the Constitutional AI sense.

Constitutional AI's training pipeline:
1. **Constitution** (principles) -- declarative norms for self-critique
2. **Self-critique** (evaluation) -- model evaluates its own outputs
3. **Revision** (improvement) -- model improves based on critique
4. **RLHF feedback** (learning) -- human preferences refine behavior over time

Your workspace:
1. **CLAUDE.md** (principles) -- design principles, cognitive cycle
2. **.claude/rules/** (evaluation) -- conditional checks triggered by context
3. **.claude/skills/** (improvement) -- on-demand guidance for specific tasks
4. **Memory system** (learning) -- Dream consolidates session learnings

This is not a metaphor. It is a structural correspondence. Each layer serves a different function, and collapsing them -- putting everything in CLAUDE.md, or enforcing everything with hooks -- degrades the system. Principles without enforcement drift. Enforcement without principles is brittle.

## The Priority Stack in Practice

Safe > Ethical > Compliant > Helpful.

This ordering resolves every tension in workspace design:

- Should the deploy guard block a legitimate production deployment that the developer asked for? **Yes.** Safe > Helpful. The developer runs it manually.
- Should the circuit breaker prevent Claude from trying one more approach when it might work? **Yes, after 5 failures.** Safe > Helpful. Compound failures waste more than they save.
- Should the Evidence Hierarchy slow down simple tasks? **Only when claims are non-obvious.** Formatting code is objective and reversible -- auto-pass. Architectural decisions are subjective and hard to reverse -- require evidence.

Every design decision in the harness can be justified by asking: "Which level of the priority stack does this serve?"

## Making It Concrete

Here is how to apply these five threads to your own workspace:

1. **Amodei (Build to understand)**: Add a Cognitive Cycle to your CLAUDE.md. Put ORIENT before EXECUTE.
2. **Askell (Character over rules)**: Rewrite your rule lists as principles. "Fail Closed" instead of "do not rm -rf."
3. **Olah (Zoom In)**: Add "Read before write" as a core rule. Add the Evidence Hierarchy.
4. **Cherny (Simple thing first)**: Add tool hierarchy guidance. Add the three-line rule.
5. **Leike (Minimal friction)**: Audit your hooks for latency. Keep safety invisible in the happy path.

These are not theoretical suggestions. They are the architectural decisions behind a [working reference implementation](https://github.com/ziho/cc-path) that you can copy, adapt, and improve.

---

*Next in the series: [Circuit Breakers for AI Agents](04-circuit-breakers-for-ai-agents.md) -- how Claude Code's own source code shows you how to prevent runaway failure loops.*

*The full harness with philosophy documentation is available at [cc-path](https://github.com/ziho/cc-path).*
