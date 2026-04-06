#!/usr/bin/env python3
"""Anthropic Runtime Kernel — CC-Path Active Enforcement

3개 핵심 기능:
1. GOLDE Phase Tracker — 현재 인지 단계를 추적하고 단계별 가이드 주입
2. Agent Quality Gate — "Never Delegate Understanding" 위반 감지
3. Auto-Verification Enforcer — 3+ 태스크 후 검증 강제

Hook events:
  - UserPromptSubmit → GOLDE 단계 감지 + 컨텍스트 주입
  - PreToolUse (Agent) → 프롬프트 품질 게이트
  - PostToolUse → 태스크 완료 추적 + 검증 넛지
"""
import json
import os
import sys
import time
from pathlib import Path

# State file for cross-turn persistence
STATE_DIR = Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())) / ".omc" / "state"
RUNTIME_STATE = STATE_DIR / "anthropic_runtime.json"

# ─── GOLDE Phase Detection ───────────────────────────────────────────

PHASE_SIGNALS = {
    "orient": {
        "keywords": [
            "뭐", "무엇", "어떤", "왜", "현재", "상태", "파악", "이해",
            "what", "why", "understand", "current", "status", "read",
            "확인", "살펴", "보여", "알려",
        ],
        "guidance": (
            "[GOLDE:ORIENT] 현재 단계: 문제 정의 & 증거 수집.\n"
            "→ Read Before Write: 코드를 읽기 전에 수정 제안 금지.\n"
            "→ FACT/INTERPRETATION/ASSUMPTION으로 분류하며 진행."
        ),
    },
    "analyze": {
        "keywords": [
            "분석", "원인", "이유", "비교", "차이", "왜", "근본",
            "analyze", "cause", "root", "compare", "differ", "debug",
            "에러", "버그", "오류", "실패",
        ],
        "guidance": (
            "[GOLDE:ANALYZE] 현재 단계: 가설 수립 & 증거 분석.\n"
            "→ Diagnose Before Switching: 실패 원인 파악 후 전략 변경.\n"
            "→ 경쟁 가설 2+ 수립. Cheapest-First 탐색 순서 적용."
        ),
    },
    "plan": {
        "keywords": [
            "계획", "플랜", "설계", "전략", "어떻게", "접근", "방법",
            "plan", "design", "strategy", "approach", "how", "architect",
            "구조", "리팩토링", "마이그레이션",
        ],
        "guidance": (
            "[GOLDE:PLAN] 현재 단계: 작업 분해 & 의존성 분석.\n"
            "→ 독립 작업은 병렬, 의존 작업은 직렬.\n"
            "→ Never Delegate Understanding: 위임 시 파일:라인 수준 스펙 필수."
        ),
    },
    "execute": {
        "keywords": [
            "해줘", "만들어", "수정", "변경", "추가", "삭제", "구현",
            "implement", "create", "modify", "change", "add", "remove", "fix",
            "적용", "반영", "작성", "코드",
        ],
        "guidance": (
            "[GOLDE:EXECUTE] 현재 단계: 최소 변경 실행.\n"
            "→ Minimum Necessary Change: 요청된 것만 변경.\n"
            "→ Explicit Over Clever: 3줄 반복이 조기 추상화보다 낫다.\n"
            "→ 하나씩 변경하고 검증. 여러 변경 한꺼번에 적용 금지."
        ),
    },
    "verify": {
        "keywords": [
            "확인", "테스트", "검증", "맞는지", "동작", "통과",
            "verify", "test", "check", "validate", "correct", "pass",
            "리뷰", "검토",
        ],
        "guidance": (
            "[GOLDE:VERIFY] 현재 단계: 증거 기반 검증.\n"
            "→ Verify Before Claiming: 직관이 아닌 증거로 완료 증명.\n"
            "→ 독립 적대적 검증 권장. 자기 검증은 대체 불가."
        ),
    },
}


def detect_phase(text: str) -> tuple[str, str]:
    """Detect GOLDE phase from user input. Returns (phase, guidance)."""
    text_lower = text.lower()
    scores: dict[str, int] = {}

    for phase, config in PHASE_SIGNALS.items():
        score = sum(1 for kw in config["keywords"] if kw in text_lower)
        if score > 0:
            scores[phase] = score

    if not scores:
        return "", ""

    best = max(scores, key=scores.get)  # type: ignore[arg-type]
    return best, PHASE_SIGNALS[best]["guidance"]


# ─── Agent Quality Gate ──────────────────────────────────────────────

DELEGATION_ANTI_PATTERNS = [
    "based on your findings",
    "based on the research",
    "위에서 조사한 결과를",
    "조사 결과를 바탕으로",
    "찾은 것을 기반으로",
    "결과를 토대로",
    "알아낸 것을 바탕으로",
]

QUALITY_INDICATORS = [
    # file:line pattern
    ".ts:", ".tsx:", ".py:", ".js:", ".rs:", ".go:",
    "line ", "라인 ",
    # specific action
    "추가해", "수정해", "삭제해", "변경해",
    "add ", "modify ", "change ", "remove ", "fix ",
]


