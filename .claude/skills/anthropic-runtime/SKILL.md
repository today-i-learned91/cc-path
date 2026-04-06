---
name: anthropic-runtime
description: "CC-Path 런타임 커널 — GOLDE 단계 자동 추적, Agent 품질 게이트, 자동 검증 강제. 수동 지식을 능동 실행 엔진으로 전환."
whenToUse: "런타임, 커널, 능동, 자동 추적, 자동 검증, 품질 게이트, cc-path, runtime, kernel"
model: opus
---

# Anthropic Runtime Kernel

수동 스킬 지식을 **능동 실행 엔진**으로 전환하는 CC-Path 런타임 커널.

## 적용 대상: $ARGUMENTS

---

## 아키텍처: 3-Layer Active Enforcement

```
Layer 1: GOLDE Phase Tracker (UserPromptSubmit hook)
  → 사용자 입력에서 인지 단계 자동 감지
  → 단계별 가이드를 컨텍스트에 자동 주입
  → Orient→Analyze→Plan→Execute→Verify 추적

Layer 2: Agent Quality Gate (PreToolUse:Agent hook)
  → "Never Delegate Understanding" 위반 자동 감지
  → 모호한 위임 프롬프트에 경고 주입
  → 파일:라인 수준 구체성 부재 시 힌트 제공

Layer 3: Verification Enforcer (PostToolUse hook)
  → 파일 수정 횟수 자동 추적
  → 3회 수정 후 검증 힌트
  → 5회 수정 후 검증 강제 넛지
  → 테스트/린트/타입체크 실행 시 카운터 리셋
```

---

## Before vs After

### Before (수동 지식)
```
CLAUDE.md에 "Read Before Write" 원칙이 적혀 있음
→ 모델이 읽고 "노력"함
→ 바쁠 때 잊어버림
→ 검증 안 하고 "완료" 선언
→ 모호한 에이전트 프롬프트 작성
```

### After (능동 런타임)
```
UserPromptSubmit → 단계 자동 감지 → 단계별 가이드 강제 주입
PreToolUse:Agent → 프롬프트 품질 자동 체크 → 위반 시 경고
PostToolUse:Edit → 수정 횟수 추적 → 임계값 도달 시 검증 강제
→ 원칙이 "잊혀질 수 없음" — 시스템이 강제함
```

---

## 상태 파일

`.omc/state/anthropic_runtime.json`:
```json
{
  "tasks_without_verify": 3,
  "last_phase": "execute",
  "session_start": 1712444040,
  "total_agent_calls": 7,
  "quality_gate_blocks": 1,
  "phases_visited": ["orient", "analyze", "plan", "execute"]
}
```

---

## 훅 등록 (settings.json)

```json
{
  "UserPromptSubmit": [{
    "hooks": [{
      "type": "command",
      "command": "CLAUDE_HOOK_EVENT=UserPromptSubmit python3 tools/hooks/anthropic_runtime.py",
      "timeout": 3
    }]
  }],
  "PreToolUse": [{
    "matcher": "Agent",
    "hooks": [{
      "type": "command",
      "command": "CLAUDE_HOOK_EVENT=PreToolUse python3 tools/hooks/anthropic_runtime.py",
      "timeout": 5
    }]
  }],
  "PostToolUse": [{
    "matcher": "Write|Edit|MultiEdit|Bash",
    "hooks": [{
      "type": "command",
      "command": "CLAUDE_HOOK_EVENT=PostToolUse python3 tools/hooks/anthropic_runtime.py",
      "timeout": 3
    }]
  }]
}
```

---

## GOLDE 단계 감지 키워드

| 단계 | 감지 키워드 | 주입되는 가이드 |
|------|-----------|--------------|
| Orient | 뭐, 왜, 파악, 이해, 확인 | Read Before Write, FACT 분류 |
| Analyze | 분석, 원인, 비교, 에러, 버그 | Diagnose Before Switching, 경쟁 가설 |
| Plan | 계획, 설계, 전략, 어떻게 | 병렬/직렬 분리, Never Delegate |
| Execute | 해줘, 만들어, 수정, 구현 | Minimum Change, Explicit>Clever |
| Verify | 확인, 테스트, 검증, 동작 | 증거 기반 검증, 독립 적대적 |

---

## Agent 품질 게이트 규칙

### 차단 (경고 주입)
```
"based on your findings" → 이해 위임 감지
"조사 결과를 바탕으로"  → 이해 위임 감지
"결과를 토대로"         → 이해 위임 감지
```

### 힌트 (권장사항 주입)
```
100자+ 프롬프트에 파일 경로/라인 번호 없음
→ "구체적 스펙을 포함하면 성공률이 높아집니다"
```

---

## 검증 강제기 임계값

| 수정 횟수 | 동작 |
|----------|------|
| 1-2 | 추적만 (무개입) |
| 3 | `[VERIFY HINT]` 중간 검증 제안 |
| 5+ | `[VERIFY NUDGE]` 검증 강제 권장 |
| 테스트/린트 실행 | 카운터 리셋 |

---

## 확장 포인트

이 커널은 확장 가능:
- `detect_phase()`: 새 키워드 추가로 감지 정확도 향상
- `DELEGATION_ANTI_PATTERNS`: 새 안티패턴 추가
- `QUALITY_INDICATORS`: 새 구체성 지표 추가
- 새 PostToolUse 이벤트: 다른 도구 추적 추가
- classifier-weights.json 연동: 데이터 기반 단계 분류

---

## 17개 스킬과의 연계

```
런타임 커널이 단계를 감지하면:

Orient  → anthropic-research + anthropic-principles 원칙 적용
Analyze → anthropic-problem-solve 프레임워크 적용
Plan    → anthropic-strategic-plan + anthropic-multi-agent 적용
Execute → anthropic-architecture + anthropic-token-zero 적용
Verify  → anthropic-verify 프레임워크 적용

Agent 호출 시:
  → anthropic-agent-mastery 선택 기준 적용
  → anthropic-agent-interconnect 연쇄 패턴 적용
```

---

## 실행

`$ARGUMENTS`에 대해:
1. 현재 런타임 상태 확인 (`.omc/state/anthropic_runtime.json`)
2. 훅 등록 상태 확인 (`.claude/settings.json`)
3. 필요 시 커널 확장/수정
4. 검증 강제기 임계값 조정
