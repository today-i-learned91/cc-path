---
name: anthropic-multi-agent
description: "멀티에이전트 오케스트레이션 — Team/Coordinator 모드, 3백엔드(tmux/in-process/remote), Mailbox 통신, 병렬 전략, 4단계 코디네이터 워크플로우"
whenToUse: "멀티에이전트, multi-agent, 팀, team, 병렬 작업, 코디네이터, coordinator, 분산, swarm, 오케스트레이션"
model: opus
---

# Anthropic Multi-Agent Orchestration

Claude Code의 Team System, Coordinator Mode, Swarm Backend에서 추출한 멀티에이전트 오케스트레이션 방법론.

## 적용 대상: $ARGUMENTS

---

## I. 멀티에이전트가 필요한 시점

| 상황 | 접근법 |
|------|--------|
| 단일 파일 수정 | 직접 실행 |
| 3+ 독립 파일 수정 | 병렬 에이전트 (Agent 도구) |
| 5+ 파일, 의존성 있음 | Team 모드 |
| 대규모 리팩토링 | Coordinator 모드 |
| 멀티 리포/환경 | Worktree 격리 + Team |

---

## II. 3가지 백엔드

### Backend 1: tmux (프로세스 격리)
```
- 각 워커가 독립 Claude Code 프로세스
- tmux split pane으로 시각화
- 완전한 프로세스 격리 (메모리 안전)
- CLI 플래그 상속 (buildInheritedCliFlags)
- 환경변수로 정체성 전달:
  CLAUDE_CODE_AGENT_ID, CLAUDE_CODE_AGENT_NAME, CLAUDE_CODE_TEAM_NAME
```

### Backend 2: in-process (저지연)
```
- 같은 Node.js 프로세스 내 AsyncLocalStorage 격리
- API 클라이언트/MCP 연결 공유 (리소스 절약)
- 50메시지 상한 (메모리 폭주 방지 — 36.8GB 세션 교훈)
- 가장 빠른 스폰/통신
```

### Backend 3: remote (클라우드)
```
- Anthropic CCR 인프라에서 클라우드 실행
- WebSocket으로 이벤트 수신
- HTTP POST로 메시지 전송
- ultraplan, ultrareview, autofix-pr, background-pr 지원
```

---

## III. Team 생명주기

```
1. TeamCreate
   → ~/.claude/teams/{name}/config.json 생성
   → 태스크 리스트 디렉토리 설정
   → 리더 지정

2. Agent 도구로 워커 스폰
   → 팀 파일의 members 배열에 추가
   → 환경변수로 정체성 주입

3. 자율 작업
   → 워커가 태스크 리스트에서 작업 선택
   → 가장 낮은 ID부터 (선행 작업이 맥락 제공)
   → blockedBy 확인 후 작업 시작
   → idle은 정상 (대기 상태)

4. 통신 (Mailbox)
   → SendMessage로 직접/브로드캐스트
   → 파일 기반 메일박스 (프로세스 경계 초월)

5. 종료
   → SendMessage({ type: 'shutdown_request' })
   → 워커가 { type: 'shutdown_response' }로 응답
   → TeamDelete로 정리
```

---

## IV. 코디네이터 4단계 워크플로우

`CLAUDE_CODE_COORDINATOR_MODE=1`에서 활성화. 코디네이터는 **순수 오케스트레이터**.

### Stage 1: Research (병렬 워커 정찰)
```
코디네이터: "3명의 워커를 병렬 투입하세요"
  Worker A: "src/auth/ 미들웨어 구조 조사"
  Worker B: "관련 테스트 파일과 커버리지 조사"
  Worker C: "기존 에러 핸들링 패턴 조사"

규칙: 읽기 전용 → 자유롭게 병렬
```

### Stage 2: Synthesis (코디네이터가 직접 통합)
```
"Never Delegate Understanding"

코디네이터가 워커 결과를 직접 읽고 합성:
  - 파일 경로와 라인 번호 포함한 구체적 구현 스펙 작성
  - "based on your findings, fix it" 절대 금지
  - 각 워커에게 정확히 무엇을 변경할지 명세
```

