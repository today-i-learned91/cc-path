---
name: anthropic-architecture
description: "Anthropic 수준의 소프트웨어 설계 방법론 — 7계층 아키텍처, 6가지 디자인 패턴, Fail-Closed 디폴트, 3벡터 확장성, 35줄 스토어 철학"
whenToUse: "설계, 아키텍처, 구조, 리팩토링, 모듈화, architecture, design, refactoring, 시스템 설계"
model: opus
---

# Anthropic Architecture

Claude Code 1905파일 아키텍처에서 추출한 소프트웨어 설계 방법론.

## 적용 대상: $ARGUMENTS

---

## 원칙 1: 7계층 파이프라인 아키텍처

```
Layer 0 — Entrypoints & Bootstrap (진입점, 최소 임포트)
Layer 1 — Core Domain Types (Tool, Task — "spine")  
Layer 2 — Query Pipeline (brain — 데이터 처리 중심)
Layer 3 — Tools & Tasks (hands — 실행)
Layer 4 — Commands & Skills (voice — 사용자 인터페이스)
Layer 5 — UI & Rendering (face — 표현)
Layer 6 — Services & Infrastructure (nervous system)
Layer 7 — Extensions & Integrations (plugins, MCP)
```

**의존성은 아래로만 흐른다.** Layer 5(UI)가 Layer 2(Query)를 직접 호출하지 않음.

---

## 원칙 2: 설계 패턴 선택 기준

| 패턴 | 언제 사용 | Claude Code 예시 |
|------|---------|-----------------|
| **Builder/Factory** | 안전한 디폴트가 필요할 때 | `buildTool()` — fail-closed 디폴트 적용 |
| **Strategy** | 같은 인터페이스, 다른 구현 | 40+ Tool 구현체 |
| **Observer** | 상태 변경 구독 | 35줄 micro-store |
| **Command** | 데이터로서의 실행 | Command 레지스트리 |
| **Mediator** | 모듈 간 통신 중재 | query.ts — 도구, API, 권한 중재 |
| **Template Method** | 공통 골격 + 개별 구현 | Tool 인터페이스의 30+ 메서드 |

---

## 원칙 3: Fail-Closed 디폴트

```typescript
const TOOL_DEFAULTS = {
  isEnabled: () => true,
  isConcurrencySafe: () => false,  // 안전하다고 증명되기 전까지 직렬
  isReadOnly: () => false,          // 읽기전용이라고 증명되기 전까지 쓰기 취급
  isDestructive: () => false,
  checkPermissions: () => ({ behavior: 'allow' })  // 일반 권한 시스템에 위임
}
```

**"알 수 없는 것은 위험한 것으로 간주한다."**

---

## 원칙 4: 최소 복잡성 상태 관리

Claude Code의 상태 관리는 Redux가 아닌 **35줄 pub/sub store**:

```typescript
function createStore<T>(initialState: T) {
  let state = initialState
  const listeners = new Set<() => void>()
  return {
    getState: () => state,
    setState: (updater: (prev: T) => T) => {
      state = updater(state)
      listeners.forEach(fn => fn())
    },
    subscribe: (fn: () => void) => {
      listeners.add(fn)
      return () => listeners.delete(fn)
    }
  }
}
```

**원칙**: "필요한 만큼의 복잡성. 미래 요구사항을 위한 추측적 추상화 금지."

---

## 원칙 5: 3벡터 확장 아키텍처

| 벡터 | 구조 | 발견 | 호출 |
|------|------|------|------|
| **Skills** | Markdown + frontmatter | 파일시스템 스캔 | SkillTool |
| **Plugins** | Manifest + hooks + skills | 레지스트리/마켓 | 설정 토글 |
| **MCP** | Server + tools | 네트워크 프로토콜 | MCPTool |

**우선순위**: bundled > builtinPlugin > skillDir > workflow > plugin > mcp

---

## 원칙 6: Import Cycle 방지는 아키텍처 관심사

```typescript
// types/permissions.ts exists specifically to break import cycles
// — Tool.ts:42-47 주석

// coordinator/coordinatorMode.ts duplicates a gate check
// rather than importing utils/permissions/filesystem.ts 
// because it would create a cycle
```

**기법:**
- `types/` 디렉토리로 공유 타입 추출
- 지연 `require()`로 조건부 로딩
- 레지스트리 패턴으로 순환 끊기

---

## 원칙 7: 캐시 안정적 정렬

```typescript
// Built-in tools are a contiguous sorted prefix
// MCP tools are a separate sorted suffix
// uniqBy('name') ensures built-ins win on name conflict
```

**도구 풀의 정렬은 프롬프트 캐시 경제학을 위해 결정적이어야 한다.**

---

## 원칙 8: Feature Flag Dead Code Elimination

```typescript
const cronTools = feature('AGENT_TRIGGERS')
  ? [require('./CronCreateTool').CronCreateTool]
  : []
```

빌드 타임에 `feature()` 평가 → 데드 브랜치 트리셰이킹. 
동일 코드베이스에서 내부/외부 빌드 분리의 핵심 메커니즘.

---

## 디렉토리 구조 설계 원칙

### 디렉토리를 만드는 기준
파일이 자체 디렉토리를 가져야 하는 경우:
1. UI 컴포넌트(`UI.tsx`)가 로직과 분리될 때
2. 시스템 프롬프트(`prompt.ts`)가 구현과 분리될 때
3. 3개 이상의 헬퍼 파일이 필요할 때

### 네이밍 컨벤션
| 컨벤션 | 의미 | 예시 |
|--------|------|------|
| PascalCase | 클래스/컴포넌트/주요 모듈 | `BashTool.tsx` |
| camelCase | 유틸/서비스/헬퍼 | `bashPermissions.ts` |
| kebab-case | 슬래시 커맨드 디렉토리 | `add-dir/` |
| SCREAMING_SNAKE | 모듈 상수 | `TOOL_DEFAULTS` |

### 루트 파일 vs 서브디렉토리
루트에 남는 파일 = 아키텍처의 "척추". 거의 모든 모듈에서 임포트됨:
- `Tool.ts`, `Task.ts` — 핵심 인터페이스
- `tools.ts`, `tasks.ts` — 레지스트리
- `query.ts`, `QueryEngine.ts` — 파이프라인
- `commands.ts` — 커맨드 허브

---

## AsyncGenerator 파이프라인 패턴

Claude Code의 전체 데이터 흐름은 `AsyncGenerator<StreamEvent | Message>`:

```
QueryEngine.submitMessage()  → yield*
  query() / queryLoop()      → yield*
    queryModelWithStreaming() → yield StreamEvent
```

**장점**: 스트리밍, 백프레셔, 에러 전파, 동일 파이프라인으로 REPL/SDK/Remote 지원
**단점**: 디버깅 어려움, 스택 트레이스가 제너레이터를 넘나듦

---

## 실행

`$ARGUMENTS`에 대해:
1. 현재 구조 파악 (Layer 식별)
2. 의존성 방향 확인 (아래로만)
3. Fail-Closed 디폴트 적용
4. 최소 복잡성으로 상태 관리
5. 확장 벡터 식별 (Skills/Plugins/MCP)
6. Import cycle 방지 전략 수립
7. Feature flag으로 변형 관리
