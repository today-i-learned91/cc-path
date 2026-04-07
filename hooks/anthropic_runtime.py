#!/usr/bin/env python3
"""CC-Path v2.0 — Anthropic Runtime Kernel

Active enforcement engine extracted from Claude Code source analysis.
Implements 6 subsystems through Claude Code hooks:

1. GOLDE State Machine     — Legal phase transitions, not keyword voting
2. Evidence Tracker        — Per-file read/write/verify records
3. Cost Tracker            — Tool tier awareness, cheapest-first warnings
4. Agent Quality Scorer    — Positive scoring + anti-pattern detection
5. Verification Gate       — Gap reports for unverified modifications
6. Session Metrics         — Composite score + cross-session JSONL

Designed by 5 Anthropic-grade agents (Founder, CTO, Scientist, Eng Lead, Research Lead).
Pure Python stdlib. No LLM calls. No external deps. ~3s timeout per hook.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import time
from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any

# ─── Constants ──────────────────────────────────────────────────────

STATE_DIR = Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())) / ".cc-path"
RUNTIME_STATE = STATE_DIR / "runtime.json"
METRICS_FILE = STATE_DIR / "metrics.json"
SESSION_LOG = STATE_DIR / "sessions.jsonl"

MAX_FILES_TRACKED = 50
MAX_AGENT_CALLS = 30
MAX_PHASE_HISTORY = 30


# ─── Enums ──────────────────────────────────────────────────────────

class Phase(str, Enum):
    IDLE = "idle"
    ORIENT = "orient"
    ANALYZE = "analyze"
    PLAN = "plan"
    EXECUTE = "execute"
    VERIFY = "verify"
    LEARN = "learn"


class ToolTier(str, Enum):
    FREE = "free"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    EXPENSIVE = "expensive"


# ─── Legal GOLDE Transitions ───────────────────────────────────────

LEGAL_TRANSITIONS: dict[Phase, set[Phase]] = {
    Phase.IDLE:    {Phase.ORIENT, Phase.EXECUTE},
    Phase.ORIENT:  {Phase.ANALYZE, Phase.PLAN, Phase.EXECUTE},
    Phase.ANALYZE: {Phase.PLAN, Phase.EXECUTE, Phase.ORIENT},
    Phase.PLAN:    {Phase.EXECUTE, Phase.ANALYZE},
    Phase.EXECUTE: {Phase.VERIFY, Phase.ANALYZE},
    Phase.VERIFY:  {Phase.LEARN, Phase.EXECUTE, Phase.ORIENT},
    Phase.LEARN:   {Phase.IDLE, Phase.ORIENT},
}


# ─── Tool Classification ───────────────────────────────────────────

TOOL_TIERS: dict[str, ToolTier] = {
    "Glob": ToolTier.FREE,
    "Grep": ToolTier.FREE,
    "ToolSearch": ToolTier.FREE,
    "Read": ToolTier.LOW,
    "Bash": ToolTier.MEDIUM,
    "Write": ToolTier.HIGH,
    "Edit": ToolTier.HIGH,
    "MultiEdit": ToolTier.HIGH,
    "NotebookEdit": ToolTier.HIGH,
    "Agent": ToolTier.EXPENSIVE,
    "Task": ToolTier.EXPENSIVE,
    "WebSearch": ToolTier.EXPENSIVE,
    "WebFetch": ToolTier.EXPENSIVE,
}

BASH_READ_PATTERNS = [
    "git log", "git diff", "git status", "git blame", "git show",
    "ls ", "cat ", "head ", "tail ", "wc ", "file ",
    "test ", "type ", "which ", "echo ",
]

BASH_VERIFY_PATTERNS = [
    "pytest", "jest", "vitest", "mocha",
    "npm test", "yarn test", "pnpm test",
    "tsc --noemit", "mypy", "pyright", "ruff check",
    "eslint", "prettier --check", "cargo check", "cargo test",
    "go vet", "go test", "make test", "make check",
]


# ─── Phase Detection Signals ───────────────────────────────────────

PHASE_SIGNALS: dict[Phase, dict[str, Any]] = {
    Phase.ORIENT: {
        "keywords": [
            "what", "why", "understand", "current", "status", "read",
            "show", "explain", "describe", "overview", "find",
            "뭐", "무엇", "왜", "현재", "상태", "파악", "이해", "확인", "살펴", "보여", "알려",
        ],
        "weight": 1.0,
        "guidance": (
            "[GOLDE:ORIENT] Read Before Write. Classify evidence: FACT / INTERPRETATION / ASSUMPTION.\n"
            "Do NOT propose changes until you have read the relevant code."
        ),
    },
    Phase.ANALYZE: {
        "keywords": [
            "analyze", "cause", "root", "compare", "debug", "diagnose", "investigate", "bug", "error",
            "분석", "원인", "비교", "에러", "버그", "오류", "실패", "근본",
        ],
        "weight": 1.2,
        "guidance": (
            "[GOLDE:ANALYZE] Diagnose Before Switching. Form 2+ competing hypotheses.\n"
            "Cheapest-First: logs(free) -> grep(free) -> read(low) -> test(medium) -> modify(high)."
        ),
    },
    Phase.PLAN: {
        "keywords": [
            "plan", "design", "strategy", "approach", "how", "architect", "refactor",
            "계획", "설계", "전략", "어떻게", "접근", "구조", "리팩토링",
        ],
        "weight": 1.1,
        "guidance": (
            "[GOLDE:PLAN] Parallel Independent, Serial Dependent.\n"
            "Never Delegate Understanding: file:line specs required for every delegation."
        ),
    },
    Phase.EXECUTE: {
        "keywords": [
            "implement", "create", "modify", "change", "add", "remove", "fix", "write", "build", "make",
            "해줘", "만들어", "수정", "변경", "추가", "삭제", "구현", "적용", "작성",
        ],
        "weight": 1.0,
        "guidance": (
            "[GOLDE:EXECUTE] Minimum Necessary Change. Explicit Over Clever.\n"
            "One change at a time. Verify each before proceeding."
        ),
    },
    Phase.VERIFY: {
        "keywords": [
            "verify", "test", "check", "validate", "confirm", "review",
            "확인", "테스트", "검증", "동작", "통과", "리뷰", "검토",
        ],
        "weight": 1.3,
        "guidance": (
            "[GOLDE:VERIFY] Verify Before Claiming. Evidence, not intuition.\n"
            "Independent adversarial verification. Your own checks do NOT substitute."
        ),
    },
}


# ─── Compressed Skill Library (18 skills, ~150 tokens each) ────────

SKILL_COMPACT: dict[str, dict[str, Any]] = {
    "principles": {
        "priority": 1, "phases": "all",
        "compact": (
            "10 PRINCIPLES: 1)Read Before Write 2)Diagnose Before Switching "
            "3)Minimum Necessary Change 4)Parallel Independent,Serial Dependent "
            "5)Verify Before Claiming 6)Cheapest First 7)Fail Closed "
            "8)Never Delegate Understanding 9)Explicit Over Clever "
            "10)Cache Economics. GOLDE: Orient->Analyze->Plan->Execute->Verify->Learn. "
            "Classify: FACT/INTERPRETATION/ASSUMPTION."
        ),
    },
    "problem-solve": {
        "priority": 2, "phases": "orient,analyze",
        "compact": (
            "DEBUG: 1)Collect evidence(logs,traces) 2)Classify FACT/INTERP/ASSUMPTION "
            "3)2+ competing hypotheses 4)Cheapest-first: logs->grep->read->test->modify "
            "5)One change at a time,verify each 6)Circuit breaker:3 fails->rethink. "
            "Reversibility check before every action."
        ),
    },
    "architecture": {
        "priority": 2, "phases": "plan,execute",
        "compact": (
            "ARCH: 7-layer pipeline(deps flow down only). Fail-Closed defaults: "
            "isConcurrencySafe:false until proven. 35-line pub/sub store>Redux. "
            "Builder/Factory for safe defaults. Import cycles: types/ extraction, "
            "lazy require, registry pattern. Directory promotion: 3+ files."
        ),
    },
    "verify": {
        "priority": 1, "phases": "verify",
        "compact": (
            "VERIFY: Independent adversarial verification. Author!=Verifier. "
            "Fail-Closed: unknown=dangerous. Checklist: original problem solved? "
            "existing tests pass? new tests cover change? no side-effects? "
            "FACT-only conclusions? Circuit breaker: 3 consecutive fails->stop."
        ),
    },
    "strategic-plan": {
        "priority": 2, "phases": "plan",
        "compact": (
            "PLAN: Phase0:1-2steps=just do it. 3+=light tasklist. Arch=full Plan Mode. "
            "Phase1:parallel explore(3 read-only agents). Phase2:design A vs B. "
            "Phase3:read critical files. Phase4:tasks+file:line+deps. "
            "Phase5:approval->execute. Coordinator:Research->Synthesize->Implement->Verify."
        ),
    },
    "token-zero": {
        "priority": 3, "phases": "all",
        "compact": (
            "TOKEN: 8K output cap(99% sufficient,escalate to 64K). "
            "Deferred loading:name+hint only,ToolSearch on demand(30-50% saving). "
            "Cache scoping:static=global,dynamic=session. "
            "Big results:disk persist+2KB preview. "
            "3-tier compaction:micro->session-memory->full. Analysis-then-Strip."
        ),
    },
    "agent-mastery": {
        "priority": 2, "phases": "plan,execute",
        "compact": (
            "AGENTS: Explore(haiku,read-only)->Plan(read+analysis)->general-purpose(all)->fork(inherits). "
            "Fresh agent:full briefing(what,why,known,context,expected). "
            "Fork agent:just instruction(no background repeat). "
            "NEVER:'based on your findings,fix it.' "
            "ALWAYS:file:line+specific action+scope boundary+expected outcome."
        ),
    },
    "context-engine": {
        "priority": 3, "phases": "all",
        "compact": (
            "CONTEXT: Never truncate if you can persist. Never persist if you can defer. "
            "3-tier cascade: microcompact(cache-edit,free)->session-memory(10-40K)->full(9-section). "
            "Deferred tool loading. Memory: max 5 relevant, skip already-surfaced. "
            "Output budget: length/4 rough estimation."
        ),
    },
    "research": {
        "priority": 3, "phases": "orient,analyze",
        "compact": (
            "RESEARCH: Cheapest-First gates: known(0)->cache(low)->files(med)->API(high). "
            "Parallel independent directions(max 3). FACT/INTERP/ASSUMPTION classification. "
            "Explore->Design->Review 3-phase. Synthesize yourself, never delegate understanding."
        ),
    },
    "prompt-craft": {
        "priority": 4, "phases": "plan,execute",
        "compact": (
            "PROMPT: Identity->Constraints->Context order. "
            "Priority signals: CRITICAL>IMPORTANT>NEVER>MUST. "
            "7 rhetoric: consequence framing, positive-then-negative, concrete>abstract, "
            "persona, anti-pattern inoculation, scope anchoring, anti-gold-plating. "
            "Numeric anchors:'<=25 words between tool calls'."
        ),
    },
    "document-craft": {
        "priority": 4, "phases": "execute",
        "compact": (
            "DOCS: README:problem->solution->quickstart->API->contributing. "
            "ADR:context->decision->consequences. Chain-of-Density: "
            "iterative compression, entity preservation, fixed length, fusion. "
            "Technical docs: code as source of truth, link don't duplicate."
        ),
    },
    "multi-agent": {
        "priority": 3, "phases": "plan,execute",
        "compact": (
            "MULTI-AGENT: Lead synthesizes, Workers execute. "
            "3 backends: tmux(isolated)/in-process(low-latency)/remote(cloud). "
            "Mailbox communication(file-based,cross-process). Author!=Verifier. "
            "Parallel reads, serial same-file writes. "
            "Coordinator 4-stage: Research->Synthesize->Implement->Verify."
        ),
    },
    "agent-interconnect": {
        "priority": 4, "phases": "execute",
        "compact": (
            "INTERCONNECT: Skill->Hook->Agent->Doc organic linkage. "
            "Auto-routing by context detection. Cross-component orchestration. "
            "Hook events: UserPromptSubmit/PreToolUse/PostToolUse/Stop. "
            "Skill auto-detection by keyword/file-pattern matching."
        ),
    },
    "agent-automation": {
        "priority": 5, "phases": "execute",
        "compact": (
            "AUTOMATION: Cron triggers for recurring agents. Remote agent execution. "
            "Dream memory consolidation(24h+ gap, 5+ sessions). Hook automation. "
            "Proactive mode: agent initiates without user prompt. "
            "Session memory persistence across conversations."
        ),
    },
    "harness-craft": {
        "priority": 4, "phases": "execute",
        "compact": (
            "HARNESS: buildTool() factory with fail-closed defaults. "
            "Permission pipeline: validateInput->getDenyRule->checkPermissions->mode->classifier. "
            "Hook system: 4 events, matcher regex, timeout, command type. "
            "Streaming executor: AsyncGenerator pipeline. MCP integration."
        ),
    },
    "skill-forge": {
        "priority": 5, "phases": "execute",
        "compact": (
            "SKILLS: YAML frontmatter(name,description,whenToUse,model). "
            "3-tier source priority: bundled>plugin>mcp. "
            "Budget control: token limit per skill injection. "
            "Security: auto-approve for read-only skills."
        ),
    },
    "folder-mastery": {
        "priority": 5, "phases": "plan",
        "compact": (
            "FOLDERS: 7-layer classification. Directory promotion: 3+ files or UI/prompt split. "
            "4 naming conventions: PascalCase(class)/camelCase(util)/kebab-case(command)/SCREAMING(const). "
            "Registry pattern: single source of truth."
        ),
    },
    "runtime": {
        "priority": 5, "phases": "all",
        "compact": (
            "RUNTIME: Active enforcement via hooks. Phase state machine, evidence tracker, "
            "cost tracker, agent quality scorer, verification gate, session metrics. "
            "Soft gates only (warnings, not blocks)."
        ),
    },
}


# ─── Anti-patterns and Quality Indicators ──────────────────────────

DELEGATION_ANTI_PATTERNS = [
    "based on your findings",
    "based on the research",
    "based on what you found",
    "fix the issues you found",
    "implement what we discussed",
    "위에서 조사한 결과를",
    "조사 결과를 바탕으로",
    "찾은 것을 기반으로",
    "결과를 토대로",
    "알아낸 것을 바탕으로",
]

QUALITY_INDICATORS = {
    "file_ref": {
        "patterns": [
            r"\.ts:", r"\.tsx:", r"\.py:", r"\.js:", r"\.rs:", r"\.go:",
            r"\.java:", r"\.rb:", r"\.swift:", r"\.kt:",
            r"line \d+", r"라인 \d+", r":\d+",
        ],
        "weight": 0.3, "label": "file:line reference",
    },
    "specific_action": {
        "patterns": [
            "add ", "remove ", "change ", "replace ", "rename ", "move ",
            "extract ", "inline ", "wrap ", "unwrap ", "delete ",
            "추가해", "삭제해", "변경해", "수정해", "교체해",
        ],
        "weight": 0.2, "label": "specific action verb",
    },
    "scope_boundary": {
        "patterns": [
            "only ", "do not ", "don't ", "leave ", "skip ", "ignore ",
            "만 ", "하지 마", "건드리지", "그대로",
        ],
        "weight": 0.2, "label": "scope boundary",
    },
    "expected_outcome": {
        "patterns": [
            "should return", "should throw", "should render",
            "expect ", "result in ", "produce ",
            "반환해야", "에러가", "결과가",
        ],
        "weight": 0.15, "label": "expected outcome",
    },
    "context_why": {
        "patterns": [
            "because ", "since ", "to prevent ", "to fix ", "to enable ",
            "왜냐하면", "때문에", "방지하기", "해결하기",
        ],
        "weight": 0.15, "label": "reasoning/why",
    },
}


# ─── State Dataclass ───────────────────────────────────────────────

@dataclass
class RuntimeState:
    session_id: str = ""
    session_start: float = 0.0
    current_phase: str = "idle"
    phase_history: list[dict] = field(default_factory=list)
    phase_durations: dict[str, float] = field(default_factory=dict)
    phase_entry_time: float = 0.0
    files: dict[str, dict] = field(default_factory=dict)
    read_before_write_violations: int = 0
    tool_counts: dict[str, int] = field(default_factory=dict)
    tier_counts: dict[str, int] = field(default_factory=dict)
    cost_warnings: int = 0
    cheapest_first_violations: int = 0
    agent_calls: list[dict] = field(default_factory=list)
    total_agent_calls: int = 0
    quality_gate_blocks: int = 0
    avg_agent_quality: float = 0.0
    unverified_files: list[str] = field(default_factory=list)
    verification_runs: int = 0
    total_modifications: int = 0
    total_tool_calls: int = 0
    turn_count: int = 0


# ─── State I/O (Atomic) ────────────────────────────────────────────

def load_state() -> RuntimeState:
    try:
        if RUNTIME_STATE.exists():
            data = json.loads(RUNTIME_STATE.read_text())
            return RuntimeState(**{
                k: v for k, v in data.items()
                if k in RuntimeState.__dataclass_fields__
            })
    except (json.JSONDecodeError, OSError, TypeError):
        pass
    return RuntimeState(
        session_id=hashlib.md5(str(time.time()).encode()).hexdigest()[:8],
        session_start=time.time(),
    )


def save_state(state: RuntimeState) -> None:
    """Atomic write: temp + rename. Prevents TOCTOU."""
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        if len(state.files) > MAX_FILES_TRACKED:
            sorted_files = sorted(
                state.files.items(),
                key=lambda kv: kv[1].get("last_modified", 0) or kv[1].get("first_read", 0),
                reverse=True,
            )
            state.files = dict(sorted_files[:MAX_FILES_TRACKED])
        if len(state.agent_calls) > MAX_AGENT_CALLS:
            state.agent_calls = state.agent_calls[-MAX_AGENT_CALLS:]
        if len(state.phase_history) > MAX_PHASE_HISTORY:
            state.phase_history = state.phase_history[-MAX_PHASE_HISTORY:]

        temp = RUNTIME_STATE.with_suffix(".tmp")
        temp.write_text(json.dumps(asdict(state), indent=2, default=str))
        temp.replace(RUNTIME_STATE)
    except OSError:
        pass


# ─── Phase Detection ───────────────────────────────────────────────

def detect_phase_signal(text: str) -> tuple[Phase | None, float]:
    text_lower = text.lower()
    scores: dict[Phase, float] = {}
    for phase, config in PHASE_SIGNALS.items():
        keywords = config["keywords"]
        weight = float(config.get("weight", 1.0))
        hits = sum(1 for kw in keywords if kw in text_lower)
        if hits > 0:
            scores[phase] = hits * weight
    if not scores:
        return None, 0.0
    best = max(scores, key=scores.get)
    total = sum(scores.values())
    confidence = scores[best] / total if total > 0 else 0.0
    return best, confidence


def attempt_transition(state: RuntimeState, target: Phase, trigger: str) -> str:
    try:
        current = Phase(state.current_phase)
    except ValueError:
        current = Phase.IDLE

    legal = LEGAL_TRANSITIONS.get(current, set())

    if state.phase_entry_time > 0:
        duration = time.time() - state.phase_entry_time
        state.phase_durations[current.value] = state.phase_durations.get(current.value, 0.0) + duration

    is_legal = target in legal
    state.phase_history.append({
        "from": current.value,
        "to": target.value,
        "ts": time.time(),
        "trigger": trigger[:50],
        "legal": is_legal,
    })

    state.current_phase = target.value
    state.phase_entry_time = time.time()

    guidance = str(PHASE_SIGNALS.get(target, {}).get("guidance", ""))

    if not is_legal and current != Phase.IDLE:
        return (
            f"[GOLDE TRANSITION WARNING] {current.value} -> {target.value} is unusual.\n"
            f"Expected from {current.value}: {', '.join(p.value for p in legal)}.\n"
            f"{guidance}"
        )
    return guidance


# ─── Evidence Tracker ──────────────────────────────────────────────

def track_file_read(state: RuntimeState, file_path: str) -> None:
    if not file_path:
        return
    normalized = os.path.normpath(file_path)
    if normalized not in state.files:
        state.files[normalized] = {
            "path": normalized,
            "first_read": 0.0, "last_modified": 0.0, "last_verified": 0.0,
            "read_count": 0, "modify_count": 0, "verify_count": 0,
        }
    entry = state.files[normalized]
    if entry.get("first_read", 0.0) == 0.0:
        entry["first_read"] = time.time()
    entry["read_count"] = entry.get("read_count", 0) + 1


def track_file_modify(state: RuntimeState, file_path: str) -> str:
    if not file_path:
        return ""
    normalized = os.path.normpath(file_path)
    now = time.time()
    warning = ""

    if normalized not in state.files:
        state.files[normalized] = {
            "path": normalized,
            "first_read": 0.0, "last_modified": 0.0, "last_verified": 0.0,
            "read_count": 0, "modify_count": 0, "verify_count": 0,
        }

    entry = state.files[normalized]
    entry["last_modified"] = now
    entry["modify_count"] = entry.get("modify_count", 0) + 1
    state.total_modifications += 1

    if entry.get("first_read", 0.0) == 0.0:
        state.read_before_write_violations += 1
        warning = (
            f"[READ-BEFORE-WRITE VIOLATION] Modifying '{os.path.basename(normalized)}' "
            f"without reading it first.\n"
            "Principle #1: Never modify code you haven't read."
        )

    if normalized not in state.unverified_files:
        state.unverified_files.append(normalized)

    return warning


def track_file_verify(state: RuntimeState, file_paths: list[str]) -> None:
    now = time.time()
    for fp in file_paths:
        normalized = os.path.normpath(fp)
        if normalized in state.files:
            state.files[normalized]["last_verified"] = now
            state.files[normalized]["verify_count"] = (
                state.files[normalized].get("verify_count", 0) + 1
            )
        if normalized in state.unverified_files:
            state.unverified_files.remove(normalized)
    state.verification_runs += 1


# ─── Cost Tracker ──────────────────────────────────────────────────

def classify_bash_tier(command: str) -> ToolTier:
    cmd_lower = command.lower().strip()
    for pattern in BASH_READ_PATTERNS:
        if cmd_lower.startswith(pattern):
            return ToolTier.FREE
    for pattern in BASH_VERIFY_PATTERNS:
        if pattern in cmd_lower:
            return ToolTier.LOW
    return ToolTier.MEDIUM


def is_bash_verification(command: str) -> bool:
    cmd_lower = command.lower()
    return any(p in cmd_lower for p in BASH_VERIFY_PATTERNS)


def track_tool_cost(state: RuntimeState, tool_name: str, tool_input: dict) -> str:
    state.total_tool_calls += 1
    state.tool_counts[tool_name] = state.tool_counts.get(tool_name, 0) + 1

    tier = TOOL_TIERS.get(tool_name, ToolTier.MEDIUM)
    if tool_name == "Bash":
        command = tool_input.get("command", "")
        tier = classify_bash_tier(command)

    state.tier_counts[tier.value] = state.tier_counts.get(tier.value, 0) + 1

    warning = ""
    try:
        current = Phase(state.current_phase)
    except ValueError:
        current = Phase.IDLE

    if tier in (ToolTier.HIGH, ToolTier.EXPENSIVE):
        if current in (Phase.ORIENT, Phase.ANALYZE):
            state.cheapest_first_violations += 1
            state.cost_warnings += 1
            warning = (
                f"[CHEAPEST-FIRST] Using {tier.value}-cost tool '{tool_name}' during {current.value} phase.\n"
                "During Orient/Analyze, prefer: Glob/Grep(free) -> Read(low) -> Bash-readonly(free).\n"
                "Save writes and agents for Execute phase."
            )
    return warning


# ─── Agent Quality Scorer ──────────────────────────────────────────

def score_agent_prompt(prompt: str) -> tuple[float, list[str], list[str]]:
    prompt_lower = prompt.lower()
    score = 0.0
    strengths: list[str] = []
    weaknesses: list[str] = []

    for pattern in DELEGATION_ANTI_PATTERNS:
        if pattern in prompt_lower:
            score -= 0.3
            weaknesses.append(f"Anti-pattern: '{pattern}'")

    for key, config in QUALITY_INDICATORS.items():
        patterns = config["patterns"]
        weight = config["weight"]
        label = config["label"]
        found = False
        for p in patterns:
            try:
                if re.search(p, prompt_lower):
                    found = True
                    break
            except re.error:
                if p in prompt_lower:
                    found = True
                    break
        if found:
            score += weight
            strengths.append(label)
        elif weight >= 0.2:
            weaknesses.append(f"Missing: {label}")

    if len(prompt) < 50:
        score -= 0.1
        weaknesses.append("Prompt too short")

    return max(0.0, min(1.0, score)), strengths, weaknesses


def check_agent_quality(state: RuntimeState, prompt: str) -> str:
    score, strengths, weaknesses = score_agent_prompt(prompt)

    state.agent_calls.append({
        "ts": time.time(),
        "len": len(prompt),
        "score": score,
        "has_anti_pattern": any(p in prompt.lower() for p in DELEGATION_ANTI_PATTERNS),
    })
    state.total_agent_calls += 1

    scores = [c.get("score", 0) for c in state.agent_calls]
    state.avg_agent_quality = sum(scores) / len(scores) if scores else 0.0

    if score < 0.3:
        state.quality_gate_blocks += 1
        parts = [f"[QUALITY GATE] Score: {score:.1f}/1.0 — Never Delegate Understanding."]
        if weaknesses:
            parts.append("Issues: " + "; ".join(weaknesses[:3]))
        parts.append("Fix: Synthesize understanding yourself, delegate with file:line specs.")
        return "\n".join(parts)
    elif score < 0.6:
        parts = [f"[QUALITY HINT] Score: {score:.1f}/1.0."]
        if weaknesses:
            parts.append("Could improve: " + "; ".join(weaknesses[:2]))
        return "\n".join(parts)
    return ""


# ─── Verification Gate ─────────────────────────────────────────────

def build_verification_report(state: RuntimeState) -> str:
    unverified = state.unverified_files
    count = len(unverified)
    if count == 0:
        return ""

    if count >= 5:
        files = "\n".join(f"  - {os.path.basename(f)}" for f in unverified[:8])
        if count > 8:
            files += f"\n  ... and {count - 8} more"
        return (
            f"[VERIFICATION GAP] {count} files modified without verification.\n"
            f"Unverified:\n{files}\n"
            "Action: Run tests, type check, or lint to verify these changes."
        )
    elif count >= 3:
        return (
            f"[VERIFY HINT] {count} files modified since last verification.\n"
            "Consider running a quick check before continuing."
        )
    return ""


# ─── Skill Selection ───────────────────────────────────────────────

def select_skills_for_phase(phase: str, turn_count: int) -> str:
    selected = []
    for name, skill in SKILL_COMPACT.items():
        phases = str(skill["phases"])
        if phases == "all" or phase in phases.split(","):
            selected.append((int(skill["priority"]), name, str(skill["compact"])))

    selected.sort(key=lambda x: x[0])
    max_skills = 3 if turn_count > 10 else 4

    parts = [s[2] for s in selected[:max_skills]]
    if not parts:
        return ""
    return "[CC-PATH SKILLS]\n" + "\n---\n".join(parts)


# ─── Metrics ───────────────────────────────────────────────────────

def compute_metrics(state: RuntimeState) -> dict:
    total_files = len(state.files)
    modified = sum(1 for f in state.files.values() if f.get("modify_count", 0) > 0)
    verified = sum(
        1 for f in state.files.values()
        if f.get("last_verified", 0) > f.get("last_modified", 0) > 0
    )
    evidence_coverage = verified / modified if modified > 0 else 1.0

    rbw_compliant = sum(
        1 for f in state.files.values()
        if f.get("modify_count", 0) > 0
        and f.get("first_read", 0) > 0
        and f.get("first_read", 0) < f.get("last_modified", 0)
    )
    rbw_rate = rbw_compliant / modified if modified > 0 else 1.0

    total_tools = state.total_tool_calls
    expensive = state.tier_counts.get("high", 0) + state.tier_counts.get("expensive", 0)
    cost_efficiency = 1.0 - (expensive / total_tools) if total_tools > 0 else 1.0

    phase_order = [p.get("to", "") for p in state.phase_history]
    golde_compliant = True
    for i, phase in enumerate(phase_order):
        if phase == "execute" and "orient" not in phase_order[:i] and "analyze" not in phase_order[:i]:
            golde_compliant = False
            break

    composite = (
        rbw_rate * 0.2
        + evidence_coverage * 0.25
        + cost_efficiency * 0.15
        + state.avg_agent_quality * 0.15
        + evidence_coverage * 0.25
    )

    return {
        "session_id": state.session_id,
        "timestamp": time.time(),
        "duration_seconds": time.time() - state.session_start if state.session_start > 0 else 0,
        "golde_compliant": golde_compliant,
        "read_before_write_rate": round(rbw_rate, 3),
        "cheapest_first_violations": state.cheapest_first_violations,
        "phase_coverage": list(set(phase_order)),
        "files_tracked": total_files,
        "files_modified": modified,
        "files_verified": verified,
        "evidence_coverage": round(evidence_coverage, 3),
        "total_tool_calls": total_tools,
        "tier_distribution": dict(state.tier_counts),
        "cost_efficiency": round(cost_efficiency, 3),
        "cost_warnings": state.cost_warnings,
        "total_agent_calls": state.total_agent_calls,
        "avg_agent_quality": round(state.avg_agent_quality, 3),
        "quality_gate_blocks": state.quality_gate_blocks,
        "verification_runs": state.verification_runs,
        "unverified_files": len(state.unverified_files),
        "composite_score": round(composite, 3),
    }


def save_metrics(state: RuntimeState) -> None:
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        metrics = compute_metrics(state)
        METRICS_FILE.write_text(json.dumps(metrics, indent=2))
        with open(SESSION_LOG, "a") as f:
            f.write(json.dumps(metrics) + "\n")
    except OSError:
        pass


# ─── Hook Handlers ─────────────────────────────────────────────────

def handle_user_prompt_submit(hook_input: dict, state: RuntimeState) -> dict:
    content = hook_input.get("content", "")
    if isinstance(content, list):
        content = " ".join(b.get("text", "") for b in content if isinstance(b, dict))
    if not content:
        return {}

    state.turn_count += 1
    target_phase, confidence = detect_phase_signal(str(content))
    if target_phase is None or confidence < 0.3:
        return {}

    guidance = attempt_transition(state, target_phase, f"prompt:{str(content)[:50]}")
    skill_context = select_skills_for_phase(state.current_phase, state.turn_count)

    parts = [p for p in [guidance, skill_context] if p]

    if state.current_phase == "execute":
        gap = build_verification_report(state)
        if gap:
            parts.append(gap)

    save_state(state)
    if parts:
        return {"additionalContext": "\n\n".join(parts)}
    return {}


def handle_pre_tool_use(hook_input: dict, state: RuntimeState) -> dict:
    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})

    cost_warning = track_tool_cost(state, tool_name, tool_input)

    agent_message = ""
    if tool_name in ("Agent", "Task"):
        prompt = tool_input.get("prompt", "")
        agent_message = check_agent_quality(state, prompt)

    parts = [p for p in [cost_warning, agent_message] if p]
    save_state(state)
    if parts:
        return {"additionalContext": "\n".join(parts)}
    return {}


def handle_post_tool_use(hook_input: dict, state: RuntimeState) -> dict:
    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})
    messages: list[str] = []

    if tool_name == "Read":
        track_file_read(state, tool_input.get("file_path", ""))

    if tool_name in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        warning = track_file_modify(state, tool_input.get("file_path", ""))
        if warning:
            messages.append(warning)

    if tool_name == "Bash":
        command = tool_input.get("command", "")
        if is_bash_verification(command):
            track_file_verify(state, list(state.unverified_files))
            if state.current_phase == "execute":
                attempt_transition(state, Phase.VERIFY, f"bash_verify:{command[:30]}")

    if tool_name in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        gap = build_verification_report(state)
        if gap:
            messages.append(gap)

    if state.total_tool_calls % 20 == 0 and state.total_tool_calls > 0:
        save_metrics(state)

    save_state(state)
    if messages:
        return {"additionalContext": "\n\n".join(messages)}
    return {}


def handle_stop(hook_input: dict, state: RuntimeState) -> dict:
    save_metrics(state)
    save_state(state)
    return {}


# ─── Main ──────────────────────────────────────────────────────────

def main() -> None:
    try:
        hook_input = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, EOFError, ValueError):
        print(json.dumps({}))
        return

    hook_event = os.environ.get("CLAUDE_HOOK_EVENT", "")
    state = load_state()

    handlers = {
        "UserPromptSubmit": handle_user_prompt_submit,
        "PreToolUse": handle_pre_tool_use,
        "PostToolUse": handle_post_tool_use,
        "Stop": handle_stop,
        "Notification": handle_stop,
    }

    handler = handlers.get(hook_event)
    if handler:
        try:
            result = handler(hook_input, state)
            print(json.dumps(result))
        except Exception:
            print(json.dumps({}))
    else:
        print(json.dumps({}))


if __name__ == "__main__":
    main()
