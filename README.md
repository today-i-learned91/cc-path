# cc-path

**Anthropic-grade AI agent methodology for Claude Code.**

Transform how you use Claude Code — from passive chat to an active operating system that enforces Anthropic's own engineering principles in real-time.

---

## What is cc-path?

cc-path is a Claude Code plugin extracted from **scientific analysis of Claude Code's own source code** (1905 files, 804KB system prompt, 302 directories). We reverse-engineered how Anthropic builds, thinks, and operates — then packaged it as an actionable skill system with runtime enforcement.

### Before cc-path
```
You: "Fix this bug"
Claude: *reads some code, makes changes, says "done"*
Result: Maybe works. No verification. No systematic approach.
```

### After cc-path
```
You: "Fix this bug"
Claude: 
  → [GOLDE:ORIENT] Auto-detected: problem-solving phase
  → Reads error, classifies FACT/INTERPRETATION/ASSUMPTION
  → [GOLDE:ANALYZE] Competing hypotheses, cheapest-first investigation
  → [GOLDE:EXECUTE] Minimum necessary change
  → [VERIFY NUDGE] 3 files modified without verification — running tests
  → Evidence-based completion with proof
```

---

## Features

### 18 Methodology Skills
Automatically activated by context — no slash commands needed.

| Category | Skills | Trigger Examples |
|----------|--------|-----------------|
| **Core Methods** | `anthropic-principles`, `anthropic-prompt-craft`, `anthropic-document-craft` | Any task (always active) |
| **Problem Solving** | `anthropic-problem-solve`, `anthropic-verify`, `anthropic-research` | "debug", "fix", "investigate", "analyze" |
| **Planning & Design** | `anthropic-strategic-plan`, `anthropic-architecture`, `anthropic-folder-mastery` | "plan", "design", "refactor", "structure" |
| **Agent Mastery** | `anthropic-agent-mastery`, `anthropic-multi-agent`, `anthropic-agent-automation`, `anthropic-agent-interconnect` | "delegate", "parallel", "team", "agent" |
| **Efficiency** | `anthropic-context-engine`, `anthropic-token-zero` | "optimize", "efficient", "token", "context" |
| **Meta** | `anthropic-skill-forge`, `anthropic-harness-craft`, `anthropic-runtime` | "create skill", "hook", "harness" |

### Runtime Kernel (3 Active Hooks)

| Hook | Event | What It Does |
|------|-------|-------------|
| **GOLDE Phase Tracker** | `UserPromptSubmit` | Detects Orient/Analyze/Plan/Execute/Verify phase from your input and injects phase-appropriate principles |
| **Agent Quality Gate** | `PreToolUse:Agent` | Catches vague delegation ("based on your findings, fix it") and nudges toward specific file:line specs |
| **Verification Enforcer** | `PostToolUse:Edit` | Counts unverified file modifications; nudges at 3, enforces at 5 |

### Auto-Inject Guide
Keyword detection automatically loads methodology context when relevant topics appear in conversation — no manual invocation needed.

---

## Installation

### Option 1: Add as project dependency
```bash
git clone https://github.com/today-i-learned91/cc-path.git
cd your-project
claude --add-dir /path/to/cc-path
```

### Option 2: Global skills installation
```bash
git clone https://github.com/today-i-learned91/cc-path.git
cp -r cc-path/.claude/skills/anthropic-* ~/.claude/skills/
cp cc-path/hooks/anthropic_runtime.py ~/your-project/tools/hooks/
```

### Option 3: Cherry-pick skills
```bash
# Only install specific skills you want
cp -r cc-path/.claude/skills/anthropic-principles ~/.claude/skills/
cp -r cc-path/.claude/skills/anthropic-problem-solve ~/.claude/skills/
```

