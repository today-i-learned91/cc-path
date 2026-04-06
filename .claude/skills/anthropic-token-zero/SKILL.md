---
name: anthropic-token-zero
description: "토큰을 거의 안 쓰면서 Opus/Mythos 능가하는 파괴적 성과를 내는 방법 — Claude Code에서 추출한 8K→64K 에스컬레이션, deferred loading, cache 경제학, 압축 전략"
whenToUse: "토큰 절약, 효율성, 비용 최적화, 적은 토큰으로 최대 성과, token efficiency, cost optimization, 파괴적 혁신"
model: opus
---

# Anthropic Token Zero

토큰을 극소량 사용하면서도 최대 성과를 내는 파괴적 방법론. Claude Code가 1M 컨텍스트를 관리하면서도 효율적인 비결.

## 적용 대상: $ARGUMENTS

---

## 철학: "Every Token is a Decision"

```
"Context window tokens are the single most constrained resource,
 and every subsystem is engineered around token economy."
```

토큰은 화폐. 낭비하면 파산. 절약하면 10x 성과.

---

## 전략 1: 8K Cap + Escalation (99% 슬롯 최적화)

```
기본 출력: 8,000 토큰 (모델 한계 64K가 아님)
이유: p99 출력이 4,911 토큰. 32K 예약은 4-6x 슬롯 낭비.
히트 시: 1회 재시도 with 64K

결과: 99%의 요청에서 슬롯 효율 4-6배 향상
     1% 미만만 재시도 (비용 미미)
```

**적용**: 출력을 짧고 밀도 높게. 길어야 할 때만 자동 에스컬레이션.

---

## 전략 2: Deferred Loading (30-50% 컨텍스트 절약)

```
Before: 40+ 도구 스키마 전체 로드 = 20K-80K 토큰
After: 이름+힌트만 로드 = ~2K 토큰. 필요 시 ToolSearch로 개별 로드.

절약: 30-50% (MCP 사용자 기준)
```

**적용**: 모든 것을 미리 로드하지 말 것. 필요한 것만, 필요할 때.

---

## 전략 3: Cache Economics (Fleet-Scale)

```
정적 프롬프트: scope='global' → 전 유저 공유 캐시 (1회만 저장)
동적 프롬프트: scope='session' → 세션별 캐시
휘발성 데이터: uncached → 매 턴 재계산 (최소화)

에이전트 리스트 외부화: fleet cache_creation 토큰의 10.2% 절약
```

**적용**: 변하지 않는 것은 캐시. 자주 변하는 것만 재계산. 한 글자도 캐시 무효화를 최소화.

---

## 전략 4: Persist > Truncate > Compress

```
큰 도구 결과 (>50K chars):
  → 디스크에 저장 + 2KB 프리뷰만 컨텍스트에
  → 모델이 필요하면 FileRead로 재접근 (온디맨드)
  → 정보 손실 0, 컨텍스트 비용 2KB만

빈 결과:
  → "(tool completed with no output)" 대체
  → 빈 tool_result가 stop sequence 유발하는 버그 방지
```

---

## 전략 5: 3단계 캐스케이드 컴팩션

```
Tier 1 (무료): Cache-editing microcompact
  → 서버 캐시만 편집, 로컬 무변경, 캐시 미스 0

Tier 2 (경량): Session memory compact
  → 최근 10K-40K 보존, 나머지 세션 메모리로 대체

Tier 3 (중량): Full compact — 최후 수단
  → 9섹션 요약 + 최근 파일 5개 복원

순서가 핵심: 싼 것부터. Tier 3 도달을 최대한 지연.
```

---

## 전략 6: Rough Estimation (Zero-Cost Counting)

```
정확한 토큰 카운트: API 호출 필요 (비용 + 지연)
러프 추정: length / 4 (일반) 또는 length / 2 (JSON)
  → 25% 오차 → 4/3 패딩으로 보상
  → API 호출 0, 지연 0

결과: 매 반복에서 토큰 체크 가능 (비용 0)
```

---

