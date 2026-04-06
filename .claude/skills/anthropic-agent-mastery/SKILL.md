---
name: anthropic-agent-mastery
description: "AI Agent 활용 마스터리 — 빌트인 에이전트 6종, Fork 서브에이전트, 에이전트 메모리 3스코프, 커스텀 에이전트 정의, 모델 라우팅"
whenToUse: "에이전트, agent, 위임, delegate, 서브에이전트, subagent, fork, 탐색, explore, 병렬 작업"
model: opus
---

# Anthropic Agent Mastery

Claude Code의 AgentTool(234K), 빌트인 에이전트 6종, Fork 시스템, 에이전트 메모리에서 추출한 AI Agent 활용 완전 마스터리.

## 적용 대상: $ARGUMENTS

---

## I. 빌트인 에이전트 카탈로그

### 1. general-purpose (범용)
```
모델: inherit (부모와 동일)
도구: ['*'] (모든 도구)
용도: 복잡한 멀티스텝 작업, 리서치, 코드 변경
특성: 가장 유연. 모든 도구 접근 가능
```

### 2. Explore (탐색 전문가)
```
모델: haiku (외부), inherit (내부)
도구: Agent, ExitPlanMode, FileEdit, FileWrite, NotebookEdit 제외 (읽기 전용)
용도: 코드베이스 검색, 파일 탐색, 패턴 발견
특성: omitClaudeMd=true (CLAUDE.md 건너뜀 → 토큰 절약)
최적 사용: "src/ 디렉토리에서 인증 관련 파일을 모두 찾아줘"
```

### 3. Plan (설계 전문가)
```
모델: inherit
도구: 읽기 전용 + Plan 특화
용도: 아키텍처 설계, 접근법 비교, 트레이드오프 분석
특성: omitClaudeMd=true
최적 사용: "인증 시스템 리팩토링 접근법 A vs B 비교해줘"
```

### 4. claude-code-guide (가이드)
```
모델: inherit
용도: Claude Code 사용법, 기능 안내
특성: 비SDK 엔트리포인트에서만 사용 가능
```

### 5. verification (검증 전문가)
```
모델: inherit
용도: 독립 적대적 검증
특성: feature-gated (tengu_hive_evidence)
시스템 프롬프트: "adversarial verification — 
  자신의 검증은 대체 불가, 독립 verifier만 판정"
```

### 6. fork (컨텍스트 포크 — 합성 에이전트)
```
모델: inherit
도구: ['*']
maxTurns: 200
permissionMode: 'bubble'
특성: 부모의 전체 대화 컨텍스트를 상속
시스템 프롬프트: 없음 (부모의 렌더링된 시스템 프롬프트를 직접 전달)
```

---

## II. 에이전트 선택 의사결정 트리

```
요청이 들어왔을 때:

1. 읽기 전용인가?
   ├─ 파일/코드 검색 → Explore (haiku, 저렴)
   ├─ 설계/비교 분석 → Plan (읽기전용 + 분석)
   └─ 아님 → 다음

2. 구현이 필요한가?
   ├─ 단순 (1-2파일) → 직접 실행 (에이전트 불필요)
   ├─ 중간 (3+ 파일) → general-purpose
   ├─ 복잡 (아키텍처 변경) → Plan 먼저 → general-purpose
   └─ 대규모 → Team 모드 (멀티에이전트)

3. 검증이 필요한가?
   └─ verification 에이전트 (작성자 ≠ 검증자)

4. 컨텍스트 공유가 필요한가?
   ├─ 부모 대화 맥락 필요 → fork
   └─ 독립 작업 → fresh agent
```

---

## III. Fresh Agent vs Fork Agent

### Fresh Agent (기본)
```
컨텍스트: 0에서 시작
프롬프트: 완전한 브리핑 필요
  1. 무엇을 달성하려는지
  2. 왜 중요한지
  3. 이미 알아낸 것 / 배제한 것
  4. 주변 문제의 맥락
  5. 기대하는 산출물 형태

안티패턴: "Terse command-style prompts produce shallow, generic work."
```

### Fork Agent (컨텍스트 상속)
```
컨텍스트: 부모의 전체 대화를 상속
프롬프트: 지시만 간결하게
  - "무엇을 할지"만 명시 (배경 반복 금지)
  - 범위 명확히: "what's in, what's out"

규칙:
  - "Don't peek" — 다른 fork의 출력 파일을 읽지 말 것
  - "Don't race" — fork 결과를 예측/가공하지 말 것
  - 재귀 방지: FORK_BOILERPLATE_TAG로 fork-in-fork 감지

캐시 최적화:
  모든 fork 자식이 바이트 동일한 API 프리픽스 생성
  → 프롬프트 캐시 공유 (비용 절약)
```

