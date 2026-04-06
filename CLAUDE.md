# cc-path — Anthropic-Grade AI Agent Operating System

Claude Code plugin that transforms passive knowledge into an **active runtime kernel**.
Extracted from scientific analysis of Claude Code's source (1905 files, 804KB system prompt).

## What This Does

Every session automatically enforces Anthropic's own engineering principles:
- **GOLDE Phase Tracker** — Detects cognitive phase (Orient→Analyze→Plan→Execute→Verify) and injects phase-specific guidance
- **Agent Quality Gate** — Catches "Never Delegate Understanding" violations before agent prompts are sent
- **Verification Enforcer** — Tracks file modifications and nudges verification after 3-5 unverified edits
- **18 Method Skills** — Prompt engineering, architecture, testing, context management, token efficiency, and more

## The 10 Principles (Always Active)

1. **Read Before Write** — Never modify code you haven't read
2. **Diagnose Before Switching** — Find root cause before changing approach
3. **Minimum Necessary Change** — Only change what was asked
4. **Parallel Independent, Serial Dependent** — Maximize concurrency safely
5. **Verify Before Claiming** — Prove completion with evidence, not intuition
6. **Cheapest First** — Exhaust low-cost sources before expensive operations
7. **Fail Closed** — When uncertain, fail to the safe side
8. **Never Delegate Understanding** — Synthesize understanding yourself, delegate with specific specs
9. **Explicit Over Clever** — Three similar lines beat a premature abstraction
10. **Cache Economics Drive Architecture** — Minimize repetition costs

## Skill Auto-Detection

Skills activate automatically based on context — no slash commands needed:

| Context Detected | Primary Skill | Secondary |
|-----------------|--------------|-----------|
| Code writing | principles | architecture |
| Debugging | problem-solve | verify |
| Planning | strategic-plan | research |
| Documentation | document-craft | prompt-craft |
| Agent delegation | agent-mastery | token-zero |
| Research | research | context-engine |
| Multi-agent work | multi-agent | agent-automation |

## Hook Registration

Add to your project's `.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "CLAUDE_HOOK_EVENT=UserPromptSubmit python3 hooks/anthropic_runtime.py", "timeout": 3}]}],
    "PreToolUse": [{"matcher": "Agent", "hooks": [{"type": "command", "command": "CLAUDE_HOOK_EVENT=PreToolUse python3 hooks/anthropic_runtime.py", "timeout": 5}]}],
    "PostToolUse": [{"matcher": "Write|Edit|MultiEdit|Bash", "hooks": [{"type": "command", "command": "CLAUDE_HOOK_EVENT=PostToolUse python3 hooks/anthropic_runtime.py", "timeout": 3}]}]
  }
}
```
