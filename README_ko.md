[English](README.md) | **한국어**

# cc-path

**Philosophy as Architecture** -- AI 코딩 어시스턴트 워크스페이스를 원칙 기반으로 설계하는 방법론.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> "We want Claude to be genuinely helpful to the humans it works with, as well as to society at large, while avoiding actions that are unsafe or unethical. We want Claude to have good values and be a good AI assistant, in the same way that a person can have good values while also being good at their job."
>
> -- Anthropic, *Claude's Character* (2024)

---

## 문제

대부분의 CLAUDE.md 파일은 카고 컬트(cargo cult)다. 블로그에서 프롬프트 조각을 복사해오고, 규칙을 계속 덧붙이다 500줄이 되고, Claude가 절반을 무시하는 이유를 모른다.

실패 패턴은 예측 가능하다:

- **Guidance와 governance의 구분이 없다.** 제안과 강제 규칙이 전부 CLAUDE.md 한 파일에 뒤섞여 있어서 아무것도 확실하게 작동하지 않는다.
- **원칙이 없다.** 설정이 감에 의존한다. 왜 이 규칙인가? 왜 이 구조인가? 설계 결정을 *왜 그것이 작동하는지*까지 추적할 수 있는 사람이 없다.
- **비구조적 로딩으로 인한 토큰 낭비.** 모든 규칙이 매 요청마다 로드된다. 600줄짜리 CLAUDE.md는 Claude가 코드를 한 줄 읽기도 전에 ~4K 토큰을 소비한다.
- **이해 없는 복사-붙여넣기.** "읽고 나서 쓰라"는 규칙을 쓰면서, 그것이 Chris Olah의 해석가능성(interpretability) 연구에서 유래했고 Anthropic의 엔지니어링 방법론의 핵심 원칙이라는 것을 모른다.

더 나은 방법이 있다.

## 해결책

**Harness Engineering**은 AI 코딩 어시스턴트 워크스페이스를 설계하는 시스템 엔지니어링 분야다. DevOps가 수작업 SSH 배포를 재현 가능한 인프라로 바꿨듯이, Harness Engineering은 CLAUDE.md를 프롬프트 모음에서 원칙 기반 아키텍처로 바꾼다.

핵심 통찰: Anthropic은 이미 철학을 공개했다. Claude Code 팀은 이미 엔지니어링 원칙을 공유했다. 이 프로젝트는 그 둘을 연결한다 -- Anthropic의 공개 논문과 엔지니어링 블로그에서 실질적인 워크스페이스 메커니즘까지, 모든 설계 결정을 추적한다.

결과물은 템플릿이 아니다. 인용이 달린 *레퍼런스 구현체*다.

## 아키텍처

이 harness는 세 개의 컨텍스트 레이어와 별도의 governance 플레인을 사용한다:

```
                        TOKEN BUDGET
                        ============
Layer 1: Always         CLAUDE.md + .claude/CLAUDE.md        ~2-3K tokens
         (Constitution) Design principles, cognitive cycle,
                        safety standards -- loaded every request

Layer 2: Conditional    .claude/rules/*.md (with paths:)     0 tokens until triggered
         (Case Law)     Thinking framework, cognitive
                        protection -- loaded when relevant
                        files are accessed

Layer 3: On-demand      .claude/skills/*.md                  ~70 tokens each (frontmatter)
         (Playbooks)    Workflows, templates -- only
                        frontmatter in context, body
                        loaded on invocation

Layer G: Governance     .claude/hooks/                       0 context tokens
         (Enforcement)  deploy-guard, circuit-breaker,
                        input-sanitizer -- 100% enforcement
                        via PreToolUse/PostToolUse hooks
```

임의로 만든 설계가 아니다. Claude Code 내부의 로딩 순서에 직접 대응한다:

```
Managed -> User -> Project (root->CWD) -> Local -> AutoMem
```

뒤쪽 레이어가 앞쪽을 덮어쓴다. 서브프로젝트 CLAUDE.md가 부모를 오버라이드한다. 이 아키텍처는 그것을 명시적으로 반영한다.

## 빠른 시작

