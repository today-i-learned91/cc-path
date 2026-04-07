# cc-path

**Claude Code를 위한 Anthropic 급 AI 에이전트 운영체제. v2.0**

Claude Code 소스코드 1,905 파일을 알파벳 단위까지 분해해서 만든 플러그인.
이제 Claude는 "원칙을 안다"가 아니라 **"원칙을 어기면 시스템이 막는다"** 가 됩니다.

> 18개 스킬 + 6개 런타임 서브시스템 + 938줄의 진심.
> 설치 후 다음 세션부터 Claude가 다르게 행동합니다. 진짜로요.

---

## 📌 이 플러그인이 뭔가요

cc-path는 **Anthropic이 직접 Claude Code를 만들면서 따른 방법론을 추출해서 코드로 구현한 것**입니다.

10명의 Opus 에이전트가 1,905개 파일과 804KB 시스템 프롬프트를 과학적으로 분해했어요. 그 결과로 18가지 방법론 스킬과 능동적으로 행동을 강제하는 런타임 커널이 나왔습니다.

### 한 줄 요약

**"Claude Code가 자기 자신을 더 잘 쓰는 법을 알려주는 플러그인"**

### Before & After

```
# Before cc-path
유저: "이 버그 고쳐줘"
Claude: 코드 추측해서 수정 → 테스트 안 함 → "완료!" → 사실 안 됨

# After cc-path
유저: "이 버그 고쳐줘"
Claude:
  → [GOLDE:ORIENT] 자동 감지: 문제 정의 단계
  → 에러 읽고 FACT/INTERPRETATION/ASSUMPTION 분류
  → [GOLDE:ANALYZE] 경쟁 가설 2개 수립, Cheapest-First 탐색
  → [READ-BEFORE-WRITE 감지] 'auth.ts' 안 읽고 수정 시도 → 차단
  → [GOLDE:EXECUTE] 최소 변경
  → [VERIFY GAP] 3개 파일 수정, 검증 0회 → 테스트 자동 실행
  → 증거 기반 완료 보고
```

---

## 🎯 핵심 기능

### 18개 방법론 스킬 (자동 활성화)

슬래시 커맨드 안 쳐도 됩니다. 맥락에서 자동으로 켜져요.

| 카테고리 | 스킬 | 트리거 키워드 |
|---------|------|-------------|
| **핵심 원칙** | `principles`, `prompt-craft`, `document-craft` | (항상 활성) |
| **문제 해결** | `problem-solve`, `verify`, `research` | "디버그", "버그", "조사" |
| **설계** | `strategic-plan`, `architecture`, `folder-mastery` | "플랜", "설계", "리팩토링" |
| **에이전트 마스터리** | `agent-mastery`, `multi-agent`, `agent-automation`, `agent-interconnect` | "에이전트", "병렬", "팀" |
| **효율성** | `context-engine`, `token-zero` | "최적화", "토큰" |
| **메타** | `skill-forge`, `harness-craft`, `runtime` | "스킬", "훅" |

### 6개 런타임 서브시스템 (자동 강제)

| 시스템 | 무엇을 하나 |
|--------|------------|
| **🧭 GOLDE State Machine** | 인지 단계(Orient→Analyze→Plan→Execute→Verify→Learn) 자동 감지 + 합법적 전환만 허용 |
| **🔍 Evidence Tracker** | 파일별 read/modify/verify 타임스탬프 추적 → "안 읽고 수정" 차단 |
| **💰 Cost Tracker** | 5단계 도구 비용 분류(Free→Expensive) → 비싼 도구 먼저 쓰면 경고 |
| **🎯 Agent Quality Scorer** | 에이전트 위임 프롬프트 0.0~1.0 점수 → 모호한 위임 차단 |
| **✅ Verification Gate** | 미검증 파일 갭 리포트 → 3개 쌓이면 힌트, 5개 쌓이면 강제 넛지 |
| **📊 Session Metrics** | 5개 지표 복합 점수 + 크로스세션 트렌드(JSONL) |

