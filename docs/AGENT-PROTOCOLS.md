# Agent Interaction Protocol

How agents collaborate in cc-path. Use this guide to select agents,
sequence workflows, and enforce maker-checker separation.

Reference: agent definitions in [`../agents/*.md`](../agents/),
tier table in [`../harness/CLAUDE.md`](../harness/CLAUDE.md) lines 41-54.

---

## 1. Agent Selection Guide

Choose the minimum set of agents needed. Over-delegation wastes context;
under-delegation skips verification.

| Task Type | Complexity | Recommended Agents | Count |
|-----------|-----------|-------------------|-------|
| Bug fix | Low | builder + reviewer | 2 |
| Feature | Medium | planner + builder + reviewer + tester | 4 |
| Refactor | Medium | architect + builder + reviewer | 3 |
| Security audit | High | security + red-teamer + architect + reviewer | 4+ |
| New project | High | analyst + planner + architect + builder + tester + writer | 6 |
| Code review | Low | reviewer (or critic for plans) | 1 |
| Research | Low | researcher | 1 |
| Documentation | Low | writer | 1 |

Selection principle: start with the lowest count that covers both
**making** and **checking**. Escalate by adding agents, never by
giving one agent two roles.

---

## 2. Interaction Protocols

### 2a. Build and Review

Standard workflow for any code change.

```
builder(write) --> reviewer(read-only) --> builder(fix) --> reviewer(approve)
```

| Step | Agent | Produces | Consumes |
|------|-------|----------|----------|
| 1 | [builder](../agents/builder.md) | Code + tests | Requirements or plan |
| 2 | [reviewer](../agents/reviewer.md) | Review findings (severity + location) | Code from step 1 |
| 3 | [builder](../agents/builder.md) | Revised code | Review findings from step 2 |
| 4 | [reviewer](../agents/reviewer.md) | Approval or escalation | Revised code from step 3 |

Execution: strictly sequential. Builder and reviewer never run in parallel
because the reviewer needs the builder's output.

### 2b. Plan and Critique

For non-trivial tasks that need upfront design.

```
planner(plan) --> critic(challenge) --> planner(revise)
```

| Step | Agent | Produces | Consumes |
|------|-------|----------|----------|
| 1 | [planner](../agents/planner.md) | Phased plan with dependencies | Requirements |
| 2 | [critic](../agents/critic.md) | Findings (severity + evidence) | Plan from step 1 |
| 3 | [planner](../agents/planner.md) | Revised plan | Critique from step 2 |

Execution: sequential. The critic applies the evidence hierarchy
(FACT / INTERPRETATION / ASSUMPTION) from the
[thinking framework](../../.claude/rules/thinking-framework.md).

### 2c. Research and Build

Full pipeline for features that require investigation.

```
Phase 1 (parallel):  researcher(gather)  +  analyst(requirements)
Phase 2 (sequential): architect(design)
Phase 3 (parallel):  builder(implement)  +  tester(write tests)
Phase 4 (sequential): reviewer(verify)
```

| Phase | Agents | Mode | Produces |
|-------|--------|------|----------|
| 1 | [researcher](../agents/researcher.md), [analyst](../agents/analyst.md) | parallel | Evidence report, requirements |
| 2 | [architect](../agents/architect.md) | sequential | Architecture decision with trade-offs |
| 3 | [builder](../agents/builder.md), [tester](../agents/tester.md) | parallel | Code, test suite |
| 4 | [reviewer](../agents/reviewer.md) | sequential | Review findings, approval |

Phase 1 parallelizes because both agents are read-only.
Phase 3 parallelizes because builder and tester write to different file sets.

### 2d. Security Audit

Adversarial workflow with structured escalation.

```
Phase 1 (parallel):  security(scan)  +  red-teamer(attack)
Phase 2 (sequential): builder(fix)
Phase 3 (sequential): security(verify)
```

| Phase | Agents | Mode | Produces |
|-------|--------|------|----------|
| 1 | [security](../agents/security.md), [red-teamer](../agents/red-teamer.md) | parallel | Vulnerability report, exploit report |
| 2 | [builder](../agents/builder.md) | sequential | Patches for findings |
| 3 | [security](../agents/security.md) | sequential | Verification that fixes hold |

The security agent acts as both initiator and final checker. The red-teamer
provides adversarial evidence that the security agent alone might miss.

---

## 3. Maker-Checker Matrix

A maker NEVER checks its own output. Every workflow must include at least
one checker per maker.

```
                      CHECKER (read-only verification)
                 reviewer  critic  security  architect  researcher
MAKER
  builder           Y        -        Y         Y          -
  planner           -        Y        -         Y          -
  writer            Y        Y        -         -          -
  architect         -        Y        Y         -          -
  tester            Y        -        -         -          -
  red-teamer        -        -        Y         -          -
```

Rules:
- **Self-check prohibited** -- a maker never reviews its own output.
- **Read-only agents are natural checkers** -- reviewer, critic, security,
  architect, and researcher all have read-only access (except red-teamer,
  which needs write access to execute attacks).
- **Minimum one checker** -- every maker in a workflow must have at least
  one assigned checker before work begins.
- **Security-sensitive tasks** require the [security](../agents/security.md)
  agent as a mandatory checker, regardless of other checkers present.

---

## 4. Communication Format

Standard format for every agent handoff. The coordinator uses this
structure to route work between agents that cannot see each other.

```markdown
## Handoff: [from-agent] -> [to-agent]
**Task**: one-line description of what the receiving agent should do
**Input**: artifact name, file paths, or summary of prior output
**Output**: what the receiving agent must produce
**Status**: pass | fail | needs-revision
**Evidence**: FACT (observed in code/tests) | INTERPRETATION (inferred) | ASSUMPTION (unverified)
```

Example:

```markdown
## Handoff: builder -> reviewer
**Task**: Review authentication middleware for correctness and security
**Input**: src/middleware/auth.ts (lines 1-85), tests/auth.test.ts
**Output**: Review findings with severity, location, and fix recommendations
**Status**: pass
**Evidence**: FACT -- implementation exists at src/middleware/auth.ts:12-45
```

Evidence classification follows the hierarchy defined in the
[thinking framework](../../.claude/rules/thinking-framework.md):
FACT (directly observable), INTERPRETATION (inference with stated reasoning),
ASSUMPTION (unverified, must be flagged).

---

## 5. Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| **Self-approval** | Maker checks its own output | Assign a different agent as checker (see matrix above) |
| **Skipping verification** | Deploying without reviewer or tester | Every write agent needs at least one read-only checker |
| **Over-delegation** | 6 agents for a bug fix | Match agent count to task complexity (section 1) |
| **Under-delegation** | Builder doing security review | Use the specialist -- builder builds, security reviews security |
| **Parallel writes** | Two agents writing the same file | Serialize write agents per file set; parallelize only across disjoint files |
| **Unbounded loops** | Builder and reviewer cycling without convergence | Cap revision rounds at 3; escalate to architect or coordinator after |
| **Skipping evidence** | Handoffs without FACT/INTERPRETATION/ASSUMPTION tags | Enforce communication format (section 4) on every handoff |
