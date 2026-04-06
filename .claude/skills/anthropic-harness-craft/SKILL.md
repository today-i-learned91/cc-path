---
name: anthropic-harness-craft
description: "Anthropic 수준의 하네스/도구 설계 방법론 — buildTool() 팩토리, 권한 파이프라인, 훅 시스템, 스트리밍 실행기, MCP 통합"
whenToUse: "하네스 설계, 도구 만들기, tool design, harness, hook 설정, 권한 시스템 설계"
model: opus
---

# Anthropic Harness Craft

Claude Code의 Tool 시스템(792줄 인터페이스), Hook 시스템(4타입 16이벤트), 권한 파이프라인에서 추출한 하네스/도구 설계 방법론.

## 적용 대상: $ARGUMENTS

---

## 도구(Tool) 설계 패턴

### buildTool() 팩토리: Fail-Closed 디폴트

```typescript
const TOOL_DEFAULTS = {
  isEnabled: () => true,
  isConcurrencySafe: () => false,  // 증명될 때까지 직렬
  isReadOnly: () => false,          // 증명될 때까지 쓰기
  isDestructive: () => false,
  checkPermissions: () => ({ behavior: 'allow' })
}

// buildTool(myToolDef) → TOOL_DEFAULTS와 병합
```

**원칙**: 새 도구는 기본적으로 가장 안전한 상태. 안전성을 증명한 후에만 제약 완화.

### Tool 인터페이스 핵심 메서드

| 메서드 | 목적 | 디폴트 |
|--------|------|--------|
| `call()` | 핵심 실행 | (필수 구현) |
| `validateInput()` | 권한 전 검증 | pass |
| `checkPermissions()` | 도구별 권한 | allow → 일반 시스템에 위임 |
| `description()` | 모델에게 보여줄 설명 | (필수) |
| `prompt()` | 시스템 프롬프트 기여 | 없음 |
| `isReadOnly()` | 읽기 전용 선언 | false |
| `isConcurrencySafe()` | 병렬 안전 선언 | false |
| `isDestructive()` | 비가역적 선언 | false |
| `maxResultSizeChars` | 디스크 퍼시스턴스 임계 | 50K |

---

## 권한 파이프라인 설계

```
tool_use 블록 생성
  │
  ├─ validateInput()     ← 빠른 실패 (형식 검증)
  ├─ getDenyRuleForTool() ← 포괄 거부 (도구 전체 차단)
  ├─ checkPermissions()  ← 도구별 로직
  ├─ 권한 모드 해석       ← 7가지 모드
  ├─ 자동모드 분류기      ← LLM 기반 (feature-gated)
  │
  └─ 결과: allow | deny | ask | passthrough
```

### 권한 결과 처리

| 결과 | 처리 |
|------|------|
| `allow` | 즉시 실행 |
| `deny` | 거부 기록, 사용자 알림 |
| `ask` | 사용자 승인 요청 (모드에 따라) |
| `passthrough` | 항상 ask (MCP 도구 기본) |

### 거부 추적 회로 차단기
```
3회 연속 거부 OR 20회 총 거부 (auto 모드)
→ 직접 사용자에게 질문으로 폴백
```

---

## 훅(Hook) 시스템 설계

### 4가지 훅 타입

| 타입 | 실행 방식 | 용도 |
|------|----------|------|
| `command` | 셸 명령 실행 | 자동화, 린팅, 포매팅 |
| `prompt` | LLM 프롬프트 평가 | 자연어 규칙 적용 |
| `agent` | 서브에이전트 (도구 사용 가능) | 복잡한 검증 |
| `http` | HTTP POST | 외부 서비스 연동 |

### 16+ 훅 이벤트

```
생명주기:
  SessionStart → ... → SessionEnd (1.5초 타임아웃)

도구 실행:
  PreToolUse → [실행] → PostToolUse | PostToolUseFailure

권한:
  PermissionRequest → PermissionDenied

컨텍스트:
  PreCompact → PostCompact
  UserPromptSubmit
  FileChanged, ConfigChange, CwdChanged

태스크:
  TaskCreated → TaskCompleted

에이전트:
  SubagentStart → SubagentStop
  TeammateIdle
```

### PreToolUse 훅 결정

```json
{
  "permissionDecision": "allow|deny|ask",
  "updatedInput": { "...수정된 입력..." },
  "additionalContext": "대화에 주입할 컨텍스트"
}
```

### 훅 보안

- **워크스페이스 신뢰 필수** (SessionEnd 취약점 교훈)
- **관리 훅 정책**: `shouldAllowManagedHooksOnly()` 킬스위치
- **타임아웃**: 도구 훅 10분, SessionEnd 1.5초
- **`if` 필터**: `"Bash(git *)"` 패턴으로 불필요한 실행 방지
- **비동기 훅**: `{async: true}` 반환 시 백그라운드 실행

---

## 스트리밍 도구 실행기

```
StreamingToolExecutor:
  → tool_use 블록이 스트림에서 도착하는 즉시 실행 시작
  → 병렬 안전 도구: 동시 실행
  → 비안전 도구: 순차 실행
  → sibling abort: Bash 에러 시 형제 도구 프로세스 kill
```

### 동시성 분류

```
partitionToolCalls():
  concurrent-safe (읽기전용): Grep, Read, Glob → 병렬
  non-concurrent (쓰기): Bash, Edit, Write → 직렬
```

---

## MCP 도구 통합 패턴

```typescript
// MCP 도구 → Tool 객체 변환
{
  name: `mcp__${serverName}__${toolName}`,
  checkPermissions: () => ({ behavior: 'passthrough' }),
  isConcurrencySafe: tool.annotations.readOnlyHint,
  isDestructive: tool.annotations.destructiveHint,
  maxResultSizeChars: 100_000,
  // _meta['anthropic/searchHint'] → deferred loading 힌트
  // _meta['anthropic/alwaysLoad'] → deferred 면제
}
```

---

## 하네스 설계 체크리스트

```markdown
## 도구 설계
- [ ] Fail-Closed 디폴트 적용 (isConcurrencySafe=false 등)
- [ ] validateInput()으로 빠른 실패 구현
- [ ] checkPermissions()으로 도구별 권한 로직
- [ ] maxResultSizeChars 설정 (큰 결과 디스크 퍼시스턴스)
- [ ] prompt()으로 모델 가이드 제공

## 훅 설계
- [ ] 적절한 이벤트 선택 (PreToolUse vs PostToolUse)
- [ ] if 필터로 불필요한 실행 방지
- [ ] 타임아웃 설정
- [ ] 비동기 여부 결정

## 보안
- [ ] 경로 검증 (TOCTOU 방어)
- [ ] 명령 주입 방지
- [ ] 파괴적 작업 경고
```

---

## 실행

`$ARGUMENTS`에 대해:
1. 도구/하네스 목적 정의
2. Fail-Closed 디폴트 기반 설계
3. 권한 파이프라인 설계
4. 훅 이벤트 및 타입 결정
5. 동시성 분류
6. 보안 체크리스트 적용