def check_agent_prompt_quality(prompt: str) -> tuple[bool, str]:
    """Check if agent prompt follows 'Never Delegate Understanding'.
    Returns (passed, message).
    """
    prompt_lower = prompt.lower()

    # Check anti-patterns
    for pattern in DELEGATION_ANTI_PATTERNS:
        if pattern in prompt_lower:
            return False, (
                f"[QUALITY GATE] 'Never Delegate Understanding' 위반 감지: '{pattern}'\n"
                "→ 이해를 직접 합성하고, 파일:라인 수준의 구체적 스펙으로 위임하세요.\n"
                "→ 나쁜 예: 'Based on your findings, fix the bug'\n"
                "→ 좋은 예: 'src/auth/middleware.ts:45에서 token.exp 체크 추가'"
            )

    # Check quality indicators (warn, don't block)
    has_specificity = any(ind in prompt_lower for ind in QUALITY_INDICATORS)
    if not has_specificity and len(prompt) > 100:
        return True, (
            "[QUALITY HINT] 에이전트 프롬프트에 파일 경로/라인 번호가 없습니다.\n"
            "→ 구체적 스펙(파일:라인, 정확한 변경 내용)을 포함하면 성공률이 높아집니다."
        )

    return True, ""


# ─── Verification Enforcer ───────────────────────────────────────────

def load_state() -> dict:
    """Load persistent runtime state."""
    try:
        if RUNTIME_STATE.exists():
            return json.loads(RUNTIME_STATE.read_text())
    except (json.JSONDecodeError, OSError):
        pass
    return {
        "tasks_without_verify": 0,
        "last_phase": "",
        "session_start": time.time(),
        "total_agent_calls": 0,
        "quality_gate_blocks": 0,
        "phases_visited": [],
    }


def save_state(state: dict) -> None:
    """Save persistent runtime state."""
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        RUNTIME_STATE.write_text(json.dumps(state, indent=2))
    except OSError:
        pass


# ─── Main Hook Handler ───────────────────────────────────────────────

def main() -> None:
    try:
        hook_input = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, EOFError):
        print(json.dumps({}))
        return

    hook_event = os.environ.get("CLAUDE_HOOK_EVENT", "")
    tool_name = hook_input.get("tool_name", "")
    state = load_state()

    # ── UserPromptSubmit: GOLDE Phase Detection ──
    if hook_event == "UserPromptSubmit":
        user_input = ""
        content = hook_input.get("content", "")
        if isinstance(content, str):
            user_input = content
        elif isinstance(content, list):
            user_input = " ".join(
                b.get("text", "") for b in content if isinstance(b, dict)
            )

        if not user_input:
            print(json.dumps({}))
            return

        phase, guidance = detect_phase(user_input)
        if phase:
            state["last_phase"] = phase
            if phase not in state.get("phases_visited", []):
                state.setdefault("phases_visited", []).append(phase)
            save_state(state)

            # Only inject on meaningful phase detection
            print(json.dumps({"additionalContext": guidance}))
        else:
            print(json.dumps({}))
        return

    # ── PreToolUse (Agent): Quality Gate ──
    if hook_event == "PreToolUse" and tool_name == "Agent":
        tool_input = hook_input.get("tool_input", {})
        prompt = tool_input.get("prompt", "")

        state["total_agent_calls"] = state.get("total_agent_calls", 0) + 1

        passed, message = check_agent_prompt_quality(prompt)
        save_state(state)

        if not passed:
            state["quality_gate_blocks"] = state.get("quality_gate_blocks", 0) + 1
            save_state(state)
            # Don't block, but inject strong warning
            print(json.dumps({"additionalContext": message}))
        elif message:
            print(json.dumps({"additionalContext": message}))
        else:
            print(json.dumps({}))
        return

    # ── PostToolUse: Verification Tracking ──
    if hook_event == "PostToolUse":
        # Track edits/writes as "unverified tasks"
        if tool_name in ("Edit", "Write", "NotebookEdit", "MultiEdit"):
            state["tasks_without_verify"] = state.get("tasks_without_verify", 0) + 1

        # Reset counter on verification-related tools
        if tool_name in ("Bash",):
            tool_input = hook_input.get("tool_input", {})
            command = tool_input.get("command", "")
            if any(kw in command for kw in ["test", "check", "verify", "lint", "type"]):
                state["tasks_without_verify"] = 0

        # Verification nudge at threshold
        nudge = ""
        count = state.get("tasks_without_verify", 0)
        if count >= 5:
            nudge = (
                f"[VERIFY NUDGE] {count}개 파일 수정이 검증 없이 진행됨.\n"
                "→ 테스트 실행, 타입 체크, 또는 독립 검증 에이전트를 권장합니다.\n"
                "→ Verify Before Claiming: 직관이 아닌 증거로 완료를 증명하세요."
            )
        elif count == 3:
            nudge = (
                f"[VERIFY HINT] {count}개 파일 수정 후 검증 미실행.\n"
                "→ 중간 검증을 고려해보세요."
            )

        save_state(state)
        if nudge:
            print(json.dumps({"additionalContext": nudge}))
        else:
            print(json.dumps({}))
        return

    # Default: pass through
    print(json.dumps({}))


if __name__ == "__main__":
    main()
