# Claude Code Engineering Principles

Claude Code 소스코드(`claude-code-main/`)에서 직접 추출한 설계 원칙.
공식적으로 번호가 매겨진 목록은 없으며, 15개 원칙이 여러 파일에 분산되어 있다.

## Source Verification

- 소스: claude-code npm 소스맵 (`0cf2fa2e` 커밋, 2026-03-31)
- 모든 인용은 FACT (파일:줄번호 확인 가능)
- `ant-only` 표시: `USER_TYPE === 'ant'` 빌드 조건부 (내부 사용자 전용)

---

## A. Safety & Defaults (안전 & 기본값)

### 1. Fail-Closed Default

> 불확실할 때 제한적 기본값을 선택한다.

```
isConcurrencySafe → false (안전하지 않다고 가정)
isReadOnly → false (쓰기라고 가정)
toAutoClassifierInput → '' (보안 관련 도구는 반드시 override)
```

**출처**: `Tool.ts:748-755`
**적용**: 새 도구/기능 추가 시, 기본값은 항상 가장 제한적으로 설정.

### 2. Reversibility-Aware Action

> 행동의 가역성과 영향 범위(blast radius)를 먼저 고려한다.

> "The cost of pausing to confirm is low, while the cost of an unwanted action
> (lost work, unintended messages sent, deleted branches) can be very high."
> "Follow both the spirit and letter of these instructions — measure twice, cut once."

**출처**: `constants/prompts.ts:256-266`
**적용**: 비가역적/공유 시스템 영향 작업은 사용자 확인 후 실행.

### 3. Security Boundary Ownership

> 보안 경계 프롬프트에 명시적 팀 소유자를 지정한다.

```
IMPORTANT: DO NOT MODIFY THIS INSTRUCTION WITHOUT SAFEGUARDS TEAM REVIEW
Safeguards team: David Forsythe, Kyla Guru
```

**출처**: `constants/cyberRiskInstruction.ts:1-23`
**적용**: 보안 관련 설정은 소유자가 명확하고, 변경 시 검토 필수.

---

## B. Understanding & Verification (이해 & 검증)

### 4. Never Delegate Understanding

> 이해를 위임하지 마라. 파일 경로, 줄 번호, 구체적 변경 내용으로 이해를 증명하라.

> "Don't write 'based on your findings, fix the bug' or 'based on the research,
> implement it.' Those phrases push synthesis onto the agent instead of doing it yourself."

**출처**: `tools/AgentTool/prompt.ts:112`, `coordinator/coordinatorMode.ts:259-267`
**적용**: 에이전트 위임 시 반드시 구체적 지시 (파일:줄, 정확한 변경 내용).

### 5. Verification = Proof, Not Confirmation

> 검증은 증명이다. rubber-stamp하지 마라.

> "Run tests with the feature enabled — not just 'tests pass'.
> Run typechecks and investigate errors — don't dismiss as 'unrelated'.
> Be skeptical. Test independently — prove the change works, don't rubber-stamp."

**출처**: `coordinator/coordinatorMode.ts:220-227`
**적용**: "테스트 통과"가 아니라 "이 기능이 동작함"을 증명.

### 6. Read Before Write

> 읽지 않은 코드를 수정하지 마라.

> "In general, do not propose changes to code you haven't read.
> If a user asks about or wants you to modify a file, read it first."

**출처**: `constants/prompts.ts:230`
**적용**: 모든 수정 전 해당 파일을 먼저 읽기.

### 7. Diagnose Before Retrying

> 실패 시 맹목적 재시도 대신 원인을 진단한다.

> "If an approach fails, diagnose why before switching tactics — read the error,
> check your assumptions, try a focused fix. Don't retry the identical action blindly,
> but don't abandon a viable approach after a single failure either."

**출처**: `constants/prompts.ts:233`
**적용**: 동일 명령 반복 금지. 에러 메시지 읽기 → 가설 → 집중 수정.

### 8. Truthful Reporting (ant-only)

> 결과를 성실하게 보고한다. 실패를 숨기지 마라.

> "Never claim 'all tests pass' when output shows failures, never suppress or
> simplify failing checks to manufacture a green result."

**출처**: `constants/prompts.ts:240`
**적용**: 테스트 실패 시 있는 그대로 보고. 불완전한 작업을 완료라 하지 않음.

---

## C. Complexity & Scope (복잡도 & 범위)

### 9. Minimum Viable Complexity

> 요청된 것만 해결한다. 추측적 추상화 금지.

