---
name: anthropic-agent-interconnect
description: "에이전트-스킬-훅-문서 상호연결 — 전체 시스템의 유기적 연계, 자동 라우팅, 상황 감지, 크로스 컴포넌트 오케스트레이션"
whenToUse: "연계, 연결, 통합, integration, interconnect, 자동 라우팅, 오케스트레이션, 시스템 설계, 전체 아키텍처"
model: opus
---

# Anthropic Agent Interconnect

Claude Code의 전체 시스템에서 추출한 에이전트-스킬-훅-문서 간 유기적 상호연결 방법론.

## 적용 대상: $ARGUMENTS

---

## I. 4-Layer 연결 아키텍처

```
Layer A: 문서 (정적 지식)
  CLAUDE.md → guides/ → modules/*/prompts/
  Hot(항상) → Warm(키워드 감지) → Cold(수동)

Layer B: 스킬 (실행 가능 지식)
  anthropic-* 스킬 13종 + 에이전트 4종
  whenToUse 키워드로 자동 트리거

Layer C: 에이전트 (실행 단위)
  빌트인 6종 + 커스텀 + OMC 에이전트
  상황에 따라 자동 선택

Layer D: 훅 (자동화 접점)
  16+ 이벤트에 4가지 타입의 훅
  도구 실행 전후로 자동 개입
```

---

## II. 상황 감지 → 자동 라우팅 매트릭스

### 코드 작성 감지 시
```
문서: CLAUDE.md (principles 섹션)
스킬: anthropic-principles + anthropic-architecture
에이전트: 직접 실행 (단순) 또는 general-purpose (복잡)
훅: PreToolUse(FileEdit) → 린트/포맷 자동 적용
```

### 디버깅 감지 시
```
문서: guides/protocols.md (Phase 0 구조화)
스킬: anthropic-problem-solve + anthropic-verify
에이전트: Explore(정찰) → general-purpose(수정) → verification(검증)
훅: PostToolUse(Bash) → 에러 감지 시 컨텍스트 주입
```

### 플래닝 감지 시
```
문서: CLAUDE.md (Anthropic Methods 섹션)
스킬: anthropic-strategic-plan + anthropic-research
에이전트: Plan(설계) × 3 병렬 → Explore(정찰) × 3 병렬
훅: UserPromptSubmit → 복잡도 감지 → Plan Mode 제안
```

### 멀티에이전트 감지 시
```
문서: guides/anthropic-methods.md (자동 주입)
스킬: anthropic-multi-agent + anthropic-agent-mastery
에이전트: Coordinator → Worker × N → Verifier
훅: TaskCompleted → 검증 넛지, TeammateIdle → 재배정
```

### 문서/프롬프트 작성 감지 시
```
문서: CLAUDE.md (CoD 원칙)
스킬: anthropic-document-craft + anthropic-prompt-craft
에이전트: 직접 실행 (대부분)
훅: PostToolUse(FileWrite) → 포맷 검증
```

### 자동화 설정 감지 시
```
문서: guides/operations.md
스킬: anthropic-agent-automation + anthropic-harness-craft
에이전트: 직접 실행
훅: ConfigChange → 설정 검증
```

---

## III. 스킬 연쇄 패턴 (Skill Chaining)

### Sequential Chain (순차 연쇄)
```
요청: "인증 시스템 리팩토링해줘"

1. anthropic-strategic-plan → 5단계 Plan Mode
2. anthropic-research → 병렬 탐색 (Explore × 3)
3. anthropic-architecture → 설계 패턴 선택
4. anthropic-multi-agent → 구현 팀 조율
5. anthropic-verify → 독립 검증
6. anthropic-document-craft → 변경 문서화
```

### Parallel Chain (병렬 연쇄)
```
요청: "코드 리뷰하고 문서도 업데이트해줘"

병렬 A: anthropic-verify (코드 리뷰)
병렬 B: anthropic-document-craft (문서 업데이트)
합류: 두 결과를 통합 리포트로
```

### Conditional Chain (조건 연쇄)
```
요청: "이거 고쳐줘" (모호)

IF 단순 → 직접 실행 (스킬 불필요)
IF 중간 → anthropic-problem-solve만
IF 복잡 → problem-solve → strategic-plan → multi-agent
IF 모호 → anthropic-research 먼저 → 판단 후 분기
```