### 자동으로 일어나는 일들

- ✅ 파일 안 읽고 수정 시도 → **즉시 경고**
- ✅ "Based on your findings, fix it" 같은 모호한 위임 → **품질 게이트 차단**
- ✅ 3개 파일 수정 후 검증 안 함 → **자동 검증 권장**
- ✅ 5개 파일 미검증 → **강제 넛지 + 미검증 파일 목록**
- ✅ Orient 단계에서 Write 도구 사용 → **Cheapest-First 위반 경고**
- ✅ `npm test` 자동 감지 → **검증 카운터 자동 리셋**
- ✅ 매 세션 종료 → **메트릭 자동 저장 + 트렌드 비교**

---

## ⚡ 빠른 시작

### 옵션 1: 프로젝트 디렉토리로 사용

```bash
git clone https://github.com/today-i-learned91/cc-path.git
cd cc-path
claude
```

이게 끝입니다. 18 스킬 + 6 서브시스템 전부 자동 활성화돼요.

### 옵션 2: 다른 프로젝트에 추가

```bash
git clone https://github.com/today-i-learned91/cc-path.git ~/cc-path
cd your-project
claude --add-dir ~/cc-path
```

### 옵션 3: 글로벌 스킬만 설치

```bash
git clone https://github.com/today-i-learned91/cc-path.git
cp -r cc-path/.claude/skills/anthropic-* ~/.claude/skills/
```

스킬만 쓰고 훅은 설치 안 하는 미니멀 옵션. 단, 6 서브시스템은 작동 안 합니다.

---

## 🧬 10대 원칙 (Claude Code 소스에서 직접 추출)

| # | 원칙 | 출처 |
|---|------|------|
| 1 | **Read Before Write** | System prompt: "do not propose changes to code you haven't read" |
| 2 | **Diagnose Before Switching** | "read the error, check your assumptions, try a focused fix" |
| 3 | **Minimum Necessary Change** | "Don't add features beyond what was asked" |
| 4 | **Parallel Independent, Serial Dependent** | StreamingToolExecutor 동시성 제어 |
| 5 | **Verify Before Claiming** | Verification Agent: "independent adversarial verification" |
| 6 | **Cheapest First** | Dream system gate sequence (시간→세션→잠금) |
| 7 | **Fail Closed** | `TOOL_DEFAULTS.isConcurrencySafe: false` |
| 8 | **Never Delegate Understanding** | Coordinator: "Never write 'based on your findings'" |
| 9 | **Explicit Over Clever** | "Three similar lines > premature abstraction" |
| 10 | **Cache Economics** | `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` 정적/동적 분리 |

---

## 📈 메트릭 대시보드

세션이 끝나면 `.cc-path/metrics.json`에 자동 저장됩니다:

```json
{
  "session_id": "a3f1b2c8",
  "duration_seconds": 1847,
  "golde_compliant": true,
  "read_before_write_rate": 0.857,
  "evidence_coverage": 0.857,
  "cost_efficiency": 0.807,
  "avg_agent_quality": 0.72,
  "verification_runs": 4,
  "composite_score": 0.832
}
```

`.cc-path/sessions.jsonl`로 세션 간 트렌드도 추적할 수 있어요. Claude가 점점 좋아지는지 직접 보면 됩니다.

---

## 🏗️ 어떻게 만들었나

```
Phase 1: 분석
  10명의 Opus 에이전트 × 1,905 파일 × 1M+ 토큰 분석
  → 7개 도메인 (아키텍처, 프롬프트, 컨텍스트, 도구, 플래닝, 테스트, 쿼리)

Phase 2: 추출
  파일:라인 수준의 패턴 발견
  → 18개 방법론 스킬로 정제

Phase 3: 능동화
  5명의 Anthropic 급 에이전트(Founder, CTO, Scientist, Eng Lead, Research Lead) 합의
  → 938줄 런타임 커널로 구현

Phase 4: 검증
  Phase 감지(한국어/영어), Agent 품질 점수, 비용 분류, 검증 자동화 모두 통과
```