## 전략 7: Memory Relevance Selection (Sonnet으로 256토큰)

```
전체 메모리 스캔: 비용 폭발
Anthropic 방식: Sonnet 사이드 쿼리 (256 토큰 예산)
  → 메모리 매니페스트에서 최대 5개 선택
  → 이미 표면화된 것 제외 → 중복 0
  → 턴당 1회만 실행 (반복 아님)

비용: ~256 토큰/턴. 효과: 관련 컨텍스트만 정확히 주입.
```

---

## 전략 8: Analysis-then-Strip (품질↑ 토큰↓)

```
<analysis>
[여기서 깊은 분석 수행 — CoT로 품질 향상]
[이 부분은 최종 출력에서 완전히 제거됨]
</analysis>

<summary>
[분석 결과만 남김 — 고밀도, 최소 토큰]
</summary>
```

**CoT의 품질 향상 효과는 취하되, CoT 자체의 토큰 비용은 제거.**

---

## 전략 9: Diminishing Returns Detection

```
auto-continue: 예산의 90% 미달 시 자동 계속
BUT: 3+ 계속 후 연속 2회 delta < 500 토큰
  → 자동 중단 (더 이상 의미 있는 출력 없음)

결과: 불필요한 continuation 토큰 0
```

---

## 전략 10: Numeric Length Anchors (1.2% 출력 절감)

```
"<=25 words between tool calls. <=100 words final responses."
→ 정량적 앵커가 "be concise"보다 1.2% 효과적
→ 전체 fleet에서 연간 수십만 달러 절약
```

---

## 파괴적 성과를 위한 메타 전략

### "Never Delegate Understanding"
```
토큰 낭비의 최대 원인: 모호한 위임 → 에이전트가 잘못된 방향으로 수천 토큰 소비
해결: 직접 이해한 후, 구체적 스펙(파일:라인)으로 위임
결과: 에이전트의 첫 시도 성공률 극대화 → 재시도 토큰 0
```

### "Cheapest-First Gate Sequence"
```
비싼 작업 전에 반드시 싼 게이트를 먼저:
  1. 이미 아는 것 확인 (0 토큰)
  2. 캐시/메모리 확인 (저 토큰)
  3. 파일 읽기 (중 토큰)
  4. API 호출/웹 검색 (고 토큰)
```

### "Parallel Independent, Serial Dependent"
```
독립 작업 3개 × 직렬 = 3x 턴 = 3x 시스템 프롬프트 비용
독립 작업 3개 × 병렬 = 1x 턴 = 1x 시스템 프롬프트 비용
결과: 시스템 프롬프트 반복 비용 1/3
```

### "Circuit Breaker, Not Infinite Retry"
```
3회 연속 실패 → 전략 재평가 (재시도 토큰 절약)
"1,279 sessions had 50+ consecutive failures, 
 wasting ~250K API calls/day globally"
→ 회로 차단기 도입 후 일일 250K 호출 절약
```

---

## Token Zero Checklist

```markdown
- [ ] 출력 cap 설정 (8K 기본, 필요시 escalation)
- [ ] Deferred loading 적용 (필요한 것만 로드)
- [ ] 캐시 스코핑 (정적/동적 분리)
- [ ] 큰 결과는 디스크 persist + 프리뷰
- [ ] 컴팩션 캐스케이드 (싼 것부터)
- [ ] Analysis-then-Strip (CoT 품질 + 토큰 절약)
- [ ] Diminishing returns detection (불필요 continuation 차단)
- [ ] Never Delegate Understanding (재시도 0)
- [ ] Cheapest-First Gates (비싼 작업 지연)
- [ ] 병렬화 (시스템 프롬프트 반복 최소화)
```

---

## 실행

`$ARGUMENTS`에 대해:
1. 현재 토큰 사용 패턴 진단
2. 가장 큰 낭비 지점 식별
3. 10가지 전략 중 적용 가능한 것 선택
4. 파괴적 성과를 위한 메타 전략 적용
5. Token Zero Checklist로 검증
