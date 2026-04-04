---
description: "Implement features, fix bugs, write production code with tests"
when_to_use: "build, implement, create, make, code, develop, add feature, fix bug"
allowed-tools: Read Glob Grep Edit Write Bash Agent
model: sonnet
effort: high
argument-hint: "[feature or bug description]"
---

# Build

Write production-quality code following the project's conventions.

## Process

1. **Understand**: read existing code before proposing changes
2. **Plan**: decompose into small, verifiable steps
3. **Execute**: one logical change at a time
4. **Test**: run tests with the feature enabled
5. **Verify**: prove the change works, don't rubber-stamp

## Constraints

- No unused imports, variables, or dead code
- Error handling at system boundaries only
- Three similar lines > premature abstraction
- Commit atomically with conventional commit messages