> "Don't create helpers, utilities, or abstractions for one-time operations.
> Don't design for hypothetical future requirements.
> Three similar lines of code is better than a premature abstraction."

**출처**: `constants/prompts.ts:201-203`
**적용**: 3줄 반복 > 조기 추상화. 버그 수정에 주변 코드 정리 붙이지 않기.

### 10. Scope Control

> 핵심으로 직행한다. 과잉 수행하지 마라.

> "Go straight to the point. Try the simplest approach first without going in circles.
> Do not overdo it. Be extra concise."

**출처**: `constants/prompts.ts:418,231`
**적용**: 가장 단순한 접근법부터 시도. 파일 생성은 불가피할 때만.

---

## D. Architecture & Systems (아키텍처 & 시스템)

### 11. Prompt-as-Architecture

> 프롬프트를 코드 모듈과 동등하게 관리한다.

- 정적/동적 분리: `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` 마커
- 캐시 보호: `DANGEROUS_uncachedSystemPromptSection()` 명명 규칙
- 소유권 지정: 보안 프롬프트에 팀 이름 명시

**출처**: `constants/prompts.ts:114`, `constants/systemPromptSections.ts:32`
**적용**: CLAUDE.md, rules, skills = 아키텍처의 일부. 캐시/우선순위/소유권 관리.

### 12. Progressive Context Compression

> 컨텍스트를 점진적으로 압축하여 무한 대화를 지원한다.

- `autoCompact`: 컨텍스트 한계 접근 시 자동 요약
- 최근 메시지 원본 유지, 오래된 메시지만 압축
- Dream: 세션 간 메모리 통합 (Orient → Gather → Consolidate → Prune)

**출처**: `services/compact/prompt.ts`, `services/autoDream/consolidationPrompt.ts`
**적용**: 지식 축적 시 L0→L1→L2→L3 압축 계층. 최근 데이터 원본 보존.

### 13. Compile-Time Feature Elimination

> 런타임 토글 대신 빌드 타임에 기능을 제거한다.

> "process.env.USER_TYPE === 'ant' is build-time --define. It MUST be inlined
> at each callsite (not hoisted to a const) so the bundler can constant-fold
> it to false in external builds and eliminate the branch."

**출처**: `constants/prompts.ts:618-619`
**적용**: feature flag보다 코드 직접 변경. 불필요한 런타임 조건 분기 제거.

---

## E. Execution & Coordination (실행 & 협업)

### 14. Parallelism as Superpower

> 독립 작업은 반드시 병렬로 실행한다.

> "Parallelism is your superpower. Workers are async. Launch independent workers
> concurrently whenever possible — don't serialize work that can run simultaneously."

규칙:
- 읽기 전용 → 자유롭게 병렬
- 쓰기 → 파일 세트별 하나씩
- 검증 → 구현과 다른 영역에서 병렬 가능

**출처**: `coordinator/coordinatorMode.ts:213`
**적용**: 2개 이상 독립 작업은 항상 병렬. Agent 동시 투입.

### 15. Stale-Data-Acceptable Gates

> 기능 게이트는 약간의 stale 데이터를 허용한다. 메인 루프를 차단하지 마라.

함수명이 원칙을 인코딩: `getFeatureValue_CACHED_MAY_BE_STALE`

> "stale true is acceptable (the server is the real gatekeeper)."

**출처**: `services/analytics/growthbook.ts:734`
**적용**: 비차단 확인. 실시간 정확성이 필요 없는 게이트에 캐시 허용.

---

## 원칙 분류 매트릭스

| 분류 | 원칙 | 적용 시점 |
|------|------|----------|
| **매 작업** | 1,4,5,6,7,9,10 | 모든 코드 변경에 적용 |
| **설계 시** | 2,3,11,12,13 | 아키텍처/시스템 설계 시 |
| **실행 시** | 8,14,15 | 에이전트 협업/병렬 실행 시 |

## 기존 "7대 원칙"과의 매핑

| 기존 7대 원칙 | 실제 소스 원칙 | 비고 |
|-------------|-------------|------|
| Fail Closed | #1 Fail-Closed Default | 일치 |
| Prompt Is Architecture | #11 Prompt-as-Architecture | 일치 |
| Progressive Compression | #12 Progressive Context Compression | 일치 |
| Never Delegate Understanding | #4 Never Delegate Understanding | 일치 |
| Data-Driven Circuit Breakers | — | **소스에 미명시** (해석) |
| Feature Flags = Dead Code | #13 Compile-Time Feature Elimination | 일치 |
| Explicit Over Clever | #9 + #10 종합 | 직접 명시 없음, 복합 해석 |
