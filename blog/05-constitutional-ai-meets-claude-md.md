# Your CLAUDE.md Is a Constitution: What Constitutional AI Teaches About Workspace Design

**TL;DR**
- Constitutional AI's training pipeline (constitution, self-critique, revision, RLHF) maps structurally to how CLAUDE.md layers work: principles (CLAUDE.md), evaluation (rules), improvement (skills), and feedback (memory system).
- This is not a metaphor. Both systems use the same mechanism: declarative principles that shape behavior through self-critique rather than exhaustive rule lists.
- The published Claude Constitution is CC0 (public domain). You can literally build on it when designing your workspace's principles.

---

## Constitutional AI in Three Paragraphs

Constitutional AI (CAI) is Anthropic's approach to training helpful AI systems that are also safe. The [paper](https://arxiv.org/abs/2212.08073) was published in 2022, and the method underlies every Claude model.

The core idea: instead of having human labelers flag every harmful output (expensive, slow, inconsistent), give the model a *constitution* -- a set of declarative principles -- and have it critique its own outputs against those principles. The model generates a response, evaluates whether it violates any principle, revises the response, and then trains on the improved version. This is called RLAIF: Reinforcement Learning from AI Feedback, as opposed to RLHF (from Human Feedback).

Why does this work? Because principles generalize where rules fail. A rule that says "do not help with bomb-making" can be evaded by rewording the request. A principle that says "choose the response that is least likely to be used for harm" covers bomb-making, bioweapons, cyberattacks, and every harmful use case that has not been imagined yet. The constitution creates a *way of thinking*, not a lookup table.

## The Structural Mapping

Here is the part that most developers miss: your CLAUDE.md hierarchy implements the same architecture as Constitutional AI. Not metaphorically. Structurally.

```
Constitutional AI Phase              Workspace Layer
------------------------------------  ---------------------------------
Constitution (principles)         --> CLAUDE.md (root + .claude/)
  Declarative norms the model           Design principles, cognitive
  uses for self-critique                cycle, core rules -- always loaded

Self-Critique (evaluation)        --> .claude/rules/ (conditional)
  Model evaluates its own               Rules evaluate agent behavior
  outputs against principles            at specific file access points

Revision (improvement)            --> .claude/skills/ (on-demand)
  Model revises based on                Skills provide focused guidance
  critique feedback                     when invoked for specific tasks

RLHF Feedback Loop                --> Memory system (Dream + MEMORY.md)
  Human preferences refine              Session learnings consolidate
  the model over time                   into persistent project knowledge

Deployment Safeguards             --> Hooks (PreToolUse, PostToolUse)
  Runtime safety filters                Deterministic enforcement
  that cannot be bypassed               that cannot be talked past
```

Let me walk through each layer.

## Layer 1: The Constitution (CLAUDE.md)

In CAI, the constitution is a set of principles like "Choose the response that is most helpful while being honest and harmless" or "Choose the response that a wise, senior Anthropic employee would be most proud of."

In your workspace, the root CLAUDE.md serves the same function. Here is the constitution from our harness:

```markdown
## Design Principles

- **Fail Closed, Default Safe** -- restrictive defaults, opt-in only
- **Prompt Is Architecture** -- CLAUDE.md layers encode system behavior
- **Progressive Compression** -- 3-layer context: always / conditional / on-demand
- **Never Delegate Understanding** -- prove comprehension with file:line
- **Explicit Over Clever** -- no implicit dependencies, no magic
```

These are not instructions. They are *principles for self-critique*. When Claude is about to take an action, these principles inform its evaluation: "Am I being explicit or clever? Am I delegating understanding or proving it? Am I failing open or closed?"

The critical design choice: principles, not rules. Amanda Askell's insight from Claude's Character design applies directly:

> A model trained to follow principles outperforms one trained to follow rules. Rules are brittle at the boundary; internalized values generalize.

A rule list ("do not use rm -rf, do not force-push, do not delete databases") covers three cases. "Fail Closed, Default Safe" covers every destructive operation, including ones you have not anticipated.

## Layer 2: Self-Critique (.claude/rules/)

In CAI, the self-critique phase has the model evaluate its own output against the constitution. "Does this response violate any of my principles? If so, how?"

