---
name: anthropic-problem-solve
description: "Anthropic 수준의 문제 접근/해결 방법론 — 진단→가설→검증 루프, Fail-Closed 원칙, 가역성 분석, FACT/INTERPRETATION/ASSUMPTION 분류"
whenToUse: "문제 해결, 디버깅, 트러블슈팅, 버그 수정, 장애 대응, problem solving, debugging, investigation"
model: opus
---

# Anthropic Problem Solve

Claude Code의 시스템 프롬프트, 안전 메커니즘, 쿼리 파이프라인에서 추출한 문제 해결 방법론.

## 적용 대상: $ARGUMENTS

---

## 핵심 원칙: "Diagnose Before Switching"

```
"If an approach fails, diagnose why before switching tactics — 
 read the error, check your assumptions, try a focused fix. 
 Don't retry the identical action blindly, 
 but don't abandon a viable approach after a single failure either."
— Claude Code System Prompt
```

---

## Phase 1: ORIENT — 문제 정의

### 1.1 증거 수집 (Read Before Write)
- **코드를 읽기 전에 수정을 제안하지 않는다**
- 에러 메시지, 스택 트레이스, 로그를 먼저 수집
- 재현 조건을 파악

### 1.2 FACT / INTERPRETATION / ASSUMPTION 분류

| 분류 | 설명 | 예시 |
|------|------|------|
| **FACT** | 관찰 가능한 증거 | "에러 로그에 `TypeError: undefined`가 나옴" |
| **INTERPRETATION** | 증거 기반 추론 | "null check가 누락된 것 같음" |
| **ASSUMPTION** | 검증 안 된 전제 | "이 함수는 항상 객체를 반환할 것" |

### 1.3 가역성 분석 (Reversibility & Blast Radius)

모든 해결 행동을 실행 전에 분류:

```
Low Risk (즉시 실행):
  - 파일 읽기, 검색, 테스트 실행
  
Medium Risk (확인 후 실행):
  - 파일 수정, 설정 변경
  
High Risk (사용자 승인 필수):
  - 삭제, force push, 프로덕션 변경
  - "the cost of pausing to confirm is low, 
     while the cost of an unwanted action can be very high"
```

---

## Phase 2: ANALYZE — 가설 수립

### 2.1 경쟁 가설 (Competing Hypotheses)
최소 2개의 가설을 동시에 고려:

```markdown
H1: [가설] — 근거: [FACT/INTERPRETATION]
H2: [가설] — 근거: [FACT/INTERPRETATION]
```

### 2.2 증거-가설 매트릭스

| 증거 | H1 지지 | H2 지지 | H1 반증 | H2 반증 |
|------|---------|---------|---------|---------|
| [증거1] | O | | | |
| [증거2] | | O | O | |

### 2.3 비용 최소 탐색 순서 (Cheapest First)

Claude Code Dream 시스템의 게이트 순서 원칙:
```
1. 시간 게이트 (가장 저렴) → 2. 세션 게이트 → 3. 잠금 (가장 비쌈)
```

문제 해결에서도:
```
1. 로그/에러 메시지 확인 (0 비용)
2. 관련 코드 읽기 (저 비용)  
3. 검색/grep (저 비용)
4. 테스트 실행 (중 비용)
5. 코드 변경 시도 (고 비용)
```

---

## Phase 3: EXECUTE — 최소 변경 실행

### 3.1 최소 필요 변경 (Minimum Necessary Change)

```
"Don't add features, refactor code, or make 'improvements' beyond what was asked.
 A bug fix doesn't need surrounding code cleaned up.
 Don't add error handling for scenarios that can't happen."
— Claude Code System Prompt
```

### 3.2 하나씩, 검증하며

```
변경 1 → 테스트 → 통과? → 다음
                  → 실패? → 롤백 → 진단 → 재시도
```

**절대 하지 않을 것:**
- 동일한 행동을 맹목적으로 재시도
- 한 번 실패했다고 즉시 접근법 폐기
- 여러 변경을 한꺼번에 적용

### 3.3 Fail-Closed 디폴트

```
알 수 없는 경로 → 차단 (허용 아님)
분류기 불가용 → 사용자에게 물어봄 (자동 허용 아님)
거부 누적 3회 → 사용자에게 물어봄 (자동 허용 아님)
```

**원칙**: 불확실할 때는 안전한 쪽으로 실패.

---

## Phase 4: VERIFY — 증거 기반 검증

### 4.1 자기 검증은 불충분

```
"Independent adversarial verification must happen before you report completion.
 Your own checks do NOT substitute — only the verifier assigns a verdict."
— Claude Code Verification Agent
```

### 4.2 검증 체크리스트

```markdown
- [ ] 원래 문제가 재현되지 않음 (수정 확인)
- [ ] 기존 테스트 모두 통과 (회귀 없음)
- [ ] 새 테스트가 버그를 커버 (재발 방지)
- [ ] 의도하지 않은 부작용 없음
- [ ] FACT만으로 결론 도출 (ASSUMPTION에 의존하지 않음)
```

### 4.3 회로 차단기 (Circuit Breaker)

```
3회 연속 실패 → 접근법 재평가
"MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3"
→ Claude Code는 3회 연속 실패 시 해당 전략을 중단
```

---

## Phase 5: LEARN — 비자명한 교훈만 보존

```
"Preserve only non-obvious reusable insights"
— GOLDE Cycle Phase 6
```

**저장할 것**: 코드에서 유추할 수 없는 "왜" — 근본 원인, 숨겨진 제약
**저장하지 않을 것**: 코드 패턴, 파일 경로, git 히스토리 (코드에서 읽으면 됨)

---

## 안전 체크리스트 (모든 해결 행동 전)

Anthropic의 23개 Bash 보안 체크에서 추출한 사고 프레임:

1. **이 행동은 가역적인가?** (rm -rf는 비가역)
2. **다른 사람에게 영향을 주는가?** (push는 팀에 영향)
3. **TOCTOU 갭이 있는가?** (검증 시점 ≠ 실행 시점)
4. **숨겨진 확장이 있는가?** ($VAR, ~root 등)
5. **최소 권한으로 실행하는가?**

---

## 실행

`$ARGUMENTS`에 대해:
1. ORIENT: 증거 수집 + FACT/INTERPRETATION/ASSUMPTION 분류
2. ANALYZE: 경쟁 가설 수립 + 비용 최소 탐색
3. EXECUTE: 최소 변경 + 하나씩 검증
4. VERIFY: 독립 검증 + 회귀 확인
5. LEARN: 비자명한 교훈 보존
