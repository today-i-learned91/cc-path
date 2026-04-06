---
name: anthropic-prompt-craft
description: "Anthropic 수준의 프롬프트 엔지니어링 방법론 — Claude Code 소스에서 추출한 시스템 프롬프트 구성, 우선순위 신호, 수사 기법, 엣지 케이스 처리 패턴"
whenToUse: "프롬프트 작성, 시스템 프롬프트 설계, 도구 프롬프트, 에이전트 프롬프트, 프롬프트 최적화, instruction engineering"
model: opus
---

# Anthropic Prompt Craft

Claude Code 소스코드(1905파일, 804KB main.tsx)에서 과학적으로 추출한 프롬프트 엔지니어링 방법론.

## 적용 대상: $ARGUMENTS

---

## Phase 1: 구조 설계 (Identity-Constraints-Context 패턴)

Anthropic의 시스템 프롬프트는 반드시 이 순서를 따른다:

### 1.1 정체성 프레이밍 (가장 먼저)
```
"You are [역할]. You [핵심 능력/목적]."
```
- 한 문장으로 역할 확립. 나머지 모든 지시는 이 정체성 아래 종속됨
- Claude Code 예: "You are an interactive agent that helps users with software engineering tasks."

### 1.2 안전/보안 경계 (정체성 직후)
- 절대 금지 사항을 정체성 바로 뒤에 배치
- "NEVER", "MUST NOT" 급 제약은 여기서 선언
- Claude Code는 `CYBER_RISK_INSTRUCTION`을 position 2에 배치

### 1.3 시스템 메커니즘 (도구를 설명하기 전에)
- 모델이 사용할 수 있는 도구/기능의 작동 방식 설명
- "도구가 무엇인지" 이해한 후에 "어떻게 쓰는지" 안내

### 1.4 작업 실행 가이드 (가장 긴 섹션)
- 소프트웨어 엔지니어링 행동, 코드 스타일, 에러 처리 접근법
- DO → DON'T 순서 (긍정 먼저, 부정 나중)

### 1.5 도구 라우팅 (작업 철학 뒤)
- 어떤 도구를 언제 쓰는지 구체적 매핑 테이블
- "전용 도구 > 범용 도구" 원칙 명시

### 1.6 톤/스타일/효율성 (마지막 — 표현 레이어)
- 가장 마지막에 배치: 프레젠테이션 관심사이므로

---

## Phase 2: 우선순위 신호 체계 (Lexical Saliency Engineering)

모델의 어텐션 가중치는 타이포그래피 강조에 반응한다. 정확한 단계:

| 신호 | 강도 | 사용처 | 예시 |
|------|------|--------|------|
| 기본 산문 | 1x | 일반 가이드 | "Prefer editing existing files" |
| `Do not` | 2x | 표준 금지 | "Do not create files unless necessary" |
| `**Bold**` | 2.5x | 구조적 강조 | "**Don't peek.** **Don't race.**" |
| `IMPORTANT` | 3x | 강한 요구사항 | "IMPORTANT: Avoid using this tool to run..." |
| `CRITICAL` | 4x | 절대 요구사항 | "This is CRITICAL to assisting the user" |
| `NEVER` / `MUST` | 5x | 절대 금지/필수 | "NEVER update the git config" |
| `ALWAYS` | 4x | 보편적 요구 | "ALWAYS pass the commit message via HEREDOC" |

**원칙**: 모든 것을 CRITICAL로 쓰면 아무것도 CRITICAL이 아니게 됨. 진짜 중요한 것만 에스컬레이션.

---

## Phase 3: 7가지 수사 기법

### 3.1 결과 프레이밍 (Consequence Framing)
```
나쁜 예: "Don't force push."
좋은 예: "Taking unauthorized destructive actions can result in lost work, 
         so it's best to ONLY run these commands when given direct instructions."
```
왜 하면 안 되는지 결과를 설명하면 준수율이 올라간다.

### 3.2 긍정→부정 페어링
```
"When to Use This Tool" → (먼저)
"When NOT to Use This Tool" → (나중)
```
모델에게 결정 경계의 양쪽을 모두 보여줌.

### 3.3 구체적 예시 > 추상적 규칙
```
나쁜 예: "Be careful with destructive operations."
좋은 예: "Examples of risky actions:
         - Destructive: deleting files/branches, dropping database tables
         - Hard-to-reverse: force-pushing, git reset --hard
         - Visible to others: pushing code, creating PRs"
```

