---
name: anthropic-strategic-plan
description: "Anthropic 수준의 전략적 플래닝 — 5단계 Plan Mode, 작업 분해, 의존성 관리, 병렬 에이전트 조율, 검증 게이트 포함 계획 수립"
whenToUse: "플랜, 계획, 기획, 전략, 로드맵, plan, planning, 설계 전 계획 수립"
model: opus
---

# Anthropic Strategic Plan

Claude Code의 Plan Mode(5단계), Task System(의존성 추적), Coordinator Mode(4단계 워크플로우)에서 추출한 전략적 플래닝 방법론.

## 적용 대상: $ARGUMENTS

---

## Phase 0: 계획이 필요한지 판단

| 복잡도 | 접근법 |
|--------|--------|
| 1-2단계, 명확한 작업 | 바로 실행 (계획 불필요) |
| 3+ 단계, 다중 파일 | 가벼운 태스크 리스트 |
| 아키텍처 변경, 모호한 요구사항 | Full Plan Mode 진입 |

**Anthropic 원칙**: "Plan mode gates implementation behind user approval for non-trivial work."

---

## Phase 1: 탐색 (Explore) — 병렬 정찰

**최대 3개 탐색 에이전트를 동시에 투입:**
- Agent A: 관련 코드/파일 검색 (Explore 타입, read-only)
- Agent B: 의존성 및 영향 범위 조사
- Agent C: 기존 패턴/컨벤션 파악

**핵심**: 탐색은 읽기 전용. 아직 아무것도 수정하지 않음.

```
"Launch up to 3 Explore subagents in parallel for codebase search"
— Claude Code Plan Mode Phase 1
```

---

## Phase 2: 설계 (Design) — 아키텍처 검토

**최대 3개 플랜 에이전트를 동시에 투입:**
- Agent A: 접근법 A 설계 (trade-off 분석 포함)
- Agent B: 접근법 B 설계 (대안)
- Agent C: 리스크/엣지케이스 분석

**산출물**: 각 접근법의 Pros/Cons/Trade-offs 비교 매트릭스

---

## Phase 3: 검토 (Review) — 정합성 확인

1. 핵심 파일을 직접 읽어 설계와 일치하는지 확인
2. 사용자에게 명확화 질문 (모호한 부분만)
3. 가정을 FACT / INTERPRETATION / ASSUMPTION으로 분류

**Anthropic 원칙**: "Read critical files, verify alignment, ask clarifying questions"

---

## Phase 4: 최종 계획 작성

### 4.1 작업 분해 (Task Decomposition)

```markdown
## Task 1: [제목] (우선순위: P0)
- 설명: [무엇을 왜]
- 파일: [정확한 경로:라인]
- 의존성: 없음
- 예상 변경: [구체적 변경 내용]

## Task 2: [제목] (우선순위: P0)  
- 설명: [무엇을 왜]
- blockedBy: [Task 1]
- 파일: [정확한 경로:라인]
```

### 4.2 의존성 그래프

```
Task 1 (독립) ──┐
Task 2 (독립) ──┤──▶ Task 4 (Task 1,2 완료 후)──▶ Task 5 (검증)
Task 3 (독립) ──┘
```

**병렬화 규칙**:
- 읽기 전용 작업: 자유롭게 병렬
- 같은 파일 쓰기: 반드시 직렬
- 독립 파일 쓰기: 병렬 가능

### 4.3 검증 전략

각 태스크에 검증 기준을 사전 정의:

```markdown
## Verification Criteria
- [ ] 기존 테스트 통과
- [ ] 새 기능 테스트 추가
- [ ] 타입 체크 통과
- [ ] 영향받는 파일 목록과 실제 변경 일치
```

---

## Phase 5: 승인 및 실행 전환

1. 계획을 사용자에게 제시
2. 승인/수정 피드백 수렴
3. 승인 시 Plan Mode 종료 → 실행 모드 전환
4. TaskCreate로 작업 목록 생성
5. 의존성 없는 작업부터 병렬 실행 시작

---

## 코디네이터 모드: 4단계 워크플로우

대규모 작업 시 순수 오케스트레이터로 전환:

### Stage 1: Research (병렬 워커 투입)
```
Worker A: "src/auth/ 디렉토리의 미들웨어 구조 조사"
Worker B: "관련 테스트 파일과 커버리지 조사"  
Worker C: "기존 에러 핸들링 패턴 조사"
```

### Stage 2: Synthesis (코디네이터가 직접 통합)
```
"Never Delegate Understanding"
— 워커 결과를 직접 읽고, 파일 경로와 라인 번호를 포함한 
  구체적 구현 스펙을 작성. 
  "based on your findings, fix it" 절대 금지.
```

### Stage 3: Implementation (워커에게 구체적 스펙 전달)
```
Worker A: "src/auth/middleware.ts:45-67에서 expiry 체크 추가.
          token.exp < Date.now() 일 때 401 반환."
Worker B: "tests/auth/middleware.test.ts에 3개 테스트 케이스 추가:
          1. 만료된 토큰 → 401
          2. 유효한 토큰 → 통과  
          3. refresh=true + 만료 → 401"
```

### Stage 4: Verification (독립 검증 에이전트)
```
Verifier: "변경사항이 스펙과 일치하는지 적대적으로 검증.
           자신의 검증은 대체 불가 — 독립 verifier만 판정."
```

---

## 플래닝 안티패턴

| 안티패턴 | 올바른 접근 |
|---------|-----------|
| 모든 것을 순차적으로 계획 | 독립 작업을 식별하고 병렬화 |
| "이것저것 해주세요" 모호한 작업 | 파일:라인 수준의 구체적 스펙 |
| 이해 없이 위임 | 먼저 이해하고, 구체적 스펙으로 위임 |
| 계획만 하고 검증 안 함 | 모든 태스크에 검증 기준 사전 정의 |
| 과도한 계획 (2단계 작업에 30분 계획) | 복잡도에 맞게 스케일링 |

---

## Dream: 세션 간 지식 통합

24시간+ 간격, 5+ 세션 후 자동 실행:
1. **Orient**: 메모리 디렉토리 스캔
2. **Gather**: 로그/트랜스크립트에서 신호 수집
3. **Consolidate**: 기존 토픽에 병합, 상대 날짜→절대 날짜 변환
4. **Prune**: 오래된 포인터 제거, 모순 해소

---

## 실행

`$ARGUMENTS`에 대해:
1. 복잡도 판단 (Phase 0)
2. 탐색 에이전트 투입 (Phase 1)
3. 설계 대안 비교 (Phase 2)
4. 정합성 검증 (Phase 3)
5. 구체적 태스크 리스트 + 의존성 그래프 작성 (Phase 4)
6. 사용자 승인 후 실행 전환 (Phase 5)