```bash
# 저장소 클론
git clone https://github.com/ziho/cc-path.git
cd cc-path

# harness를 프로젝트에 복사
cp harness/CLAUDE.md your-project/CLAUDE.md
cp -r harness/.claude your-project/.claude

# 끝. 이제 프로젝트에 다음이 적용된다:
# - Anthropic의 공개된 엔지니어링 원칙에서 추출한 7가지 설계 원칙
# - Safety hooks (deploy guard, circuit breaker)
# - Cognitive protection 의사결정 매트릭스
# - 측정된 토큰 버짓 기반의 3레이어 컨텍스트 아키텍처
# - 주장 분류를 위한 Evidence hierarchy
```

여기서부터 커스터마이즈하면 된다. Harness는 출발점이지 족쇄가 아니다.

## 핵심 원칙

Anthropic의 공개된 엔지니어링 원칙에서 추출한 7가지 원칙. 각각이 구체적인 구현 결정으로 추적 가능하다.

| # | 원칙 | 출처 | 의미 |
|---|------|------|------|
| 1 | **Fail Closed, Default Safe** | Anthropic의 공개된 엔지니어링 원칙 | 불확실할 때는 제한적으로. 안전하다고 증명되기 전까지 안전하지 않다고 가정한다. |
| 2 | **Prompt Is Architecture** | Claude Code 컨텍스트 로딩 설계 | CLAUDE.md 레이어는 프롬프트가 아니다 -- 정의된 오버라이드 시맨틱을 가진 시스템 동작을 인코딩한다. |
| 3 | **Progressive Compression** | Claude Code 메모리 파일 로딩 | 3레이어 컨텍스트(always / conditional / on-demand)와 레이어별 측정된 토큰 버짓. |
| 4 | **Never Delegate Understanding** | Anthropic의 공개된 엔지니어링 원칙 | 위임하기 전에 이해를 증명한다. "조사 결과를 바탕으로 고쳐"는 안 된다. |
| 5 | **Verification = Proof, Not Confirmation** | Anthropic의 공개된 엔지니어링 원칙 | 기능을 켠 상태로 테스트한다. 에러를 "무관하다"며 무시하지 않는다. 회의적이어야 한다. |
| 6 | **Data-Driven Circuit Breakers** | PreToolUse hook 체인 | 직감이 아닌 측정에서 임계값을 정한다. 3회 연속 실패 시 비활성화. |
| 7 | **Explicit Over Clever** | Anthropic의 공개된 엔지니어링 원칙 | 암묵적 의존성 없음. 매직 없음. 각 하위 문제가 명확한 입출력과 기준으로 자립한다. |

## Guidance vs Governance 분리

Harness engineering을 prompt engineering과 구분하는 핵심 통찰:

```
CLAUDE.md  = Guidance  (~80%)    "You should read before you write"
                                  Claude follows this most of the time.
                                  Flexible. Contextual. Overridable.

Hooks      = Governance (100%)   "You cannot deploy with --force"
                                  Enforced by PreToolUse/PostToolUse.
                                  No exceptions. No context cost.
                                  The safety net that never breaks.
```

이 분리는 Anthropic의 Constitutional AI 구조를 반영한다 -- 원칙(guidance)과 RLHF 제약(governance)의 결합. Claude Code에서 `settings.json` hooks는 모델이 tool call을 보기 *전에* 실행된다. 모델이 이를 우회할 수 없다.

## 철학 레이어

이 harness는 설계의 근거를 Anthropic이 공개한 다섯 갈래의 사고에서 찾는다:

| 사상가 | 저작 | Harness 메커니즘 |
|--------|------|-----------------|
| **Dario Amodei** | *Machines of Loving Grace* (2024) | Cognitive Cycle (ORIENT-ANALYZE-PLAN-EXECUTE-VERIFY-LEARN) -- AI를 인간 판단의 증폭기로, 대체제가 아닌 것으로 설계 |
| **Amanda Askell** | *Claude's Character* (2024) | 규칙보다 성격 -- harness는 단순한 지시가 아니라 *가치*(주장 전에 검증, 쓰기 전에 읽기)를 인코딩한다 |
| **Chris Olah** | *Zoom In* (Distill, 2020) | "읽고 나서 쓰라" 원칙 -- 해석가능성 연구에서 유래한, 수정 전에 시스템을 이해하라는 원칙 |
| **Boris Cherny** | Claude Code 엔지니어링 | "단순한 것부터 하라" -- RAG 대신 Glob+Grep, 임베딩 대신 직접 파일 읽기, 추상화보다 조합 |
| **Jan Leike** | Alignment 연구 | 최소 마찰 안전장치 -- hooks가 개발자에게 부담을 주거나 컨텍스트 토큰을 소비하지 않으면서 강제한다 |

