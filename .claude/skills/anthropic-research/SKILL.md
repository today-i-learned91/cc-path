---
name: anthropic-research
description: "Anthropic 수준의 조사/리서치 방법론 — 병렬 탐색, 비용 최소 게이트 순서, Explore→Design→Review 3단계, 증거 기반 합성"
whenToUse: "조사, 리서치, 연구, 탐색, investigation, research, exploration, 코드베이스 분석"
model: opus
---

# Anthropic Research

Claude Code의 Plan Mode 탐색, Dream 게이트 순서, 코디네이터 리서치 패턴에서 추출한 조사/리서치 방법론.

## 적용 대상: $ARGUMENTS

---

## 원칙 1: 비용 최소 게이트 순서 (Cheapest-First)

Claude Code Dream 시스템의 게이트 순서:
```
1. 시간 게이트 (연산 0) → 2. 세션 게이트 (파일 스캔) → 3. 잠금 (프로세스 간 조율)
```

리서치에 적용:
```
1. 이미 알고 있는 것 정리 (0 비용)
2. 메모리/문서 확인 (저 비용)
3. 코드/파일 검색 (중 비용)
4. 웹 검색/외부 소스 (고 비용)
5. 실험/프로토타입 (최고 비용)
```

**원칙**: 비싼 조사를 시작하기 전에 저렴한 소스를 먼저 소진.

---

## 원칙 2: 병렬 탐색 (최대 3 에이전트)

```
Agent A: 소스 코드/내부 문서 탐색
Agent B: 외부 문서/API 참조 조사
Agent C: 유사 사례/선행 연구 검색
```

**독립적인 탐색 방향은 반드시 병렬로.** 순차 탐색은 비효율.

---

## 원칙 3: Explore → Design → Review 3단계

### Stage 1: Explore (발산)
- 넓게 탐색, 관련 정보 수집
- 키워드 검색, 파일 패턴 매칭, 의존성 추적
- 이 단계에서는 판단하지 않음 — 수집만

### Stage 2: Design (수렴)
- 수집한 정보를 구조화
- 패턴 식별, 분류, 인사이트 도출
- 경쟁 가설 수립

### Stage 3: Review (검증)
- 핵심 파일을 직접 읽어 확인
- 가정을 FACT/INTERPRETATION/ASSUMPTION으로 분류
- 모호한 부분에 대해 명확화 질문

---

## 원칙 4: "Never Delegate Understanding"

```
나쁜 예: "조사 결과를 바탕으로 해결해주세요"
좋은 예: "조사 결과, src/auth/middleware.ts:45에서 
         토큰 만료 검증이 누락됨. token.exp < Date.now() 
         조건을 추가해야 함."
```

리서치 결과를 직접 합성하고, 구체적 파일:라인 수준의 결론을 도출.

---

## 원칙 5: 증거 분류 체계

### FACT / INTERPRETATION / ASSUMPTION

| 분류 | 기준 | 예시 |
|------|------|------|
| FACT | 직접 관찰 가능 | "README.md에 'MIT License'로 명시됨" |
| INTERPRETATION | 증거 기반 추론 | "커밋 빈도로 볼 때 활발히 유지보수됨" |
| ASSUMPTION | 검증 안 됨 | "이 API는 하위 호환될 것" |

### 증거 강도 매트릭스

| 소스 | 강도 | 유효 기간 |
|------|------|----------|
| 소스 코드 직접 확인 | 최상 | 현재 |
| 공식 문서 | 상 | 버전 의존 |
| API 응답 | 상 | 실시간 |
| 커뮤니티 답변 | 중 | 확인 필요 |
| 메모리/캐시 | 하 | Stale 위험 |

---

## 원칙 6: Memory Staleness 방어

```
"Memories older than 1 day get a staleness caveat:
 'This memory is N days old. Claims about code behavior 
  or file:line citations may be outdated.'"
— Claude Code memoryAge.ts
```

**리서치에서도**: 이전 조사 결과를 인용할 때 반드시 현재 상태와 교차 검증.

---

## 리서치 템플릿

```markdown
# Research: [주제]

## 1. Research Question
[명확한 질문 1-2개]

## 2. Known Context (비용 0)
[이미 알고 있는 것]

## 3. Sources Consulted
| 소스 | 발견 | 분류 |
|------|------|------|
| [소스1] | [발견] | FACT |
| [소스2] | [발견] | INTERPRETATION |

## 4. Key Findings
- Finding 1: [FACT] ...
- Finding 2: [INTERPRETATION] ...

## 5. Competing Hypotheses
- H1: [가설] — 근거: [...]
- H2: [가설] — 근거: [...]

## 6. Synthesis (직접 합성)
[구체적 결론 — 파일:라인 수준의 구체성]

## 7. Remaining Uncertainties
[ASSUMPTION으로 남은 것 — 추가 조사 필요]

## 8. Recommended Next Actions
[구체적 다음 단계]
```

---

## 실행

`$ARGUMENTS`에 대해:
1. 리서치 질문 명확화
2. 비용 최소 게이트 순서로 소스 탐색
3. 병렬 에이전트로 독립 방향 동시 조사
4. 증거를 FACT/INTERPRETATION/ASSUMPTION으로 분류
5. 경쟁 가설 수립 및 검증
6. 직접 합성하여 구체적 결론 도출
