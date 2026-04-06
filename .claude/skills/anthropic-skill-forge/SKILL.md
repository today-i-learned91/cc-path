---
name: anthropic-skill-forge
description: "Anthropic 수준의 스킬 제작/관리 방법론 — frontmatter 설계, 3계층 소스 우선순위, 예산 제어, 보안 자동승인, MCP 스킬 통합"
whenToUse: "스킬 만들기, 스킬 설계, 스킬 관리, skill creation, skill management, 자동화 워크플로우"
---

# Anthropic Skill Forge

Claude Code의 Skill System(20파일), SkillTool, bundledSkills 아키텍처에서 추출한 스킬 제작/관리 방법론.

## 적용 대상: $ARGUMENTS

---

## 스킬 아키텍처: 3계층 소스 우선순위

```
1. managed    — 정책 설정 (최고 우선순위)
2. bundled    — CLI 바이너리에 컴파일됨
3. plugin     — 설치된 플러그인에서 제공
4. skills     — 사용자/프로젝트 .claude/skills/
5. mcp        — MCP 서버에서 발견
6. commands   — (deprecated)
```

**우선순위가 높은 소스가 동명 스킬을 오버라이드.**

---

## 스킬 파일 구조

```
.claude/skills/{skill-name}/SKILL.md
```

**SKILL.md만 지원.** 단일 `.md` 파일은 지원 안 됨.

### Frontmatter 설계

```yaml
---
name: my-skill                    # 고유 식별자
description: "한 줄 설명"          # 발견/검색용
whenToUse: "키워드1, 키워드2"      # 자동 트리거 조건
model: opus                       # 모델 오버라이드 (inherit = 부모 모델)
effort: high                      # 노력 수준
allowedTools:                     # 도구 제한 (선택)
  - Read
  - Grep
  - Glob
context: fork                     # fork 서브에이전트로 실행 (선택)
agent: explore                    # 에이전트 타입 (선택)
hooks: { ... }                    # 세션 스코프 훅 (선택)
shell: zsh                        # 셸 설정 (선택)
paths: ["src/**/*.ts"]            # 경로 기반 활성화 (선택)
disableModelInvocation: false     # 모델 직접 호출 방지 (선택)
userInvocable: true               # 사용자 슬래시 커맨드 노출 (선택)
---
```

### Frontmatter 설계 원칙

| 필드 | 필수 | 효과 |
|------|------|------|
| `name` | O | 호출 식별자 |
| `description` | O | SkillTool 프롬프트에서 250자로 절단됨 |
| `whenToUse` | O | 자동 트리거 키워드 매칭 |
| `model` | - | 무거운 작업은 `opus`, 가벼운 건 `haiku` |
| `allowedTools` | - | 보안 범위 제한 |
| `context: fork` | - | 부모 컨텍스트에서 격리 실행 |

---

## 스킬 본문 작성 규칙

### 변수 치환
```markdown
$ARGUMENTS           — 사용자가 전달한 인자
${CLAUDE_SKILL_DIR}  — 스킬 디렉토리 경로
${CLAUDE_SESSION_ID} — 현재 세션 ID
```

### 인라인 셸 실행
```markdown
`! echo "hello"` 백틱으로 감싸면 셸 명령 실행
```
**MCP 스킬에서는 보안상 비활성화됨.**

### 예산 제약
```
스킬 목록 = 컨텍스트 윈도우의 1% (SKILL_BUDGET_CONTEXT_PERCENT)
개별 설명 상한 = 250자 (MAX_LISTING_DESC_CHARS)
번들 스킬은 절단 면제
```

**스킬이 많을수록 개별 설명 품질 하락 → 핵심 스킬만 유지.**

---

## 보안: 자동 승인 시스템

### Safe Properties 허용 목록
```
SAFE_SKILL_PROPERTIES = {
  name, description, whenToUse, paths, 
  userInvocable, disableModelInvocation, ...
}
```

**이 속성만 가진 스킬은 권한 프롬프트 없이 자동 승인.**
`allowedTools`, `hooks`, `shell` 등은 `ask` 동작 트리거.

### 권한 체크 순서
```
1. Deny 규칙 (패턴 매칭: 정확 또는 :* 접두사)
2. Remote canonical 자동 승인
3. Allow 규칙 (패턴 매칭)
4. Safe properties 자동 승인
5. Default: ask (영구 허용 규칙 제안)
```

---

## 스킬 실행 모드

### Inline (기본)
```
스킬 콘텐츠 → 사용자 메시지로 주입 → 모델이 직접 처리
장점: 컨텍스트 공유, 빠름
단점: 부모 컨텍스트 오염
```

### Forked (context: fork)
```
스킬 콘텐츠 → 서브에이전트에서 격리 실행 → 결과만 반환
장점: 격리, 독립 모델/도구 설정
단점: 부모 컨텍스트 없음
```

---

## 스킬 설계 베스트 프랙티스

### 1. 목적 주도 설계
```markdown
## 적용 대상: $ARGUMENTS
[스킬이 해결하는 문제를 명확히]
```

### 2. Phase 기반 구조
```markdown
## Phase 1: Orient
## Phase 2: Analyze
## Phase 3: Execute
## Phase 4: Verify
```

### 3. 안티패턴 접종
```markdown
## 하지 않을 것
- [명시적 안티패턴 나열]
```

### 4. 탈출 조건
```markdown
## 완료 기준
- [ ] [검증 가능한 체크리스트]
```

---

## 실행

`$ARGUMENTS`에 대해:
1. 스킬 목적과 트리거 조건 정의
2. Frontmatter 설계 (name, description, whenToUse, model)
3. Phase 기반 본문 작성
4. 보안 속성 결정 (allowedTools 필요 여부)
5. Inline vs Fork 실행 모드 선택
6. `~/.claude/skills/{name}/SKILL.md`에 저장
