---
description: "Decompose complex tasks into phases with dependency mapping and parallel/sequential identification"
when_to_use: "plan, break down, decompose, organize, roadmap, prioritize, what order, task list"
allowed-tools: Read Glob Grep Agent
model: opus
effort: high
argument-hint: "[task or goal to decompose]"
---

# Plan

Decompose work into a dependency-mapped execution plan before touching code.

## Process

1. **Scope**: clarify the goal — what done looks like, what is out of scope
2. **Decompose**: break into sub-tasks, each with clear input / output / success criteria
3. **Map dependencies**: draw the DAG — which tasks block which
4. **Classify execution**: parallel (no dependencies) vs sequential (dependency chain)
5. **Identify critical path**: longest dependency chain = minimum completion time
6. **Estimate**: rough effort per phase (small / medium / large)
7. **Present**: dependency graph (text), critical path, parallelizable work highlighted

## Output Format

```
Phase 1 (parallel): A, B, C
Phase 2 (sequential, depends on A): D → E
Critical path: A → D → E
```

## Constraints

- Each sub-task must be self-contained — workers cannot share context with each other
- Classify every assumption as ASSUMPTION before building on it (evidence hierarchy)
- Parallelize read-only tasks; serialize tasks that write to the same file set
- Re-scope rather than over-plan: if decomposition exceeds 10 tasks, split into milestones
- Reference: thinking-framework.md Problem Decomposition (coordinatorMode.ts pattern)
