# OVERVIEW: write(필사) 핸드오프 축 — 작업 모드 4분기

> 추상 진입점. 무엇을·어떤 순서/분기로 도는가를 잡고 아래 3문서로 딥다이브한다.

## 주요 포인트

- **작업 모드를 2축 4분기로 확장한다** — 구현 게이트 축(auto/lazy) × 핸드오프 축(implements/write). 핵심은 **`write`를 직교 접미사**로 분리해 auto/lazy 어느 쪽에도 붙인 것. → 선택 이유 `changelog J-1`
- **per-diff 게이트는 `auto-`/`lazy-` 접두사로만 결정한다** — `write` 접미사는 per-tool 훅 동작을 안 바꾼다(필사는 기록 *이후* 핸드오프). 위험 키워드: 접두사 분류 vs fail-closed 열거. → 메커니즘 `TECHNICAL §게이트 분류`
- **`write`는 단순 접미사가 아니라 생명주기(impl→await→verify)를 갖는다** — `WRITE_PHASE` 상태로 표현. 까다로운 곳: 컨텍스트 요약 후 "이미 롤백했는지" 복구. → 메커니즘 `TECHNICAL §WRITE_PHASE 생명주기`
- **gate-guard가 await/verify에서 Claude의 코드 수정을 차단한다**(teeth) — 사용자가 타이핑·검증은 지적만. 위험: 차단 분기 순서(핸드오프 블록이 접두사 분류보다 먼저). → 메커니즘 `TECHNICAL §차단 우선순위`
- **`writing.md`가 필사 정답의 단일 출처**다 — 별도 패치·정답 파일 금지. 롤백은 코드/테스트만(docs 보존), git-guard가 안 막으니 절차로 안전 보장. → 선택 이유 `changelog J-4`·`J-5`

## 워크플로우 (절차 + 분기)

```
정의됨 진입 (task.md 생성)
  │  task-mode-guard: MODE=UNSET 리셋 → gate-guard가 산출물 변경 차단
  ▼
모드 선택 (2축 4분기) ──┬─ auto-implements ─▶ 자율 구현 ─────────────────────────▶ (끝)
                        ├─ lazy-implements ─▶ 매 diff 이해 게이트 구현 ───────────▶ (끝)
                        ├─ auto-write ───┐
                        └─ lazy-write ───┤  구현(접두사대로) + 검증 + 기록 산출물
                                         ▼
                            [WRITE_PHASE=impl] 완료
                                         │  writing.md 작성(정답 단일출처)
                                         ▼
                            코드/테스트 롤백 (docs·writing.md 보존)
                                         │  롤백 검증: git diff 코드=빈/ docs=남음
                                         ▼
                            [WRITE_PHASE=await] ◀── gate-guard: Claude 코드수정 차단
                                         │  사용자가 writing.md 보고 직접 필사
                                         ▼ (사용자 "완료")
                            [WRITE_PHASE=verify] ◀── gate-guard: Claude 코드수정 차단
                                         │  필사본 ↔ writing.md 대조 + 테스트
                                  지적만(file:line) ──▶ 사용자 수정 ──▶ 재검증
                                         ▼ (통과)
                            [WRITE_PHASE=done] ─▶ 필사본이 코드 커밋 (구현은 미커밋)
```

> per-diff 게이트(lazy 계열)·차단 분기의 *왜*는 TECHNICAL. resume 시 reinject가 매 턴 WRITE_PHASE를 복구한다.

## 딥다이브 인덱스

| 알고 싶은 것 | 문서·절 |
|---|---|
| 왜 그렇게 동작하나 (접두사 분류·WRITE_PHASE·차단 우선순위·실패모드) | TECHNICAL |
| 이번에 왜 그렇게 바꿨나 (4분기 분리·롤백 안전·단일출처) | changelog (J ID) |
| 무슨 요소를 어떻게 썼나 (bash case·hook stdin·sed 상태쓰기) | learned |
| 리뷰에서 무엇이 지적되고 해소됐나 (codex 10+α) | review-log |