### Stage 3: Implementation (구체적 스펙으로 워커 배정)
```
Worker A: "src/auth/middleware.ts:45-67에서 
          expiry 체크 추가. 조건: token.exp < Date.now()"
Worker B: "tests/auth/middleware.test.ts에 
          3개 테스트 추가: 만료→401, 유효→통과, refresh+만료→401"

규칙: 같은 파일 쓰기 → 반드시 직렬
      다른 파일 쓰기 → 병렬 가능
```

### Stage 4: Verification (독립 검증)
```
Verifier: "변경사항이 스펙과 일치하는지 적대적 검증"
  - 작성자 ≠ 검증자
  - 자기 검증은 대체 불가
```

---

## V. Mailbox 통신 프로토콜

### 직접 메시지
```
SendMessage({ to: "worker-a", content: "..." })
→ writeToMailbox(recipientName, message, teamName)
```

### 브로드캐스트
```
SendMessage({ to: "*", content: "..." })
→ 발신자 제외 모든 팀원에게 전송
```

### 구조화 프로토콜
```json
{ "type": "shutdown_request" }
{ "type": "shutdown_response" }
{ "type": "plan_approval_response", "approved": true }
```

### 태스크 알림 (워커 → 코디네이터)
```xml
<task-notification>
  <task-id>agent-id</task-id>
  <status>completed</status>
  <result>작업 결과</result>
</task-notification>
```

---

## VI. 병렬화 전략

### Continue vs Spawn 의사결정

| 조건 | 결정 | 이유 |
|------|------|------|
| 높은 컨텍스트 중첩 | `SendMessage`로 계속 | 기존 맥락 활용 |
| 낮은 컨텍스트 중첩 | `Agent`로 새로 스폰 | 깨끗한 시작 |
| 이전 워커 idle | 재활용 (`SendMessage`가 자동 재시작) | 스폰 비용 절약 |
| 새로운 독립 작업 | 새로 스폰 | 병렬 최대화 |

### 동시성 규칙

```
읽기 전용 작업: 자유롭게 병렬 (무제한)
같은 파일 쓰기: 반드시 1명씩 직렬
다른 파일 쓰기: 병렬 가능
파일 집합이 겹치면: 직렬화 필요
```

---

## VII. 태스크 분해 + 의존성

```markdown
Task 1: [독립] 인증 모듈 조사 → owner: worker-a
Task 2: [독립] 테스트 구조 조사 → owner: worker-b
Task 3: [blocked by 1,2] 구현 스펙 작성 → owner: coordinator
Task 4: [blocked by 3] 미들웨어 수정 → owner: worker-a
Task 5: [blocked by 3] 테스트 작성 → owner: worker-b
Task 6: [blocked by 4,5] 통합 검증 → owner: verifier
```

### 검증 넛지
```
3개 이상 태스크가 검증 없이 완료되면:
→ "독립 검증 에이전트 실행을 권장" 자동 알림
```

---

## VIII. 권한 동기화

```
리더 ↔ 워커 권한 브릿지:
  leaderPermissionBridge.ts → permissionSync.ts
  
리더가 승인한 권한을 모든 워커에게 전파
워커의 권한 요청을 리더에게 프록시
in-process 워커: API 클라이언트 공유로 자동 동기
```

---

## IX. Plan 승인 프로토콜

```
워커가 planModeRequired=true일 때:
  ExitPlanMode → 리더의 메일박스에 plan_approval_request 전송
  리더가 SendMessage({ type: 'plan_approval_response', approved: true })
  → 워커가 실행 모드로 전환
```

---

## 실행

`$ARGUMENTS`에 대해:
1. 멀티에이전트 필요성 판단
2. 백엔드 선택 (tmux/in-process/remote)
3. 태스크 분해 + 의존성 그래프 작성
4. 코디네이터 4단계 워크플로우 실행
5. 병렬화 전략 적용
6. 독립 검증 에이전트로 완료 확인
