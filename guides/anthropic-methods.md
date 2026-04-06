# Anthropic Methods — Auto-Injected Guide

Claude Code 소스코드(1905파일)에서 추출한 방법론을 **자동으로** 적용하는 가이드.
이 파일은 키워드 감지 시 auto_guide_loader가 주입한다.

---

## 자동 적용 규칙

아래 상황이 감지되면 해당 원칙/스킬을 **명시적 호출 없이** 자동 적용:

### 코드 작성/수정 시
- **Read Before Write** — 코드를 읽기 전에 수정 제안 금지
- **Minimum Necessary Change** — 요청된 것만 변경, 주변 정리 금지
- **Explicit Over Clever** — 3줄 반복이 조기 추상화보다 낫다
- 복잡한 변경 → `/anthropic-strategic-plan` 원칙으로 Plan 수립

### 문제 해결/디버깅 시
- **Diagnose Before Switching** — 실패 원인 파악 후 전략 변경
- **FACT/INTERPRETATION/ASSUMPTION** 분류 자동 적용
- **Circuit Breaker** — 3회 연속 실패 시 접근법 재평가
- 복잡한 버그 → `/anthropic-problem-solve` 프레임워크 적용

### 프롬프트/문서 작성 시
- **Identity→Constraints→Context** 순서
- **우선순위 신호** 체계 (CRITICAL > IMPORTANT > NEVER > MUST)
- **7가지 수사 기법** 자동 적용
- `/anthropic-prompt-craft` + `/anthropic-document-craft` 원칙 병합

### 플래닝/설계 시
- **5단계 Plan Mode** 워크플로우 자동 진입
- **병렬 탐색** — 독립 작업 식별 시 최대 3 에이전트
- **Never Delegate Understanding** — 위임 시 파일:라인 수준 스펙
- `/anthropic-strategic-plan` + `/anthropic-architecture` 원칙 병합

### 리서치/조사 시
- **Cheapest-First** — 저렴한 소스부터 소진
- **병렬 탐색** — 독립 방향 동시 조사
- **증거 분류** — FACT/INTERPRETATION/ASSUMPTION
- `/anthropic-research` 프레임워크 적용

### 에이전트 위임 시
- **Never Delegate Understanding** — 이해를 직접 합성
- **Fresh Agent**: 완전한 브리핑 (무엇, 왜, 이미 알아낸 것)
- **Fork Agent**: 간결한 지시만 (배경 반복 금지)
- **병렬화**: 독립 작업 반드시 병렬, 의존 작업 반드시 직렬

### 토큰/효율성 관련 시
- **8K Cap + Escalation** — 출력은 짧고 밀도 높게
- **Deferred Loading** — 필요한 것만 로드
- **Analysis-then-Strip** — CoT 품질 + 토큰 절약
- `/anthropic-token-zero` 전략 적용

### 테스트/검증 시
- **독립 적대적 검증** — 작성자 ≠ 검증자
- **Fail-Closed** — 불확실하면 안전한 쪽으로
- **검증 체크리스트** 자동 적용
- `/anthropic-verify` 프레임워크 적용

---

## 스킬 연계 매트릭스

| 상황 | 1차 스킬 | 보조 스킬 |
|------|---------|----------|
| 코드 작성 | principles | architecture |
| 디버깅 | problem-solve | verify |
| 플래닝 | strategic-plan | research |
| 문서 작성 | document-craft | prompt-craft |
| 설계 | architecture | folder-mastery |
| 리서치 | research | context-engine |
| 에이전트 위임 | principles | token-zero |
| 스킬 만들기 | skill-forge | harness-craft |
| 토큰 최적화 | token-zero | context-engine |
| 프롬프트 작성 | prompt-craft | principles |

---

## The Anthropic Way (10대 원칙 — 항상 적용)

1. Read Before Write
2. Diagnose Before Switching
3. Minimum Necessary Change
4. Parallel Independent, Serial Dependent
5. Verify Before Claiming
6. Cheapest First
7. Fail Closed
8. Never Delegate Understanding
9. Explicit Over Clever
10. Cache Economics Drive Architecture