---

## 📂 구조

```
cc-path/
├── CLAUDE.md                              # 10 원칙 + 스킬 라우팅
├── README.md                              # 이 파일
├── .claude/
│   ├── CLAUDE.md                          # 프로젝트 레벨 지시
│   ├── settings.json                      # 7개 훅 등록 (자동 활성화)
│   └── skills/                            # 18개 방법론 스킬
│       ├── anthropic-principles/
│       ├── anthropic-prompt-craft/
│       ├── anthropic-document-craft/
│       ├── anthropic-strategic-plan/
│       ├── anthropic-problem-solve/
│       ├── anthropic-architecture/
│       ├── anthropic-verify/
│       ├── anthropic-research/
│       ├── anthropic-context-engine/
│       ├── anthropic-token-zero/
│       ├── anthropic-folder-mastery/
│       ├── anthropic-skill-forge/
│       ├── anthropic-harness-craft/
│       ├── anthropic-agent-mastery/
│       ├── anthropic-multi-agent/
│       ├── anthropic-agent-automation/
│       ├── anthropic-agent-interconnect/
│       └── anthropic-runtime/
├── hooks/
│   └── anthropic_runtime.py               # 938줄, 6 서브시스템 통합
└── guides/
    └── anthropic-methods.md               # 자동 주입 가이드
```

---

## 🎁 트레이드오프 (정직 모드)

| 장점 | 단점 |
|------|------|
| 0초 셋업, 첫 사용부터 효과 | Python 3.10+ 필요 (stdlib만 사용) |
| 외부 의존성 0개 | 대형 파일 작업 시 ~50ms 훅 오버헤드 |
| 토큰 절약 (단계별 스킬 선택) | 키워드 기반 단계 감지의 한계 |
| 측정 가능한 개선 | 메트릭은 휴리스틱 (perfect 아님) |
| 모든 코드 오픈소스 | LLM 호출 없음 = 깊은 추론 없음 |

**누구한테 안 맞나**:
- 즉흥적이고 자유로운 코딩을 원하는 경우 → 훅이 답답할 수 있음
- 단순 스니펫 생성용 → 오버킬
- "AI가 알아서 다 하길" 원하는 경우 → cc-path는 규율을 강제함

**누구한테 맞나**:
- 진짜 프로덕션 코드 작업
- 디버깅이 자주 필요한 환경
- Claude가 더 일관되고 검증 가능하길 원하는 사람
- Anthropic의 엔지니어링 철학을 배우고 싶은 사람

---

## 📜 라이선스

MIT

---

## 🙏 크레딧

- [Claude Code](https://claude.ai/code) 소스 분석으로 만들어졌습니다
- Anthropic의 엔지니어링 원칙에서 추출 (Anthropic 공식 제휴 아님)
- 빌드: Claude Code로 Claude Code를 분석함 (재귀적인 메타)

---

## English (Brief)

cc-path is a **Claude Code plugin extracted from scientific analysis of Claude Code's own source** (1,905 files, 804KB system prompt). It provides:

- **18 methodology skills** that auto-activate based on context
- **6-subsystem runtime kernel** (938 lines) that actively enforces principles:
  - GOLDE State Machine, Evidence Tracker, Cost Tracker, Agent Quality Scorer, Verification Gate, Session Metrics
- **10 principles** extracted directly from Claude Code's source code
- **Pure Python stdlib**, no dependencies, ~50ms hook overhead

**Quick start**:
```bash
git clone https://github.com/today-i-learned91/cc-path.git
cd cc-path && claude
```

That's it. Hooks auto-register, skills auto-activate. Your next session will be measurably better than your last one.

For full documentation in Korean, see above. ↑

---

**v2.0** | 2026-04-07 | Made with 🧠 by 10 Opus agents and 1 stubborn human