### 선택 기준

| 기준 | Fresh | Fork |
|------|-------|------|
| 부모 대화 필요 | X | O |
| 캐시 공유 | X | O (바이트 동일 프리픽스) |
| 브리핑 비용 | 높음 (전체 맥락) | 낮음 (지시만) |
| 격리 | 완전 | 부분 (컨텍스트 공유) |
| 병렬 효율 | 낮음 | 높음 (캐시 공유) |

---

## IV. 에이전트 프롬프트 작성법: "Never Delegate Understanding"

```
절대 금지:
  "Based on your findings, fix the bug."
  "Research this and implement a solution."
  → 이해를 에이전트에게 위임하는 것

반드시:
  "In src/auth/middleware.ts:45-67, the session token validation 
   skips the expiry check when refresh=true. 
   Add: if (token.exp < Date.now()) return res.status(401)."
  → 직접 이해를 합성하고 구체적 스펙을 전달
```

### 좋은 에이전트 프롬프트 체크리스트
- [ ] 파일 경로와 라인 번호가 포함되어 있는가
- [ ] "왜" 이 변경이 필요한지 설명했는가
- [ ] 기대하는 행동이 구체적인가 (함수 시그니처, 반환값 등)
- [ ] 범위가 명확한가 (무엇을 변경하고 무엇을 변경하지 않는가)
- [ ] 검증 기준이 있는가

---

## V. 에이전트 메모리 시스템

### 3가지 스코프

| 스코프 | 경로 | 공유 범위 | VCS |
|--------|------|----------|-----|
| `user` | `~/.claude/agent-memory/{type}/` | 모든 프로젝트 | X |
| `project` | `.claude/agent-memory/{type}/` | 팀 전체 | O |
| `local` | `.claude/agent-memory-local/{type}/` | 로컬만 | X |

### 메모리 스냅샷
```
프로젝트 레벨: .claude/agent-memory-snapshots/{type}/snapshot.json
상태: 'none' → 'initialize' (첫 번째) → 'prompt-update' (업데이트 존재)
동기화: .snapshot-synced.json으로 재적용 방지
```

---

## VI. 커스텀 에이전트 정의

`.claude/agents/{name}.json`:
```json
{
  "description": "에이전트 설명",
  "whenToUse": "자동 트리거 조건",
  "tools": ["Read", "Grep", "Glob"],
  "disallowedTools": ["Bash"],
  "prompt": "시스템 프롬프트 텍스트",
  "model": "opus",
  "effort": "high",
  "permissionMode": "plan",
  "maxTurns": 50,
  "skills": ["my-skill"],
  "memory": "project",
  "background": false,
  "isolation": "worktree",
  "initialPrompt": "첫 턴에 주입할 프롬프트",
  "omitClaudeMd": true,
  "hooks": { "PreToolUse": [...] },
  "mcpServers": [{ "name": "my-server", "command": "..." }]
}
```

---

## VII. 에이전트 실행 모드

| 모드 | 트리거 | 특성 |
|------|--------|------|
| 동기 | 기본 | 결과를 기다림 |
| 비동기 (`run_in_background`) | 명시 | agentId + outputFile 반환 |
| 코디네이터 강제 비동기 | coordinator mode | 항상 비동기 |
| 에이전트 정의 비동기 | `background: true` | 항상 비동기 |
| Worktree 격리 | `isolation: 'worktree'` | .claude/worktrees/에 임시 브랜치 |
| Remote 격리 | `isolation: 'remote'` | CCR 클라우드 실행 |

---

## VIII. 모델 라우팅

```
에이전트 모델 해석 순서:
1. 에이전트 정의의 model 필드
2. Agent tool 호출 시 model 파라미터
3. 'inherit' → 부모 모델 상속
4. 'opusplan' → Plan모드에서 Opus, 나머지 Sonnet
5. 'haiku' → Plan모드에서 Sonnet으로 업그레이드
```

---

## 실행

`$ARGUMENTS`에 대해:
1. 에이전트 필요성 판단 (직접 실행 vs 위임)
2. 의사결정 트리로 에이전트 타입 선택
3. Fresh vs Fork 결정
4. "Never Delegate Understanding" 원칙으로 프롬프트 작성
5. 동기/비동기/격리 모드 선택
6. 결과 수신 후 검증
