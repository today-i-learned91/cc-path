---
name: anthropic-context-engine
description: "Anthropic 수준의 컨텍스트 엔지니어링 — 3단계 컴팩션 캐스케이드, cache-editing microcompact, deferred tool loading, 토큰 예산 관리, 메모리 시스템"
whenToUse: "컨텍스트 관리, 토큰 최적화, 프롬프트 최적화, context engineering, token management, 컨텍스트 윈도우"
model: opus
---

# Anthropic Context Engine

Claude Code의 3단계 컴팩션, 디퍼드 툴 로딩, 메모리 디렉토리, 토큰 예산 시스템에서 추출한 컨텍스트 엔지니어링 방법론.

## 적용 대상: $ARGUMENTS

---

## 핵심 철학

```
"Never truncate if you can persist,
 never persist if you can defer, 
 and never lose context if you can compress."
```

컨텍스트 윈도우 토큰은 가장 제약된 자원. 모든 서브시스템이 토큰 경제학 중심으로 설계됨.

---

## 아키텍처: 3단계 컴팩션 캐스케이드

```
Tier 1: Microcompact (무료)
  → 오래된 도구 결과를 캐시 편집으로 제거
  → 로컬 콘텐츠 수정 없음 → 캐시 미스 0

Tier 2: Session Memory Compact (경량)
  → 최근 메시지 보존 (10K-40K 토큰, 최소 5개 텍스트 블록)
  → 오래된 메시지를 세션 메모리로 대체

Tier 3: Full Compact (중량)
  → 전체 대화를 9섹션 구조화 요약으로 압축
  → 최근 읽은 파일 5개 복원 (50K 토큰 예산)
  → 스킬 프롬프트 재주입 (25K 토큰 예산)
```

**캐스케이드 순서가 핵심**: 싼 것부터 시도하여 비싼 Full Compact를 최대한 피함.

---

## 기법 1: Cache-Editing Microcompact

```
전통적 방식: 로컬 콘텐츠 수정 → 캐시 무효화 → 전체 재전송
Anthropic 방식: API에 cache_edits 전송 → 서버가 캐시 내 수정 → 캐시 유지
```

오래된 도구 결과를 `[Old tool result content cleared]`로 교체하되, 로컬 메시지를 건드리지 않고 서버 캐시만 편집. **캐시 미스 페널티 0.**

**컴팩트 가능 도구**: FileRead, Bash, Grep, Glob, WebSearch, WebFetch, FileEdit, FileWrite

---

## 기법 2: Deferred Tool Loading

```
모든 도구 스키마를 프롬프트에 넣으면: ~500-2000 토큰 × 40+ 도구 = 20K-80K 토큰
Deferred loading: 이름+힌트만 제공, 필요할 때 ToolSearch로 전체 스키마 로드
```

**절약**: MCP 사용자 기준 30-50% 컨텍스트 절약

```
항상 로드: ToolSearch(자기 자신), Agent(첫 턴 포크용), Brief(통신용)
디퍼드: 모든 MCP 도구, 워크플로우 도구
```

---

## 기법 3: 시스템 프롬프트 캐시 스코핑

```
Static (글로벌 캐시):
  │ 정체성 + 보안 + 시스템 메커니즘 + 작업 가이드 + 도구 라우팅
  │ scope: 'global' → 모든 유저/조직이 공유
  │
  ▼ ── SYSTEM_PROMPT_DYNAMIC_BOUNDARY ──
  │
Dynamic (세션별):
  │ CLAUDE.md + 환경 정보 + MCP 지시 + 스킬 목록
  │ scope: 'session' → 유저별 고유
```

**경제학**: 핵심 시스템 프롬프트(~10K 토큰)를 전체 fleet에서 1번만 캐시.

---

## 기법 4: 도구 결과 디스크 퍼시스턴스

```
결과 크기 > 50K chars → 디스크에 저장
모델에게는 2KB 프리뷰 + 파일 경로 전달
모델이 필요하면 FileRead로 재접근

절대 최대: 100K 토큰 / 400KB
메시지당 집계: 200K chars 상한 (10개 병렬 도구의 폭주 방지)
```

**빈 결과 처리**: `(toolName completed with no output)` — 빈 tool_result는 일부 모델에서 `\n\nHuman:` 중지 시퀀스를 유발하므로.

---

## 기법 5: Output 토큰 캡핑

```
기본 max_output_tokens: 8,000 (모델 한계 32K/64K가 아님)
이유: BQ p99 output이 4,911 토큰. 32K 예약은 4-6x 슬롯 낭비.

8K 히트 시: 1회 재시도 with 64K (escalation)
```

**1% 미만의 요청만 8K를 초과** → 99%에서 슬롯 효율 4-6x 향상.

---

## 기법 6: 메모리 디렉토리 시스템

```
4가지 메모리 타입: user, feedback, project, reference
MEMORY.md 인덱스: 200줄 AND 25KB 이중 상한
  (200줄 상한만으로는 p100에서 197KB 항목이 통과)

관련성 선택: Sonnet 사이드 쿼리 (256 토큰, JSON 출력)
  → 최대 5개 관련 메모리 선택
  → 이미 표면화된 메모리 제외
  → 최근 사용 도구도 전달 (중복 표면화 방지)

Staleness: 1일 이상 → 경고 첨부
  "This memory is N days old. Claims may be outdated."
```

---

## 기법 7: 토큰 예산 시스템

```
auto-continue: output이 예산의 90% 미만이면 자동 계속
diminishing returns: 3+ 계속 후, 연속 2회 delta < 500 토큰이면 중단

rough estimation: length / 4 (일반), length / 2 (JSON)
  → 25% 오차 → 4/3 패딩으로 보상
```

---

## 기법 8: 컴팩션 프롬프트 기법

### Analysis-then-Strip
```
<analysis>
[체계적 분석 수행 — 이 부분은 최종 출력에서 제거]
</analysis>

<summary>
[분석 결과만 남긴 고밀도 요약]
</summary>
```

### NO_TOOLS_PREAMBLE
```
"CRITICAL: Respond with TEXT ONLY. Do NOT call any tools."
(프롬프트 시작과 끝 양쪽에 배치)
이유: Sonnet 4.6+에서 maxTurns:1임에도 도구 호출 시도 → 텍스트 0 출력
     4.5에서 0.01% → 4.6에서 2.79% 실패율
```

---

## 컨텍스트 예산 계획 템플릿

```markdown
## Context Budget Plan

Total Window: [200K / 1M] tokens

### Fixed Costs (매 턴)
- System prompt (static): ~10K tokens
- System prompt (dynamic): ~[X]K tokens  
- Tool schemas: ~[X]K tokens (deferred하면 ~0)
- CLAUDE.md: ~[X]K tokens

### Variable Costs
- Conversation history: ~[X]K tokens
- Tool results (active): ~[X]K tokens
- Memory surfacing: ~[X]K tokens (max 5 × ~2K each)

### Available for Output
- max_output_tokens: 8K (escalation: 64K)

### Compaction Triggers
- Auto-compact: window - 13K buffer
- Warning: window - 20K buffer
- Circuit breaker: 3 consecutive failures → stop
```

---

## 실���

`$ARGUMENTS`에 대해:
1. 현재 컨텍스트 예산 파악
2. 3단계 캐스케이드 중 적용할 기법 선택
3. Deferred loading으로 도구 스키마 최적화
4. 캐시 스코핑으로 정적/동적 분리
5. 메모리 관련성 선택으로 필요한 것만 표면화
6. 결과물 산출