In your workspace, `.claude/rules/` files serve this function. They are loaded conditionally -- when the model accesses specific file types or contexts -- and they provide focused evaluation criteria.

Example: `cognitive-protection.md` activates when the model is about to take a mutation action. It applies a 2x2 evaluation matrix:

```
|            | Reversible    | Irreversible  |
|------------|---------------|---------------|
| Objective  | Auto-pass     | Soft confirm  |
| Subjective | Soft confirm  | Hard confirm  |
```

This is self-critique made systematic. Before executing an action, the model classifies it on two axes and applies proportional friction. The rule does not say "do not delete files" (a rule). It says "classify your action's reversibility and objectivity, then apply the appropriate level of caution" (a principle-based evaluation).

The conditional loading is significant. In CAI, self-critique is contextual -- it applies to the specific output being evaluated, not to everything the model has ever generated. Similarly, conditional rules load only when relevant:

```yaml
---
paths:
  - "**/*.sql"
  - "**/migrations/**"
---
```

This rule loads only when SQL files or migrations are accessed. It costs zero tokens during Python work. This is Progressive Compression applied to the evaluation layer.

## Layer 3: Revision (.claude/skills/)

In CAI, after self-critique identifies a problem, the model *revises* its output. The revision is guided by the specific critique: "My original response was too detailed about X. Let me provide a more general explanation."

In your workspace, `.claude/skills/` serve the revision function. When the model's default behavior is insufficient for a task, a skill provides deep, focused guidance that improves the output.

Example: the `/research` skill loads a full investigation protocol:

```yaml
---
description: "Fact-based investigation with source separation"
when_to_use: "investigate, research, analyze, look into, how does"
allowed-tools: Read Glob Grep WebSearch WebFetch Agent
model: opus
effort: high
---
```

The body (loaded only on invocation, not idle) contains the research methodology: output structure with FACT/INTERPRETATION/ASSUMPTION classification, process steps, and constraints.

The key insight: skills use *frontmatter-only loading*. Each skill costs approximately 70 tokens idle (the frontmatter) instead of 300+ tokens for the full body. Claude knows the skill exists and when to invoke it, but does not pay the full context cost until it actually needs the guidance.

In CAI terms: the model knows revision strategies exist but only loads the specific strategy when self-critique identifies a need. This is efficient use of a finite context window, just as CAI is efficient use of finite training compute.

## Layer 4: Feedback Loop (Memory)

In CAI, the RLHF feedback loop refines the model over time. Human preferences on model outputs create a training signal that improves future behavior. This is the learning mechanism.

In your workspace, the memory system serves this function:

