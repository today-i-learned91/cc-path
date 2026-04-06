---
name: anthropic-agent-automation
description: "에이전트 자동화/스케줄링 — Cron 트리거, Remote Agent, Dream 메모리 통합, Hook 자동화, Proactive 모드, Session Memory"
whenToUse: "자동화, 스케줄링, cron, trigger, 예약, 반복, 자동 실행, dream, 메모리 통합, background, 데몬"
model: opus
---

# Anthropic Agent Automation

Claude Code의 Cron System, Remote Trigger, Dream Task, Hook 자동화, Proactive Mode에서 추출한 에이전트 자동화 방법론.

## 적용 대상: $ARGUMENTS

---

## I. 자동화 계층 구조

```
Layer 1: Hook 자동화 (매 도구 호출마다)
  → PreToolUse, PostToolUse, UserPromptSubmit...
  
Layer 2: Session 자동화 (세션 중)
  → Memory extraction, Prompt suggestion, Auto-compact
  
Layer 3: Inter-session 자동화 (세션 사이)
  → Dream (메모리 통합), Auto-dream (24시간 주기)
  
Layer 4: Scheduled 자동화 (시간 기반)
  → Cron triggers, Remote agents, launchd
```

---

## II. Hook 자동화 (Layer 1)

### 4가지 Hook 타입

| 타입 | 실행 방식 | 최적 사용처 |
|------|----------|-----------|
| `command` | 셸 명령 | 린트, 포맷, 알림 |
| `prompt` | LLM 평가 | 자연어 규칙 적용 |
| `agent` | 서브에이전트 | 복잡한 검증 |
| `http` | HTTP POST | 외부 서비스 연동 |

### 핵심 Hook 이벤트와 자동화 패턴

```json
{
  "hooks": {
    "PreToolUse": [{
      "type": "command",
      "command": "python3 tools/hooks/auto_guide_loader.py",
      "if": "Bash(*)",
      "timeout": 5000
    }],
    "PostToolUse": [{
      "type": "command",
      "command": "python3 tools/hooks/post_tool_notify.py",
      "async": true
    }],
    "UserPromptSubmit": [{
      "type": "command",
      "command": "python3 tools/hooks/context_injector.py"
    }],
    "TaskCompleted": [{
      "type": "command",
      "command": "python3 tools/hooks/verification_nudge.py"
    }],
    "SessionStart": [{
      "type": "command",
      "command": "python3 tools/hooks/session_init.py"
    }],
    "PreCompact": [{
      "type": "command",
      "command": "python3 tools/hooks/save_critical_context.py"
    }]
  }
}
```

### Hook 보안 규칙
- 워크스페이스 신뢰 필수
- 도구 훅 타임아웃: 10분
- SessionEnd 타임아웃: 1.5초 (행잉 방지)
- `if` 필터로 불필요한 실행 방지
- `async: true`로 비차단 실행

### PreToolUse 결정 패턴
```json
{
  "permissionDecision": "allow",
  "updatedInput": { "command": "modified command" },
  "additionalContext": "대화에 주입할 컨텍스트"
}
```

---

## III. Session 자동화 (Layer 2)

### Memory Extraction (자동 메모리 추출)
```
대화 중 자동으로:
  - 사용자 정보 감지 → user 메모리 저장
  - 피드백 감지 → feedback 메모리 저장
  - 프로젝트 정보 → project 메모리 저장
  - 외부 참조 → reference 메모리 저장
```

### Session Memory (세션 메모리)
```
컴팩션 시 보존할 핵심 정보를 자동 추출:
  - 최근 10K-40K 토큰 보존 (최소 5개 텍스트 블록)
  - 오래된 메시지 → 세션 메모리로 대체
  - 세션 메모리는 Full Compact보다 가볍고 빠름
```

### Prompt Suggestion (다음 행동 제안)
```
각 턴 후 자동으로:
  - 다음에 할 수 있는 행동 제안 생성
  - 사용자가 탭으로 선택 가능
  - 백그라운드에서 비동기 생성 (차단 없음)
```

### Auto-Compact (자동 압축)
```
토큰 초과 시 자동 실행:
  임계값: contextWindow - 13,000 버퍼
  회로 차단기: 3회 연속 실패 시 중단
  캐스케이드: micro → session-memory → full
```

---

