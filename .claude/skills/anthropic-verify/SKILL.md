---
name: anthropic-verify
description: "Anthropic 수준의 테스팅/검증 방법론 — 23개 보안 체크, 7단계 권한 모드, 적대적 독립 검증, Defense-in-Depth, TOCTOU 방어"
whenToUse: "테스트, 검증, QA, 보안 리뷰, 안전성 검증, testing, verification, security review"
model: opus
---

# Anthropic Verify

Claude Code의 권한 시스템(7모드), Bash 보안(23체크), 파일 경로 검증, 자동 분류기에서 추출한 테스팅/검증 방법론.

## 적용 대상: $ARGUMENTS

---

## 원칙 1: 독립 적대적 검증

```
"Independent adversarial verification must happen before you report completion.
 Your own checks do NOT substitute — only the verifier assigns a verdict."
```

작성자와 검증자는 반드시 다른 패스여야 한다. 같은 컨텍스트에서 자기 승인 금지.

---

## 원칙 2: Fail-Closed Security (6대 원칙)

### P1: Fail Closed, Default Deny
- 알 수 없는 경로 → 차단 (허용 아님)
- 분류기 불가용 → 사용자에게 질문 (자동 허용 아님)
- `isConcurrencySafe: false` — 안전하다고 증명될 때까지 직렬
- `isReadOnly: false` — 읽기전용이라고 증명될 때까지 쓰기 취급

### P2: TOCTOU 방어
- 셸 확장 구문(`$VAR`, `~root`)은 경로에서 거부
- 대소문자 정규화로 파일시스템 의존적 우회 방지
- symlink 해소 후 원본+해소 경로 모두 체크

### P3: Defense in Depth
- 권한 규칙 + 분류기 + 훅 + 샌드박스 + 경로검증 + 명령 파싱 (독립 레이어)
- Zsh 모듈 시스템 전체 차단 + 개별 빌트인도 차단 (이중)
- PowerShell 주석 구문도 bash에서 차단 (크로스 셸 방어)

### P4: Informed Consent
- 파괴적 명령 경고는 정보 제공 (차단 아님) — 사용자 자율성 존중
- 권한 프롬프트에 "왜 승인이 필요한지" 구체적 규칙 인용

### P5: Enterprise Controllability
- 관리 설정이 사용자 설정을 오버라이드
- 훅 전체 킬스위치 제공
- 네트워크 도메인 관리 정책

### P6: Minimal Trust Surface
- 훅은 워크스페이스 신뢰 필수 (SessionEnd 취약점 교훈)
- 자동모드 분류기는 어시스턴트 텍스트를 트랜스크립트에서 제외
- WebFetch 승인 도메인은 샌드박스에 상속 안 됨

---

## 검증 패턴: 권한 파이프라인

```
모델이 tool_use 블록 생성
  → validateInput() — 빠른 실패 검증
  → getDenyRuleForTool() — 포괄 거부 확인
  → checkPermissions() — 도구별 권한 로직
  → 권한 모드 해석 (7가지)
  → 자동모드 분류기 (feature-gated)
  → 결과: allow / deny / ask
```

### 7가지 권한 모드

| 모드 | 동작 | 위험도 |
|------|------|--------|
| `default` | 모든 도구 사용 시 명시적 승인 요구 | 안전 |
| `plan` | 쓰기 작업 차단 (읽기 전용) | 안전 |
| `acceptEdits` | CWD 내 파일 쓰기 자동 승인 | 중간 |
| `dontAsk` | 모든 "ask"를 "deny"로 변환 | 안전 (제한적) |
| `auto` | LLM 분류기가 안전성 평가 | 중간+ |
| `bypassPermissions` | 모든 권한 체크 건너뜀 (빨간 경고) | 위험 |
| `bubble` | 내부/앤트로픽 전용 | 특수 |

---

## 검증 패턴: 회로 차단기

```typescript
MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3
// 3회 연속 실패 → 전략 중단
// 일일 ~250K API 호출 낭비 방지를 위해 도입

DENIAL_CIRCUIT_BREAKER = { consecutive: 3, total: 20 }  
// 3회 연속 또는 20회 총 거부 → 사용자에게 직접 질문으로 폴백
```

---

## 검증 패턴: Git 안전

```
감지 대상:
- git commit, push, cherry-pick, merge, rebase
- gh pr create/edit/merge/comment/close
- --amend 플래그 별도 추적
- curl POST to PR 엔드포인트까지 감지

경고 트리거:
- reset --hard, push --force, clean -f
- checkout ., stash drop/clear, branch -D
- --no-verify (훅 건너뛰기)
- DROP TABLE, TRUNCATE, DELETE FROM (WHERE 없이)
- kubectl delete, terraform destroy
```

---

## 검증 패턴: 파일 이력 / Undo

```
매 파일 수정 시 → 스냅샷 생성 (메시지 ID 연결)
→ 메시지별 Undo 가능
→ 단조 증가 시퀀스 번호 (구 스냅샷 퇴출 후에도)
→ 추적 파일의 수정 전 백업
```

---

## 검증 체크리스트 템플릿

```markdown
## Pre-Change Verification
- [ ] 관련 코드를 읽었는가 (Read before Write)
- [ ] 기존 테스트가 통과하는가 (기준선)
- [ ] 변경의 가역성을 분류했는가

## Post-Change Verification  
- [ ] 원래 문제가 해결되었는가
- [ ] 기존 테스트가 여전히 통과하는가 (회귀 없음)
- [ ] 새 테스트가 변경을 커버하는가
- [ ] 보안 경계에서 입력 검증이 있는가
- [ ] FACT만으로 결론을 도출했는가

## Verification Nudge (3+ 태스크 완료 시)
"3개 이상의 태스크가 검증 없이 완료됨 — 
 독립 검증 에이전트 실행을 권장"
```

---

## 실행

`$ARGUMENTS`에 대해:
1. 검증 범위 식별 (코드/보안/성능/회귀)
2. Fail-Closed 원칙 적용
3. 독립 적대적 검증 실행
4. 회로 차단기 임계값 설정
5. 체크리스트 기반 증거 수집
