---
name: anthropic-principles
description: "Claude Code 소스에서 추출한 통합 철학/원칙/프레임워크 — Fail Closed, Never Delegate Understanding, GOLDE 사이클, 6대 설계 원칙, 캐시 경제학"
whenToUse: "원칙, 철학, 프레임워크, 방법론 참조, principles, philosophy, framework, 가이드라인"
model: opus
---

# Anthropic Principles

Claude Code 1905파일, 804KB 시스템 프롬프트에서 추출한 통합 철학, 원칙, 프레임워크.

## 적용 대상: $ARGUMENTS

---

## I. 6대 설계 원칙 (Design Principles)

### 1. Fail Closed, Default Safe
```
알 수 없는 것은 위험한 것으로 간주.
isConcurrencySafe: false (증명될 때까지)
isReadOnly: false (증명될 때까지)
분류기 불가용 → ask (auto-allow 아님)
```

### 2. Prompt Is Architecture
```
프롬프트는 코드가 아니라 아키텍처.
시스템 프롬프트의 섹션 순서, 캐시 경계, 우선순위 신호 —
모두 의도적 설계 결정이며, 캐시 경제학이 이를 지배.
```

### 3. Progressive Compression
```
truncate하지 않고 persist.
persist하지 않고 defer.
context를 잃지 않고 compress.
3단계 캐스케이드: micro → session-memory → full.
```

### 4. Never Delegate Understanding
```
"Don't write 'based on your findings, fix the bug.'"
이해를 위임하지 않는다. 직접 합성하고, 
파일:라인 수준의 구체적 스펙으로 위임.
```

### 5. Data-Driven Circuit Breakers
```
3회 연속 실패 → 전략 중단 (무한 재시도 금지)
250K API calls/day 낭비 → 회로 차단기 도입
p99 output 4,911 tokens → 8K cap 설정
```

### 6. Explicit Over Clever
```
"Three similar lines of code is better than a premature abstraction."
영리한 추상화보다 명시적 반복.
미래 요구사항을 위한 추측적 설계 금지.
```

---

## II. GOLDE 인지 사이클

```
1. ORIENT  — 문제를 재정의하고, 기존 코드/문서를 먼저 읽는다
2. ANALYZE — 증거를 수집하고, FACT/INTERPRETATION/ASSUMPTION 분류
3. PLAN    — 의존성으로 분해하고, 안전한 독립 작업만 병렬화
4. EXECUTE — 작고 검증된 변경. 추측적 추상화 금지
5. VERIFY  — 테스트/체크로 증명. 직관이 아닌 증거
6. LEARN   — 비자명한 재사용 가능 인사이트만 보존
```

---

## III. 7가지 수사 원칙 (Rhetoric Principles)

| # | 원칙 | 설명 |
|---|------|------|
| 1 | Consequence Framing | "왜"를 결과와 함께 설명 |
| 2 | Positive-then-Negative | DO 먼저, DON'T 나중 |
| 3 | Concrete Over Abstract | 구체적 예시 > 추상적 규칙 |
| 4 | Persona Calibration | "동료"로 프레이밍 → 판단력 유도 |
| 5 | Anti-Pattern Inoculation | 실패 모드를 명시적으로 설명 |
| 6 | Scope Anchoring | 승인 범위를 명확히 제한 |
| 7 | Anti Gold-Plating | 3+ 지점에서 과도한 최적화 방지 |

---

## IV. 안전 원칙 (Safety Principles)

| # | 원칙 | 구현 |
|---|------|------|
| 1 | Fail Closed, Default Deny | 미지의 경로 → 차단 |
| 2 | TOCTOU Prevention | 셸 확장 거부, 대소문자 정규화 |
| 3 | Defense in Depth | 다중 독립 레이어 (권한+분류기+훅+샌드박스) |
| 4 | Informed Consent | 경고 제공, 차단 안 함 (사용자 자율성) |
| 5 | Enterprise Controllability | 관리 설정 > 사용자 설정 |
| 6 | Minimal Trust Surface | 훅 신뢰 필수, 어시스턴트 텍스트 분류기 제외 |

---

## V. 토큰 경제학 원칙

| 원칙 | 공식 |
|------|------|
| 8K Cap | p99 output ÷ model max = 효율 배율 (4-6x) |
| Deferred Loading | 도구 수 × 스키마 크기 = 절약 토큰 (30-50%) |
| Cache Scoping | 정적 비율 × fleet 크기 = 캐시 히트 가치 |
| Persist vs Truncate | 정보 보존 = 미래 재읽기 비용 절약 |
| Rough Estimation | length/4 오차율(25%) < API 호출 비용 |

---

## VI. 조직화 원칙

| 원칙 | 적용 |
|------|------|
| 7계층 파이프라인 | 의존성은 아래로만 |
| 디렉토리 승격 기준 | 3+ 파일 or UI/프롬프트 분리 시 |
| 4가지 네이밍 컨벤션 | PascalCase/camelCase/kebab/SCREAMING |
| 레지스트리 패턴 | 모든 실행 단위의 단일 진실 소스 |
| Import Cycle 방지 | types/ 추출, 지연 require, 레지스트리 |

---

## VII. 에이전트 조율 원칙

| 원칙 | 적용 |
|------|------|
| 병렬 독립, 직렬 의존 | 읽기=병렬, 같은 파일 쓰기=직렬 |
| Mailbox 통신 | 파일 기반 메시지 (프로세스 경계 초월) |
| 3 백엔드 | tmux(격리) / in-process(저지연) / remote(클라우드) |
| Team Lead ↔ Worker | Lead가 합성, Worker가 실행 |
| 검증 분리 | 작성자 ≠ 검증자 (동일 컨텍스트 자기승인 금지) |

---

## VIII. 통합 프레임워크: The Anthropic Way

```
1. READ BEFORE WRITE
   → 코드를 읽기 전에 수정하지 않는다

2. DIAGNOSE BEFORE SWITCHING
   → 실패 시 원인을 파악한 후 전략 변경

3. MINIMUM NECESSARY CHANGE
   → 요청된 것만 변경. 주변 정리/개선 금지

4. PARALLEL INDEPENDENT, SERIAL DEPENDENT
   → 독립 작업은 병렬, 의존 작업은 직렬

5. VERIFY BEFORE CLAIMING
   → 직관이 아닌 증거로 완료를 증명

6. CHEAPEST FIRST
   → 비싼 작업 전에 저렴한 소스를 먼저 소진

7. FAIL CLOSED
   → 불확실하면 안전한 쪽으로 실패

8. NEVER DELEGATE UNDERSTANDING
   → 이해를 직접 합성하고 구체적 스펙으로 위임

9. EXPLICIT OVER CLEVER
   → 3줄 반복이 조기 추상화보다 낫다

10. CACHE ECONOMICS DRIVE ARCHITECTURE
    → 프롬프트 구조, 도구 로딩, 상태 관리 —
       모두 캐시 히트율이 설계를 지배
```

---

## 실행

`$ARGUMENTS`에 대해 위 원칙 체계를 적용:
1. 관련 원칙 카테고리 식별 (설계/안전/토큰/조직화/조율)
2. GOLDE 사이클로 접근
3. 해당 원칙을 구체적 행동으로 번역
4. Anti-pattern 확인
5. 결과물에 원칙 준수 여부 자기검증