### Register Hooks (Optional but Recommended)
Add to your `.claude/settings.json`:
```json
{
  "hooks": {
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "CLAUDE_HOOK_EVENT=UserPromptSubmit python3 hooks/anthropic_runtime.py", "timeout": 3}]}],
    "PreToolUse": [{"matcher": "Agent", "hooks": [{"type": "command", "command": "CLAUDE_HOOK_EVENT=PreToolUse python3 hooks/anthropic_runtime.py", "timeout": 5}]}],
    "PostToolUse": [{"matcher": "Write|Edit|MultiEdit|Bash", "hooks": [{"type": "command", "command": "CLAUDE_HOOK_EVENT=PostToolUse python3 hooks/anthropic_runtime.py", "timeout": 3}]}]
  }
}
```

---

## The 10 Principles

Extracted from Claude Code's actual system prompt and architectural decisions:

| # | Principle | Source |
|---|-----------|--------|
| 1 | **Read Before Write** | System prompt: "do not propose changes to code you haven't read" |
| 2 | **Diagnose Before Switching** | System prompt: "read the error, check your assumptions, try a focused fix" |
| 3 | **Minimum Necessary Change** | System prompt: "Don't add features beyond what was asked" |
| 4 | **Parallel Independent, Serial Dependent** | StreamingToolExecutor: concurrent-safe tools run in parallel |
| 5 | **Verify Before Claiming** | Verification Agent: "independent adversarial verification" |
| 6 | **Cheapest First** | Dream system gate sequence: time→session→lock (cheapest first) |
| 7 | **Fail Closed** | `TOOL_DEFAULTS.isConcurrencySafe: false` — safe until proven otherwise |
| 8 | **Never Delegate Understanding** | Coordinator prompt: "Never write 'based on your findings'" |
| 9 | **Explicit Over Clever** | System prompt: "Three similar lines > premature abstraction" |
| 10 | **Cache Economics** | `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` — static/dynamic split for fleet caching |

---

## How It Was Built

1. **10 Opus agents** analyzed Claude Code's source in parallel
2. **7 analysis domains**: Architecture, Prompt Engineering, Context Management, Tool System, Planning, Testing, Query Pipeline
3. **1905 files** read, including the 804KB `main.tsx` system prompt
4. Patterns extracted at the **line-number level** with exact references
5. Synthesized into **actionable skills** with auto-detection triggers
6. Runtime kernel transforms passive knowledge into **active enforcement**

---

## Architecture

```
cc-path/
├── CLAUDE.md                          # 10 principles + skill routing (always loaded)
├── .claude/skills/                    # 18 methodology skills
│   ├── anthropic-principles/          # Unified philosophy & frameworks
│   ├── anthropic-prompt-craft/        # Prompt engineering methodology
│   ├── anthropic-document-craft/      # Documentation patterns
│   ├── anthropic-strategic-plan/      # 5-phase planning workflow
│   ├── anthropic-problem-solve/       # Diagnostic problem-solving
│   ├── anthropic-architecture/        # Software design methodology
│   ├── anthropic-verify/              # Testing & verification
│   ├── anthropic-research/            # Research methodology
│   ├── anthropic-context-engine/      # Context window management
│   ├── anthropic-token-zero/          # Token efficiency mastery
│   ├── anthropic-folder-mastery/      # Directory organization
│   ├── anthropic-skill-forge/         # Skill creation methodology
│   ├── anthropic-harness-craft/       # Harness & tool design
│   ├── anthropic-agent-mastery/       # AI agent utilization
│   ├── anthropic-multi-agent/         # Multi-agent orchestration
│   ├── anthropic-agent-automation/    # Agent automation & scheduling
│   ├── anthropic-agent-interconnect/  # Cross-component orchestration
│   └── anthropic-runtime/             # Runtime kernel documentation
├── hooks/
│   └── anthropic_runtime.py           # 3-layer active enforcement
└── guides/
    └── anthropic-methods.md           # Auto-inject methodology guide
```

---

## License

MIT

---

## Credits

Built by analyzing [Claude Code](https://claude.ai/code) source with Claude Code itself.
Methodology extracted from Anthropic's engineering principles, not affiliated with Anthropic.