---

## IV. 자동 감지 키워드 매핑

| 키워드 | 1차 스킬 | 2차 스킬 | 에이전트 |
|--------|---------|---------|---------|
| "설계/아키텍처/구조" | architecture | strategic-plan | Plan |
| "디버그/버그/에러" | problem-solve | verify | Explore→general |
| "플랜/계획/기획" | strategic-plan | research | Plan × 3 |
| "문서/README/ADR" | document-craft | prompt-craft | 직접 |
| "프롬프트/지시/instruction" | prompt-craft | principles | 직접 |
| "에이전트/위임/병렬" | agent-mastery | multi-agent | Coordinator |
| "자동화/스케줄/cron" | agent-automation | harness-craft | 직접 |
| "토큰/효율/비용" | token-zero | context-engine | 직접 |
| "테스트/검증/QA" | verify | problem-solve | verification |
| "폴더/구조/정리" | folder-mastery | architecture | 직접 |
| "스킬/만들기/workflow" | skill-forge | harness-craft | 직접 |
| "원칙/방법론/가이드" | principles | - | 직접 |
| "리서치/조사/탐색" | research | context-engine | Explore × 3 |

---

## V. 크로스 컴포넌트 데이터 흐름

```
사용자 입력
  │
  ├─ UserPromptSubmit Hook → 키워드 감지 → Guide 주입
  │
  ├─ CLAUDE.md → 10대 원칙 암묵적 적용
  │
  ├─ 모델 판단 → 스킬 자동 선택 (whenToUse 매칭)
  │     ├─ 스킬 내부에서 에이전트 타입 추천
  │     └─ 스킬 내부에서 다른 스킬 참조 (2차 스킬)
  │
  ├─ 에이전트 실행
  │     ├─ PreToolUse Hook → 권한/안전 체크
  │     ├─ 에이전트 메모리 → 이전 경험 활용
  │     └─ PostToolUse Hook → 결과 후처리
  │
  ├─ 태스크 시스템 → 의존성 추적
  │     └─ TaskCompleted Hook → 검증 넛지
  │
  └─ Session Memory → 컴팩션 시 보존
        └─ Dream → 세션 간 통합
```

---

## VI. OMC + Anthropic 스킬 통합

### OMC 에이전트와의 연계

| OMC 에이전트 | Anthropic 스킬 보강 |
|-------------|-------------------|
| `executor` | principles + architecture |
| `architect` | architecture + strategic-plan |
| `code-reviewer` | verify + problem-solve |
| `planner` | strategic-plan + research |
| `debugger` | problem-solve + verify |
| `test-engineer` | verify + harness-craft |
| `writer` | document-craft + prompt-craft |
| `security-reviewer` | verify (Defense-in-Depth) |
| `analyst` | research + principles |

### OMC 워크플로우와의 연계

| OMC 워크플로우 | Anthropic 원칙 자동 적용 |
|--------------|----------------------|
| `/ralph` | principles (전 원칙) + verify (매 루프) |
| `/ultrawork` | multi-agent + token-zero (병렬 효율) |
| `/autopilot` | strategic-plan + agent-mastery |
| `/team` | multi-agent + agent-automation |
| `/ccg` | principles + research (다중 관점) |

---

## VII. 피드백 루프 (자기 개선)

```
1. 세션 중 피드백 감지
   → 사용자가 수정/거부 → feedback 메모리 저장
   
2. Dream 통합
   → 24시간 후 feedback 메모리 리뷰
   → 패턴 식별 → 기존 메모리 업데이트

3. 스킬 진화
   → 반복되는 워크플로우 감지
   → /skillify로 새 스킬 추출
   → anthropic-skill-forge 원칙으로 정제

4. 훅 최적화
   → 불필요한 훅 실행 감지
   → if 필터 추가/수정
   → classifier-weights.json 업데이트
```

---

## 실행

`$ARGUMENTS`에 대해:
1. 요청의 키워드/맥락에서 상황 자동 감지
2. 4-Layer 연결 아키텍처에서 관련 컴포넌트 식별
3. 스킬 연쇄 패턴 (순차/병렬/조건) 결정
4. 적합한 에이전트 + 훅 조합 선택
5. 크로스 컴포넌트 데이터 흐름에 따라 실행
6. 피드백 루프로 지속 개선
