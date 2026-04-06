---
name: anthropic-document-craft
description: "Anthropic 수준의 문서 작성 방법론 — README, ADR, 기술문서, 컴팩션 요약, Chain-of-Density 압축까지 소스코드에서 추출한 문서화 패턴"
whenToUse: "문서 작성, README, ADR, 기술문서, 요약, 정리, 보고서, 리포트 작성, documentation"
model: opus
---

# Anthropic Document Craft

Claude Code 소스코드에서 추출한 문서 작성 방법론. README.md(27KB), 9섹션 컴팩션 프롬프트, 내부 코드 문서화 패턴 분석 기반.

## 적용 대상: $ARGUMENTS

---

## 원칙 1: 목적부터, 구현은 나중에

```
나쁜 예: "Uses the Read API to access the filesystem and return file contents."
좋은 예: "Reads a file from the local filesystem."
```

**리드 문장은 "무엇을 하는가"이지 "어떻게 구현되었는가"가 아니다.**

---

## 원칙 2: 가정을 명시적으로 선언

```
"Assume this tool is able to read all files on the machine."
"If the User provides a path to a file assume that path is valid."
```

독자가 추측하지 않도록 전제를 밝힌다.

---

## 원칙 3: 결정 경계를 정의 (When / When NOT)

문서의 핵심 가치는 "언제 쓰는가"와 "언제 쓰지 않는가"의 경계를 명확히 하는 것.

```markdown
## When to Use
- Complex multi-step tasks requiring 3+ distinct steps
- Non-trivial tasks requiring careful planning

## When NOT to Use  
- Single straightforward task
- Trivial task with < 3 steps
- Purely conversational
```

---

## 원칙 4: 구체성 > 추상성 (능력 열거)

```markdown
## Supported
- PNG, JPG images (visual content)
- PDF files (max 20 pages per request)  
- Jupyter notebooks (.ipynb)
- Glob patterns: "**/*.js", "src/**/*.ts"
- Regex syntax: "log.*Error", "function\\s+\\w+"
```

지원하는 것을 구체적으로 나열. "다양한 파일 형식을 지원합니다"는 쓸모없다.

---

## 원칙 5: 반복은 강화 (Multi-Touchpoint Reinforcement)

핵심 지시는 여러 지점에서 반복:
- 시스템 프롬프트의 톤 섹션
- 개별 도구 프롬프트
- 에이전트 프롬프트

Claude Code에서 "no emojis"는 3+ 지점에서 반복된다. 중요한 것은 한 곳에만 쓰지 않는다.

---

## 원칙 6: 지시와 결과를 페어링

```
나쁜 예: "Use HEREDOC for commit messages."
좋은 예: "ALWAYS pass the commit message via a HEREDOC, a la this example:
         [구체적 코드 예시]"
```

왜 해야 하는지 + 정확히 어떻게 하는지를 함께 제공.

---

## 문서 유형별 템플릿

### A. 기술 문서 (README / ARCHITECTURE)

```markdown
# 프로젝트명
[한 문장 목적]

## Purpose / What
[이 프로젝트가 해결하는 문제]

## Quick Start
[가장 빠른 시작 경로 — 3단계 이내]

## Architecture
[계층 다이어그램 + 데이터 흐름]

## Key Concepts
[핵심 개념 3-5개, 각각 1-2문장]

## Usage
[주요 사용 패턴 + 예시]

## Configuration
[설정 옵션 테이블]

## Troubleshooting
[자주 발생하는 문제 + 해결법]
```

### B. ADR (Architecture Decision Record)

```markdown
# ADR-NNN: [결정 제목]

## Status: [proposed | accepted | deprecated | superseded]

## Context
[이 결정이 필요한 이유 — 제약조건, 드라이버]

## Decision
[선택한 옵션 + 핵심 근거]

## Consequences
### Pros
### Cons
### Trade-offs

## Alternatives Considered
[검토했지만 선택하지 않은 옵션 + 배제 이유]
```

### C. 컴팩션 요약 (Claude Code 9-Section Template)

대화를 압축할 때 사용하는 Anthropic의 실전 템플릿:

```markdown
## 1. Primary Request and Intent
[사용자가 달성하려는 최종 목표]

## 2. Key Technical Concepts  
[기술 용어, 아키텍처 패턴, 제약조건]

## 3. Files and Code Sections
[핵심 파일 경로 + 관련 코드 스니펫]

## 4. Errors and Fixes
[발생한 에러 + 적용한 수정]

## 5. Problem Solving Approach
[시도한 접근법 + 결과]

## 6. All User Messages (verbatim essence)
[사용자 메시지의 핵심 — 원문 보존]

## 7. Pending Tasks
[미완료 작업 목록]

## 8. Current Work State
[현재 진행 상태]

## 9. Optional Next Step
[다음에 해야 할 것 — 있는 경우만]
```

### D. Chain-of-Density 압축 (CoD)

반복 압축으로 고밀도 요약 생성:

1. **1회차**: 핵심 엔티티 추출, 느슨한 요약
2. **2회차**: 엔티티 보존 + 밀도 증가, 동일 길이
3. **3회차**: Fusion & Compression — 불필요한 연결어 제거
4. **4회차**: 자기 완결적 요약 완성 (외부 참조 없이 이해 가능)

**규칙**: 길이는 고정, 밀도만 증가. 엔티티 절대 손실 금지.

---

## 내부 코드 문서화 패턴

### 운영 체크리스트 마커
```typescript
// @[MODEL LAUNCH]: Update the latest frontier model
// @[MODEL LAUNCH]: Add a knowledge cutoff date
```

### 캐시 경제학 주석
```typescript
// affects only what the model sees, not sandbox enforcement.
// Saves ~150-200 tokens/request when sandbox is enabled
```

### 안티패턴 경고
```typescript
// DO NOT MODIFY THIS INSTRUCTION WITHOUT SAFEGUARDS TEAM REVIEW
// WARNING: Do not remove or reorder this marker without updating cache logic
```

### Feature Flag 문서화
```typescript
// feature('FORK_SUBAGENT') -- context forking for cache-sharing sub-agents
// feature('CACHED_MICROCOMPACT') -- cache-editing compaction (API-side)
```

---

## Analysis-then-Strip 기법

품질 향상을 위해 CoT를 쓰되, 최종 결과에서는 제거:

```markdown
<analysis>
[여기서 체계적 분석 수행 — 이 부분은 최종 출력에서 제거됨]
</analysis>

<summary>
[분석 결과만 남긴 고밀도 요약]
</summary>
```

Anthropic은 이 기법으로 컴팩션 요약 품질을 높이면서 컨텍스트 토큰을 절약한다.

---

## 실행

위 원칙과 템플릿을 `$ARGUMENTS`에 적용:
1. 문서 유형 식별 (기술문서/ADR/요약/보고서)
2. 적합한 템플릿 선택
3. 목적→구조→내용 순서로 작성
4. 결정 경계와 구체적 예시 포함
5. 핵심 지시는 다중 지점에서 강화
6. CoD 또는 Analysis-then-Strip 기법으로 압축