- **Dream** (Claude Code's `autoDream` feature): After sessions, automatically consolidates learnings into persistent memory. What worked, what failed, what to remember.
- **MEMORY.md**: Persistent project knowledge that survives across sessions.
- **Session learnings**: Within a session, the LEARN phase of the Cognitive Cycle captures non-obvious insights.

The parallel is direct: both systems use experience to improve future behavior. CAI uses it at training time; your workspace uses it at runtime. The mechanism differs but the function is identical -- a feedback loop that makes the system better over time.

## Layer G: Deployment Safeguards (Hooks)

CAI models are not deployed raw. Anthropic adds runtime safety filters -- systems that check outputs before they reach users. These filters cannot be bypassed by clever prompting. They are deterministic checks that run outside the model's reasoning.

Your hooks serve the same function:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/deploy-guard.sh",
        "timeout": 5
      }]
    }]
  }
}
```

The deploy guard runs *before* Claude executes a bash command. It pattern-matches against dangerous operations and blocks them with exit code 2. The model cannot see the hook, reason about it, or override it. This is deterministic enforcement -- the workspace equivalent of runtime safety filters.

This layer has no CAI training analogue. It is a deployment-time addition that Anthropic applies to production systems and that you should apply to your workspace. The model's intentions are good (it was trained well). The hook catches the cases where good intentions plus context pressure lead to bad outcomes.

## Why This Matters: Principles > Rules at Every Layer

The deepest lesson from Constitutional AI is not about any specific technique. It is about the superiority of principles over rules at *every* layer of the system.

**At the constitution layer**: "Fail Closed, Default Safe" beats a list of prohibited commands.

**At the evaluation layer**: A 2x2 decision matrix (reversible/irreversible x objective/subjective) beats a list of "always confirm before..." rules.

**At the revision layer**: A skill that teaches a methodology (FACT/INTERPRETATION/ASSUMPTION classification) beats a skill that lists specific research steps.

**At the feedback layer**: Capturing *why* something worked or failed (the principle) beats capturing *what* happened (the event).

This is because principles compose and generalize. Rules enumerate and miss edge cases. A workspace built on principles adapts to new situations. A workspace built on rules requires constant updates as new situations arise.

## Practical Example: The Evidence Hierarchy

Let me trace one principle through all four layers to show how it cascades.

The principle: **Epistemic humility is structural, not performative.**

**Constitution (CLAUDE.md)**: The Cognitive Cycle includes "ANALYZE -- Gather evidence. Classify as FACT / INTERPRETATION / ASSUMPTION."

**Evaluation (rules)**: `thinking-framework.md` provides the Evidence Hierarchy:
- FACT: directly observable in code, docs, or test output. Cite with `file:line`.
- INTERPRETATION: reasonable inference from facts. State the reasoning.
- ASSUMPTION: unverified. Flag explicitly. Validate before building on it.

**Revision (skills)**: The `/research` skill requires outputs classified with this hierarchy. The skill does not just ask for research -- it specifies the *form* of the output.

**Feedback (memory)**: The Maker-Checker self-verification protocol asks: "Did I label assumptions as assumptions, not facts?" This check runs after every significant output.

One principle. Four layers. Each layer applies it differently: the constitution declares it, the rule operationalizes it, the skill applies it to a specific workflow, and the feedback loop verifies it was followed.

## The Claude Constitution Is CC0

Here is something most developers do not know: Anthropic published the [Claude Constitution](https://www.anthropic.com/research/collective-constitutional-ai-aligning-a-language-model-with-public-input) with a CC0 license. Public domain. You can use it, modify it, build on it.

This means you can literally take Claude's own constitutional principles and adapt them for your workspace. Not just inspired by -- directly derived from. The constitution includes principles about helpfulness, honesty, harmlessness, and nuance that translate directly to how you want your AI coding assistant to behave.

For example, the constitutional principle "Choose the response that is most helpful while being harmless" maps to the priority stack: **Safe > Ethical > Compliant > Helpful.** Helpful matters, but only after safety, ethics, and compliance are satisfied.

## Building Your Own Constitution

Here is a starter framework for writing your workspace's constitution, informed by CAI principles:

1. **Start with values, not rules.** What kind of AI assistant do you want? Cautious or bold? Verbose or concise? Independent or collaborative? These are character traits, not instructions.

2. **Make principles falsifiable.** "Write good code" is not a principle. "Three similar lines of code is better than a premature abstraction" is -- you can check whether the model followed it.

3. **Add evaluation criteria.** For each principle, how would you know if it was violated? That evaluation criterion becomes a rule.

4. **Provide revision guidance.** When a principle is violated, what should the model do differently? That correction path becomes a skill.

5. **Build the feedback loop.** After each session, did the principles serve well? What should change? That reflection becomes memory.

6. **Enforce the hard boundaries.** Which principles are so important that violation is unacceptable? Those become hooks.

This framework produces a workspace that improves over time, generalizes to new situations, and enforces its most critical constraints deterministically. It is Constitutional AI applied to your development environment.

---

*This is the final post in the series. The complete series:*

1. [Context Engineering Is Not Prompt Engineering](01-what-is-harness-engineering.md): Introducing Harness Engineering
2. [Your CLAUDE.md Is Not Enough](02-guidance-vs-governance.md): Why AI safety needs code, not text
3. [From Machines of Loving Grace to settings.json](03-anthropic-philosophy-in-practice.md): How Anthropic's philosophy becomes your workspace
4. [Circuit Breakers for AI Agents](04-circuit-breakers-for-ai-agents.md): Lessons from Claude Code's source
5. **This post**: Your CLAUDE.md Is a Constitution

*The full reference implementation -- harness files, hooks, documentation, and philosophy mapping -- is available at [claude-code-harness-engineering](https://github.com/ziho/claude-code-harness-engineering). MIT licensed. Contributions welcome.*
