# Development Conventions

## Quality Gates (hook-level application of Cognitive Cycle)

Maps to Claude Code's PreToolUse->PostToolUse->Failure chain:
- **Pre-action** (ORIENT): Do I understand the problem? Have I read the code?
- **Execution** (EXECUTE): Am I making the minimal correct change?
- **Post-action** (VERIFY): Does this work? Can I prove it?
- **Failure recovery** (LEARN): What's the root cause before retrying?

## Code Quality

- No unused imports, variables, or dead code
- Error handling at system boundaries only (user input, external APIs)
- No backwards-compatibility hacks for removed code
- Three similar lines > premature abstraction
- Comments only where logic is non-obvious
- Prefer composition over inheritance

## Git Protocol

- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
- Atomic commits: one logical change per commit
- Never force-push to main/master without explicit user request
- Never skip hooks (--no-verify) unless explicitly asked

## Testing Strategy

- Unit tests for business logic and pure utilities
- Integration tests for API endpoints and data flows
- E2E tests for critical user paths
- Test names describe behavior, not implementation

## Context Architecture

Loading order (source: `getMemoryFiles` in claudemd.ts):
1. Managed -> User -> Project (root->CWD) -> Local -> AutoMem
2. Later = higher priority. Sub-project CLAUDE.md overrides parent.
3. `.claude/rules/*.md` without `paths` frontmatter -> always loaded (unconditional)
4. `.claude/rules/*.md` with `paths` frontmatter -> loaded when matching file accessed (conditional)
5. `.claude/skills/*.md` -> frontmatter only in context; body on invocation

## Token Budget Management

- `/compact` when context exceeds ~60% capacity
- `/clear` when switching unrelated sub-projects
- Glob/Grep over Bash for file search
- Read with offset+limit for large files (>2000 lines)
- Parallel agents for independent research

## Maker-Checker Self-Verification

After completing any significant output:
- **Completeness**: did I address every element of the request?
- **Actionability**: can someone execute/decide based on this output?
- **Honesty**: did I label assumptions as assumptions, not facts?
- **Omissions**: did I miss critical risks or alternatives?
If any check fails, revise before delivering.