## IV. Inter-session 자동화 (Layer 3)

### Dream System (세션 간 메모리 통합)

```
게이트 순서 (비용 최소):
  1. 시간 게이트: 마지막 통합 후 24시간+ 경과
  2. 세션 게이트: 5+ 세션의 트랜스크립트 존재
  3. 잠금 게이트: 다른 프로세스가 통합 중이 아님
```

### Dream 4단계 프롬프트

```markdown
Phase 1: Orient
  → ls 메모리 디렉토리, 인덱스 읽기, 기존 토픽 스캔

Phase 2: Gather
  → 일일 로그 검색, 드리프트된 메모리 발견
  → 트랜스크립트 좁은 범위 grep

Phase 3: Consolidate
  → 메모리 파일 작성/업데이트
  → 기존 토픽에 신호 병합
  → 상대 날짜 → 절대 날짜 변환
  → 모순된 사실 삭제

Phase 4: Prune and Index
  → 엔트리포인트 최대 줄 수 이내 유지
  → 오래된 포인터 제거
  → 모순 해소
```

### Dream UI
```
- 풋터 필에서 진행 상태 표시
- Shift+Down으로 상세 다이얼로그
- DreamPhase: 'starting' → 'updating'
- filesTouched 경로 추적
```

---

## V. Scheduled 자동화 (Layer 4)

### Cron Trigger System
```
CronCreateTool:
  - 원격 에이전트를 cron 스케줄로 생성
  - 클라우드에서 실행 (로컬 머신 불필요)
  - 프롬프트, 모델, 스킬 지정 가능

CronListTool:
  - 활성 트리거 목록 조회

CronDeleteTool:
  - 트리거 삭제
```

### Remote Trigger
```
RemoteTriggerTool:
  - 즉시 원격 에이전트 실행
  - CCR 인프라에서 클라우드 실행
  - 폴링으로 이벤트 수신
```

### launchd 스케줄링 (기존 설정)
```
morning-brief:    08:00 매일
market-close:     15:30 매일
research-digest:  21:00 매일
competitor-weekly: 월 09:00

주말 guard: quick-scan, morning-brief 자동 스킵
```

---

## VI. Stop Hooks (작업 완료 감지)

```
Stop hook 시스템:
  - 모든 태스크/팀메이트 완료 감지
  - TeammateIdle 이벤트 처리
  - TaskCompleted 이벤트 처리
  - 코디네이터에게 알림

검증 넛지:
  3+ 태스크 완료 시 검증 없으면
  → "독립 검증 에이전트 실행 권장" 자동 알림
```

---

## VII. Proactive Mode (KAIROS)

```
feature('PROACTIVE') || feature('KAIROS'):
  - SleepTool 활성화 (대기 + 모니터링)
  - BriefTool 활성화 (사전 통신)
  - 에이전트가 능동적으로 행동 시작
  - 사용자 입력 없이 다음 행동 결정
```

### Brief Tool
```
사전 통신 채널:
  - 에이전트가 진행 상황을 능동적으로 보고
  - 사용자 개입 없이 다음 단계 제안
  - 알림 채널(iTerm2/Telegram)과 연동
```

---

## VIII. 자동화 설계 패턴

### 1. Cheapest-First Gate
```
게이트 1 (0 비용) → 게이트 2 (저 비용) → 게이트 3 (고 비용)
비싼 게이트를 통과하기 전에 저렴한 게이트로 필터링
```

### 2. Circuit Breaker
```
3회 연속 실패 → 전략 중단
무한 재시도 방지, 비용 폭주 방지
```

### 3. Async by Default
```
자동화 훅은 기본적으로 비동기 실행
차단하지 않으면 사용자 경험 보존
asyncRewake: exit code 2 → 모델 깨우기
```

### 4. Fail-Closed Automation
```
훅 실패 → 로깅만, 시스템 크래시 방지
분류기 불가용 → 사용자에게 질문 (자동 허용 아님)
```

---

## 실행

`$ARGUMENTS`에 대해:
1. 자동화 계층 식별 (Hook/Session/Inter-session/Scheduled)
2. 적합한 자동화 메커니즘 선택
3. 보안 규칙 적용 (타임아웃, 신뢰, 필터)
4. Cheapest-First + Circuit Breaker 패턴 적용
5. 구현 및 검증