전체 매핑은 [`docs/ANTHROPIC-PHILOSOPHY.md`](docs/ANTHROPIC-PHILOSOPHY.md)에 있다.

## Constitutional AI 비유

CLAUDE.md 계층구조는 그 자체로 헌법이다:

```
Constitution (CLAUDE.md)
    Principles that govern all behavior.
    "Fail closed. Read before write. Verify before claim."
        |
        v
Case Law (.claude/rules/)
    Specific applications of principles to contexts.
    "When touching auth code, apply hard-confirm friction."
        |
        v
Self-Critique (Cognitive Cycle)
    Every action passes through ORIENT -> VERIFY.
    The system critiques its own outputs before delivering.
        |
        v
Feedback Loop (hooks + memory)
    Governance hooks enforce hard limits.
    Memory captures learnings for future sessions.
```

이것은 비유가 아니다. Constitutional AI는 모델이 원칙 집합에 대해 자기 출력을 비판하도록 훈련시킨다. Harness도 같은 일을 한다: CLAUDE.md가 원칙을 정의하고, Cognitive Cycle이 자기비판을 강제하며, hooks가 하드 바운더리를 제공한다.

## Cognitive Protection Matrix

Harness의 가장 실용적인 메커니즘 중 하나. 모든 액션을 실행하기 전에 두 축으로 분류한다:

|  | **Reversible** | **Irreversible** |
|---|---|---|
| **Objective** (정답이 명확) | Auto-pass | Soft confirm |
| **Subjective** (판단이 필요) | Soft confirm | Hard confirm |

실제 예시:

| 액션 | 분류 | 마찰 수준 |
|------|------|----------|
| 코드 포맷팅 | Reversible + Objective | Auto-pass |
| 파일 삭제 | Irreversible + Objective | Soft confirm |
| 아키텍처 선택 | Reversible + Subjective | Soft confirm |
| 프로덕션 배포 | Irreversible + Subjective | **Hard confirm** |

에스컬레이션 트리거는 매트릭스를 오버라이드한다: auth, 결제, PII, 또는 일괄 작업(10개 이상 파일)은 항상 hard confirm이 필요하다.

## 프로젝트 구조

```
cc-path/
|
+-- README.md                  English
+-- README_ko.md               한국어 (지금 읽고 있는 문서)
+-- LICENSE                    MIT
|
+-- harness/                   어떤 프로젝트에든 바로 적용 가능한 harness
|   +-- CLAUDE.md              Layer 1: 항상 로드되는 원칙
|   +-- .claude/
|       +-- CLAUDE.md          개발 컨벤션
|       +-- rules/             Layer 2: 조건부 규칙
|       |   +-- thinking-framework.md
|       |   +-- cognitive-protection.md
|       +-- skills/            Layer 3: 온디맨드 워크플로우
|       +-- hooks/             Layer G: Governance 강제
|           +-- deploy-guard.sh
|           +-- circuit-breaker.sh
|
+-- docs/                      상세 레퍼런스 (필요할 때 읽기)
|   +-- ANTHROPIC-PHILOSOPHY.md    철학-코드 계보
|   +-- CLAUDE-CODE-PRINCIPLES.md  15가지 원칙 + 출처 인용
|   +-- GUIDE.md                   구현 가이드
|
+-- examples/                  서브프로젝트 템플릿
|   +-- python-api/
|   +-- typescript-webapp/
|
+-- blog/                      블로그 글
```

## 문서

