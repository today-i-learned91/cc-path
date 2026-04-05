# Troubleshooting -- Common Issues and Fixes

---

## Hooks Not Running

**Symptom**: Claude runs a blocked command (e.g., `git push --force`) without any
interception. No deny message appears.

**Cause 1: Hook not wired in settings.json**

Check that the hook entry exists and uses the correct matcher:

```bash
cat .claude/settings.json
```

Expected entry for deploy-guard:

```json
{
  "matcher": "Bash",
  "hooks": [{"type": "command", "command": ".claude/hooks/deploy-guard.sh", "timeout": 5}]
}
```

If the entry is missing, add it. If it is present, check the `matcher` value -- a
deploy guard wired to `Edit` will never fire on `Bash` commands.

**Cause 2: Hook script not executable**

```bash
ls -la .claude/hooks/
```

Scripts must have execute permission (`-rwxr-xr-x`). Fix with:

```bash
chmod +x .claude/hooks/*.sh
```

**Cause 3: Script path is wrong**

The `command` field in settings.json is relative to the project root. Verify:

```bash
CLAUDE_TOOL_INPUT='{"command":"git push --force origin main"}' \
  .claude/hooks/deploy-guard.sh; echo "Exit: $?"  # Should print 2
```

---

## Claude Ignoring CLAUDE.md Rules

**Symptom**: Claude does not follow a rule you defined in CLAUDE.md or a rules file.

**Cause 1: File too long -- rules are losing attention**

Rules buried in a 500-line CLAUDE.md are deprioritized under token pressure.
Check your Layer 1 size:

```bash
npx cc-path budget
```

If Layer 1 exceeds 3K tokens, trim. Target: root CLAUDE.md under 80 lines,
`.claude/CLAUDE.md` under 60 lines.

**Cause 2: Conflicting rules between layers**

Load order: `Managed -> User -> Project (root->CWD) -> Local -> AutoMem`.
Later files override earlier ones. A rule in `.claude/CLAUDE.md` wins over
the same rule in root `CLAUDE.md`. Search for conflicts with Grep across
both CLAUDE.md files and `.claude/rules/`.

**Cause 3: Rule is conditional but not triggering**

A rule with `paths:` frontmatter only loads when Claude accesses a matching file.
If Claude has not read any matching file in the session, the rule is not in context.
Ask Claude: "What rules are currently loaded?" to verify.

To make a rule always load, remove the `paths:` frontmatter. Be aware this adds
tokens to every request.

---

## Token Budget Exceeded

**Symptom**: `npx cc-path budget` reports Layer 1 over 3K tokens, or Claude's
responses feel slower and less focused on the task.

**Fix 1: Move unconditional rules to conditional**

Find rules without `paths:` frontmatter: `grep -rL "^paths:" .claude/rules/`

Add `paths:` restricted to relevant file types (e.g., `"**/*.ts"`). See
[COOKBOOK.md -- Creating a Conditional Rule](COOKBOOK.md) for the template.

**Fix 2: Trim CLAUDE.md**

Target sizes: root CLAUDE.md 80 lines / 4KB, `.claude/CLAUDE.md` 60 lines / 3KB,
individual rules 30 lines / 1.5KB. "Sometimes relevant" content belongs in a
conditional rule. "Workflow-specific" content belongs in a skill.

**Fix 3: Move reference content to docs/**

Files in `docs/` load only on explicit `Read`. Extract rule content over 30 lines
to `docs/` and leave a one-line reference in the rule pointing to the doc path.

---

## Circuit Breaker Tripped

**Symptom**: Claude cannot perform any Edit, Write, or Bash operations. Every
mutation tool call is blocked with a message about consecutive failures.

**Check the counter file**:

```bash
ls /tmp/claude-circuit-breaker-* 2>/dev/null
cat /tmp/claude-circuit-breaker-$CLAUDE_SESSION_ID 2>/dev/null
```

If the file contains `5` or higher, the gate is blocking.

**Reset manually**:

```bash
CLAUDE_SESSION_ID=your-session-id .claude/hooks/circuit-breaker-reset.sh
# Or delete the file directly:
rm /tmp/claude-circuit-breaker-your-session-id
```

The session ID appears in Claude Code's output or in the audit log at
`/tmp/claude-audit-{session}/decisions.jsonl`.

**Investigate before resetting.** The breaker tripped because five consecutive tool
calls failed. Resetting without understanding why means it trips again immediately.
Check the audit log at `/tmp/claude-audit-{session}/decisions.jsonl` for the
failing commands. Common causes: wrong working directory, missing dependencies,
permission errors, or a broken command Claude kept retrying.
Source: `constants/prompts.ts:233` -- "diagnose why before switching tactics."

---

## `npx cc-path doctor` Score Is Low

**Symptom**: The doctor command reports a low score or lists missing components.

**Common missing pieces and fixes**:

| Missing | Fix |
|---------|-----|
| Hooks not executable | `chmod +x .claude/hooks/*.sh` |
| settings.json missing hook entries | Copy from `harness/.claude/settings.json` |
| No conditional rules | Add `paths:` frontmatter to at least one rule in `.claude/rules/` |
| No skills | Copy at least one skill from `skills/` to `.claude/skills/` |
| Layer 1 over budget | See Token Budget Exceeded above |

Run doctor again after each fix:

```bash
npx cc-path doctor
```

---

## Hook Blocks Legitimate Commands

**Symptom**: A command you intend to run is blocked by deploy-guard or cognitive-protection.

**deploy-guard** blocks patterns like `--force`, `npm publish`, `firebase deploy`.
If the command is legitimate, run it manually in your terminal rather than through Claude.

**cognitive-protection** flags sensitive patterns (auth, payments, PII) with an advisory
(asks for confirmation, does not hard-block). Reply with explicit confirmation to proceed.

**To add an exception**: edit the pattern list in the hook script with a comment explaining
why. Do not remove a pattern without understanding what it protects.

---

## Sub-Project Rules Not Loading

**Symptom**: A rule in `your-subproject/.claude/rules/` is not taking effect.

**Check**: Claude Code loads rules relative to the current working directory. If
Claude Code was started from the project root, CWD is the root, not the sub-project.
Rules in a sub-project's `.claude/rules/` load only when CWD is inside that
sub-project or when Claude accesses a matching file.

**Fix**: Start Claude Code from inside the sub-project directory, or use absolute
`paths:` patterns in the rule frontmatter that match the sub-project files:

```yaml
---
paths:
  - "your-subproject/**/*.py"
---
```
