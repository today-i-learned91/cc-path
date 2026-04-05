# FAQ -- Frequently Asked Questions

---

**Does cc-path work with Cursor, Windsurf, or other AI coding tools?**

The *principles* transfer -- layered context, guidance vs governance, evidence
hierarchy -- but the file format does not. CLAUDE.md, `.claude/rules/`, `.claude/skills/`,
and hook wiring via `settings.json` are Claude Code-specific. If your tool supports
analogous configuration (system prompts, pre-action hooks), apply the same architecture
with its native format.

---

**How do I know if my CLAUDE.md is too long?**

Run `npx cc-path budget` to measure Layer 1 token usage. The target is under 3K tokens
for the combined root CLAUDE.md and `.claude/CLAUDE.md`. As a rough check: if either
file exceeds 80 lines, it likely contains content that belongs in a conditional rule
or a skill. See [COOKBOOK.md -- Token Budget Optimization](COOKBOOK.md) for the audit
process.

---

**Can I use cc-path with an existing project?**

Yes. Run `npx cc-path init` to scaffold the harness into your current directory.
It creates `.claude/hooks/`, `.claude/rules/`, and `.claude/skills/` without
overwriting existing files. Review the generated `harness/CLAUDE.md` and merge
relevant sections into your existing CLAUDE.md rather than replacing it wholesale.

---

**What is the difference between rules and skills?**

The difference is loading behavior. Rules in `.claude/rules/` load automatically --
either on every request (no `paths:` frontmatter) or when matching files are accessed
(with `paths:`). Skills in `.claude/skills/` load only their frontmatter (~70 tokens)
automatically; the full body loads only when explicitly invoked (`/skill-name`).

Use rules for guidance that should always be available or available when specific
file types are in scope. Use skills for workflows and protocols that are invoked
on demand and would waste tokens if loaded unconditionally.

---

**Why are hooks in shell scripts, not in CLAUDE.md?**

Because CLAUDE.md is guidance (~80% compliance) and hooks are governance (100%
enforcement). Under token pressure -- late in a long session, after compaction --
Claude may de-prioritize CLAUDE.md instructions. A PreToolUse hook that exits with
code 2 blocks the tool call before the model acts on it. The model cannot override it.

For safety-critical constraints (deploy protection, secret detection, failure loop
prevention), 80% is not acceptable. Those constraints live in hooks. See
[WHY.md -- Guidance vs Governance](WHY.md) for the full rationale.

---

**How do I disable a specific hook?**

Remove or comment out its entry in `.claude/settings.json`. For example, to disable
the input sanitizer:

```json
"PreToolUse": [
  // Remove or comment out this block:
  // {
  //   "matcher": "Bash|WebFetch|mcp__*",
  //   "hooks": [{"type": "command", "command": ".claude/hooks/input-sanitizer.sh"}]
  // }
]
```

Do not delete the script file -- you may want to re-enable it later. Removing the
settings.json entry is sufficient.

---

**What happens if a hook script fails or crashes?**

If a hook exits with code 1 (error) rather than code 0 (allow) or code 2 (block),
Claude Code logs the failure and continues -- it does not treat a script error as a
block. This means a broken hook silently stops enforcing. After changing a hook,
verify it exits correctly:

```bash
echo '{"command":"git push --force"}' | CLAUDE_TOOL_INPUT='{"command":"git push --force"}' .claude/hooks/deploy-guard.sh
echo $?  # Should print 2
```

The circuit breaker handles *tool call* failures, not hook script failures. A
crashing hook does not trip the circuit breaker.

---

**How does the circuit breaker work?**

Three scripts, three hook events:

- `circuit-breaker.sh` (PostToolUseFailure): increments a counter in `/tmp/claude-circuit-breaker-{session}`. At 3 consecutive failures, injects a warning. At 5, blocks all mutation tool calls.
- `circuit-breaker-gate.sh` (PreToolUse): reads the counter and blocks if it is 5 or above.
- `circuit-breaker-reset.sh` (PostToolUse): resets the counter to 0 on any success.

The counter resets automatically when any tool call succeeds. You only need to manually
reset if a session is stuck with the gate blocking everything. See
[TROUBLESHOOTING.md -- Circuit Breaker Tripped](TROUBLESHOOTING.md).

---

**What is the token budget for Layer 1?**

Layer 1 is everything that loads on every request: root `CLAUDE.md` plus `.claude/CLAUDE.md`.
The target is 2-3K tokens total. The reference implementation measures at approximately
2.5K tokens idle. For comparison, a monolithic 500-line CLAUDE.md costs roughly 4K tokens
before Claude reads a single line of your code.

Run `npx cc-path budget` for an exact measurement of your current workspace.

---

**Why not just use a long CLAUDE.md instead of layers?**

Two reasons. First, LLMs have quadratic attention cost -- every token in context
degrades the quality of attention on every other token. A 600-line CLAUDE.md burns
~4K tokens on every request, including requests where 90% of that content is irrelevant.

Second, long CLAUDE.md files get ignored. When context fills, Claude de-prioritizes
older or lower-signal content. A short, dense Layer 1 plus targeted conditional rules
keeps only relevant context in scope at any moment. Source: `getMemoryFiles` in
`claudemd.ts`; Anthropic Engineering Blog on context engineering.

---

**Can I use cc-path with oh-my-claudecode (OMC)?**

Yes. They operate at different layers and do not conflict. cc-path provides governance
(hooks enforce hard limits). OMC provides orchestration (coordinates complex multi-agent
work). cc-path hooks fire on every tool call, including calls made by OMC agents --
governance is not bypassed by orchestration.

For setup instructions and the merged `settings.json` template, see
[ADOPTING-WITH-OMC.md](../docs/ADOPTING-WITH-OMC.md).

---

**Why not just copy a CLAUDE.md from the internet?**

Because you would not understand why any of it works, which means you cannot adapt it
when it does not fit your project, debug it when it behaves unexpectedly, or prune it
when it becomes stale. cc-path's design traces every decision to an Anthropic paper or
Claude Code source file. Understanding the rationale is what lets you make informed
modifications rather than cargo-culting.

---

**How do I contribute?**

See [CONTRIBUTING.md](../CONTRIBUTING.md). The bar: every principle must have a source
citation (Anthropic paper, Claude Code source file, or blog URL), harness changes must
fit the token budget, and changes must be tested in a real Claude Code session.