| 문서 | 목적 |
|------|------|
| [`docs/ANTHROPIC-PHILOSOPHY.md`](docs/ANTHROPIC-PHILOSOPHY.md) | Anthropic의 공개 철학(Constitutional AI, RSP, Machines of Loving Grace, Claude's Character)을 구체적인 harness 메커니즘에 매핑한다. 모든 설계 결정의 *이유*. |
| [`docs/CLAUDE-CODE-PRINCIPLES.md`](docs/CLAUDE-CODE-PRINCIPLES.md) | Anthropic의 공개된 엔지니어링 원칙에서 추출한 15가지 원칙. 구현을 이끄는 *무엇*. |
| [`docs/GUIDE.md`](docs/GUIDE.md) | 프로젝트에 harness를 도입하는 단계별 가이드. 커스터마이즈, 서브프로젝트 설정, hook 구성, 토큰 버짓 관리를 다룬다. |

## Evidence Hierarchy

Harness에 내장된 핵심 관행. 어떤 주장에 대해 행동하기 전에 분류한다:

- **FACT** -- 코드, 문서, 또는 테스트 출력에서 직접 관찰 가능. 출처를 인용한다.
- **INTERPRETATION** -- 사실로부터의 합리적 추론. 추론 과정을 명시한다.
- **ASSUMPTION** -- 검증되지 않음. 명시적으로 표시한다. 이 위에 뭔가를 쌓기 전에 검증한다.

이 README는 스스로의 규칙을 따른다. 본문의 출처 인용은 FACT다. Constitutional AI 비유는 INTERPRETATION이다. 모든 주장을 직접 검증할 수 있다.

## 기여하기

기여를 환영한다. 기준은 단순하다:

1. **모든 원칙에 출처 인용이 있어야 한다.** 감이 아니라 근거. Anthropic 논문, 공식 블로그 포스트, 또는 공개 문서에 링크를 건다.
2. **Harness 변경은 토큰 버짓에 맞아야 한다.** Layer 1은 3K 토큰 이하. Rules는 각각 1.5KB 이하.
3. **Harness 변경을 테스트한다.** 수정한 harness를 실제 프로젝트에 복사하고, Claude Code가 기대대로 동작하는지 확인한다.

```bash
# Fork 후 클론
git clone https://github.com/YOUR_USERNAME/cc-path.git

# harness/ 또는 docs/에서 수정

# PR 제출 시 포함:
# - 무엇이 바뀌었는지
# - 왜 (출처 인용과 함께)
# - 어떻게 테스트했는지
```

## FAQ

**Claude Code 전용인가?**
Harness 파일 자체는 Claude Code에 특화되어 있다(CLAUDE.md, `.claude/` 디렉토리, hooks). 하지만 *원칙* -- 레이어드 컨텍스트, guidance vs governance, evidence hierarchy -- 은 어떤 AI 코딩 어시스턴트에든 적용된다. 파일 형식이 달라도 방법론은 이전 가능하다.

**Claude Code가 업데이트되면 구식이 되지 않나?**
원칙은 Anthropic의 공개 철학에서 유래하며, 이는 안정적이다. 구현 세부사항(파일 경로, 로딩 순서)은 Claude Code의 문서화된 동작을 추적한다. Claude Code가 변경되면 인용을 업데이트한다. 아키텍처는 유지된다.

**awesome-claude-code 같은 목록과 뭐가 다른가?**
그것들은 팁 모음이다. 이것은 아키텍처다. 그 차이는 셸 별칭 모음과 제대로 된 CI/CD 파이프라인의 차이와 같다. 둘 다 bash를 쓴다. 하나는 엔지니어링이다.

## 라이선스

[MIT](LICENSE) -- 쓰고, 포크하고, 수정하고, 배포한다.

## 감사의 말

- **Anthropic** -- 철학을 공개적으로 발표해준 것에 감사한다. Constitutional AI, RSP, Claude's Character, Machines of Loving Grace 모두 공개 문서다. 이 프로젝트는 그 기반 위에 세워졌다.
- **Claude Code 팀** (Boris Cherny 등) -- "단순한 것부터 하라"는 원칙과, 원칙 기반 설정에 보상하는 아키텍처를 만든 것에 감사한다.
- **[oh-my-claudecode](https://github.com/nicobailey/oh-my-claudecode)** -- Harness 패턴을 빠르게 실험할 수 있게 해준 플러그인 생태계에 감사한다.
- **Claude Code 커뮤니티** -- 이 프로젝트가 체계화한 패턴들을 발굴해준 것에 감사한다.

---

*Context Engineering은 prompt engineering이 아니다. 시스템 엔지니어링 분야다. 이 프로젝트는 그 레퍼런스 구현체다.*