### 3.4 페르소나 캘리브레이션
```
"Brief the agent like a smart colleague who just walked into the room"
```
모델을 "동료"로 프레이밍하면 판단력이 있는 실행을 유도함.

### 3.5 안티패턴 접종 (Anti-Pattern Inoculation)
```
"Don't write 'based on your findings, fix the bug.' 
 Those phrases push synthesis onto the agent instead of doing it yourself."
```
실패 모드를 명시적으로 설명하여 사전에 차단.

### 3.6 범위 앵커링
```
"Authorization stands for the scope specified, not beyond. 
 Match the scope of your actions to what was actually requested."
```
일회성 승인이 포괄적 권한으로 확대되는 것을 방지.

### 3.7 안티 골드플레이팅
```
"Three similar lines of code is better than a premature abstraction."
"Don't add features beyond what was asked."
```
과도한 최적화/추상화를 사전에 차단. 이 지시를 3+ 지점에서 반복.

---

## Phase 4: 엣지 케이스 처리 패턴

### 4.1 명시적 예외 조항
```
"Only use emojis if the user explicitly requests it."
→ 기본 행동 + 오버라이드 경로를 한 문장에
```

### 4.2 컨텍스트 의존 행동 전환
```
"By default, ask for confirmation. This default can be changed by user instructions."
→ CLAUDE.md가 기본 주의를 오버라이드할 수 있음을 명시
```

### 4.3 조건부 지시 주입
```
if (userType === 'expert') → 더 공격적 지시
if (userType === 'beginner') → 더 보수적 지시
```

### 4.4 Fail-Closed 디폴트
```
"Only validate at system boundaries. Trust internal code."
→ 알 수 없는 것은 차단이 기본
```

---

## Phase 5: 도구 프롬프트 템플릿

모든 도구 프롬프트는 이 구조를 따른다:

```markdown
# 1줄 목적 선언
"Reads a file from the local filesystem."

# 사용법 (bulleted 제약사항)
- 지원 파일 형식 열거
- 기본 동작과 한계

# When to Use / When NOT to Use
(양쪽 결정 경계)

# Examples (XML 태그)
<example>
user: "..."
assistant: ...
<commentary>왜 이것이 올바른 행동인지</commentary>
</example>

# 중요 노트
IMPORTANT: ...
CRITICAL: ...
```

---

## Phase 6: 에이전트 프롬프트 (위임의 기술)

### "Never Delegate Understanding" 원칙
```
나쁜 예: "Based on your findings, fix the bug."
좋은 예: "In src/auth/middleware.ts:45-67, the session token validation 
         skips the expiry check when refresh=true. Add an expiry check 
         that returns 401 when token.exp < Date.now()."
```

### Fresh Agent 프롬프트 체크리스트
1. 무엇을 달성하려는지
2. 왜 중요한지
3. 이미 알아낸 것 / 배제한 것
4. 주변 문제의 맥락 (판단을 위해)
5. 기대하는 산출물 형태

### Fork Agent 프롬프트 (컨텍스트 상속)
- 지시만 간결하게 (배경 반복 금지)
- 범위 명확히: "what's in, what's out"
- "Don't peek" — 다른 fork의 결과를 읽지 말 것

---

## Phase 7: 캐시 경제학 (Fleet-Scale 최적화)

프롬프트가 프로덕션에서 수백만 요청에 사용될 때:

1. **정적/동적 분리**: 변하지 않는 부분은 `scope: 'global'`로 크로스오그 캐싱
2. **휘발성 데이터 격리**: 자주 변하는 데이터(MCP 지시 등)만 `uncached`로 표시
3. **DANGEROUS_uncached**: 매 턴 재계산이 필요한 섹션에만 사용 (캐시 무효화 비용이 크므로)
4. **에이전트 리스트 외부화**: 동적 에이전트 목록이 fleet cache_creation 토큰의 10.2%를 차지 → system-reminder로 이동

---

## 실행

위 프레임워크를 `$ARGUMENTS`에 적용하여:
1. 대상의 목적과 수신자를 파악
2. Identity-Constraints-Context 순서로 구조 설계
3. 우선순위 신호를 적절히 배치 (남용 금지)
4. 7가지 수사 기법 중 적합한 것 적용
5. 엣지 케이스를 명시적으로 처리
6. 결과물 산출
