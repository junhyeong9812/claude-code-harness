# task: 中 stakes 듀얼 리뷰 승격 + 대칭 부담 도입

> 날짜: 2026-06-29 · 대상: claude-code-harness (배포본 ~/.claude 동기 필요) · stakes: **높음**(리뷰 시스템 정책·메타 변경)
> 작업 모드: auto-implements

## §1 정의 (명확도 6칸)

| # | 칸 | 내용 |
|---|----|------|
| 1 | 목표·대상 | `claude-code-harness` — 中 stakes를 **듀얼 리뷰(1패스)** 로 승격하고 **대칭 부담(verified ledger)** 을 리뷰 종료에 도입. 끝 = core §5·review.md·review-log 템플릿이 「中=듀얼 1패스 / 高=듀얼+루프+설계선검증」으로 일관, 낮음·dimensions·§4 정의 불변, stale 참조 0 |
| 2 | 경계·불변식 | • **낮음** = 셀프체크 불변, 약/강 1-liner 개념 도입 안 함 • **中** = Opus∥codex 듀얼 1패스(①②③④, ⑤ 재리뷰 없음) + codex(계획·최종) + blind 테스트 워커 + 외부검색 의무 + 대칭부담(verified ≥4·양쪽 must). **설계 codex 선검증 없음** • **高** = 위 + 설계 codex 선검증(구현 전) + 반복 루프 max3 (불변) • **中→高 승격** = 기존 §4.1 트리거 그대로 • **보존** = §4.3 최소안전선·§4 낮/중/높 정의·dimensions.md·codex 보안스캔·git 승인경계·lazy-busy 모드 축 |
| 3 | 기준소스 | 현재 `core.md`·`playbooks/review.md`·`templates/*` 본문 + 이 대화 합의. 충돌 시 본문 정본 |
| 4 | 금지영역 | dimensions*.md(전부)·core §4 stakes 정의·낮음 처우·lazy-busy 모드 축·훅 로직(stakes 문자열 직접 참조 없을 시)·`docs/`·`archive/` 역사 기록 |
| 5 | 검증 방법 | grep 정합(中 처우 일관, "codex 1회"식 stale 0) · 시나리오 워크스루(pagination 변경→中→듀얼1패스 / 보안 변경→高→루프) · **codex 설계검증(구현 전) + 최종 검증 1회**(문서·정책 산출물 = 루프 비대상, core §5 단서) · ~/.claude 동기 |
| 6 | stakes | **높음** — 리뷰 시스템 자체를 바꾸는 메타 정책 변경. 단 다단계 아님(집중 편집) → task.md 1파일 |

### 트리아지 (dimensions.md 14차원 전수)

> 대상은 **마크다운 정책 문서**(core.md·review.md·템플릿) — 실행 코드·외부 입력·DB write 없음. 코드성 차원은 비활성. stakes는 §4 낯섦·메타(정책 변경, core §2 "하네스/정책 변경=높음")가 차원 하한(중간)을 넘어 **높음** 확정.

| # | 차원 | 판정 | 근거 (본 파일) |
|---|------|------|------|
| 2 | 입력 검증 | 비활성 | 외부 입력 경로 없음 — md 정책 텍스트만 (core.md·review.md) |
| 3 | 권한 경계 | 비활성 | 인증/인가 로직 없음 |
| 4 | 데이터 정합성 | 비활성 | DB/상태 write 없음. ~/.claude 동기는 파일 복사(운영 절차, §2 검증) |
| 5 | 동시성 | 비활성 | 동시 실행 리소스 없음 |
| 6 | 예외 처리 | 비활성 | 실패 가능 IO 없음 |
| 8 | 성능 | 비활성 | 쿼리/데이터량 특성 무관 |
| 9 | 장애 복구 | 비활성 | 외부 의존성 없음 |
| 10 | 운영 가능성 | **light** | review-log.md template-guard 마커 추가가 훅 경고 동작에 영향 — 마커 문자열 정합 확인 필요 |
| 11 | 보안 | 비활성 | 공격 표면 없음 |
| 12 | API 계약 | 비활성 | 외부 계약 무관 (내부 정책 계약은 #14에서) |
| 14 | 도메인 규칙 | **활성** | 이 변경의 도메인 = 하네스 리뷰 정책. 불변식: 中=Opus∥codex 쌍 수령 / 낮음 불변 / 高=루프·설계선검증 유지 / 대칭부담 ≥4·양쪽 must. 규칙이 core §5·review.md 두 곳에 일관해야 (단일 출처 = review.md, core는 포인터) |
| 15 | 데이터 모델링 | **light** | verified ledger 스키마(필드 4종) 신설 — review.md §2 ledger 스키마와 정합 필요 |
| 16 | 비용 | **활성** | 中을 듀얼 리뷰로 승격 → 모든 中 작업에 Opus 워커 추가, 토큰·시간 증가. 사용자 인지·수용(대화 합의)이나 차원상 활성 (중간) |
| 17 | 사용자/소비자 가시성 | **light** | 정책 사용자(본인)가 보는 리뷰 흐름이 바뀜 — 中 처우 변경 |

**light 상세**:
- **#10**: review-log template-guard 마커 / 확인할 증거 = `hooks/template-guard.sh`의 review-log 검사 마커 목록 / V = 마커 추가 후 훅 경고 안 뜨는지 점검 → §4 재판정.
- **#15**: verified ledger 필드 확정 여부 / 증거 = review.md §2 기존 ledger 스키마 / V = 두 스키마 충돌 없음 확인 → §4 재판정.
- **#17**: 가시 동작 = 정책 텍스트 / 비활성 전환 가능(내부 문서) / V = 시나리오 워크스루로 라우팅 일관 확인.

## §2 계획 (v2 — codex 설계검증 15지적 반영)

> codex 설계검증 결과 4개 결정이 v1에서 수정됨(원문: scratchpad/codex-design-out.md, 요지는 review-log):
> ① 대칭부담 `≥4 고정·양쪽 must` → **applicable 렌즈 판정 후 전부 verified**(고정수 X, 날조 방지) + 한쪽 0이면 비대칭 플래그(종료 가능) ② 中 `재리뷰 완전 없음` → **post-fix 타깃 재점검 1회**(수정 hunks+인접+새 테스트) ③ 中 외부검색 `의무` → **조건부 유지**(낯선 영역만) ④ 中 테스트 `blind 워커` → **spec-우선 같은 맥락 + 테스트 코드 자체 정합성 점검**(高의 blind 워커 대체).

### 변경 파일 (순서)
1. **core.md §5 표** — 리뷰 행 中 = "듀얼 1패스(①~④ + post-fix 타깃 재점검, 반복 없음)" / 高 = "中 + 반복 루프 max3". codex 행 中 = "듀얼 1패스 겸함, 설계 선검증 제외(高 전용)". 테스트 행 中 = "spec-우선 + 테스트 코드 정합성 점검". review-log 행 中 = "듀얼 1패스 시". 외부검색·산출물 행 불변.
2. **core.md §5 불릿** — "듀얼 리뷰 누락 금지" → 中·높음 둘 다. 신규 "대칭 부담" 불릿(applicable 전부 verified). "codex 호출 실패" → 中도 듀얼 의무(0회 종료 금지).
3. **playbooks/review.md** — 제목·트리거(낮음만 미열람, 中=1패스). §1에 中 변형(post-fix 재점검·종료조건·높음 승격 시 1회차 인정). §2 대칭 부담(applicable 판정 + verified ledger) + finding 근거 형식(diff-밖 허용) + source main-synthesis + finding 단위.
4. **templates/review-log.md** — 리뷰 형태(듀얼1패스 中), 종료조건(대칭부담), `## verified` 섹션, 리뷰 모드(中·높음 필수).
5. **hooks/template-guard.sh** — review-log 케이스에 `## verified` 마커 추가(#10 light).
6. **core.md 변경 이력** 1행.
7. **grep 정합 점검** → codex 최종(문서·정책 = 별도 최종 1회) → review-log → 측정 1행 → **~/.claude 동기**.

### 변경하지 않을 파일
dimensions*.md · core §4 · templates/task·phase·master-plan · playbooks/implementation(§0 설계 선검증이 이미 높음 한정인지 grep 확인만)·orchestration·verification · docs/ · archive/

### 검증 명령
- `grep -rn '중간\|codex 1회\|별도 패스 1회' core.md playbooks/review.md templates/review-log.md` → stale 처우 0 확인
- codex 최종 검증(편집 후) — read-only
- 시나리오 워크스루 2건: pagination 한 줄 변경(→中→듀얼1패스+post-fix) / 결제 로직(→高→루프)

## §3 진행 로그

- 정의·계획 확정 → **codex 설계검증(15지적, 4개 결정 반전)** → 편집(core·review·review-log·template-guard·README) → grep 정합(stale 1건=§7 트리거 발견·수정) → **codex 최종검증(7지적, 6개 수정 1개 기각)** → 기록 → ~/.claude 동기.
- 계획과 달라진 점: codex 설계검증으로 v1의 `≥4 고정·양쪽 must·외부검색 의무·blind 워커(中)`를 모두 교정(v2). 편집 중 core §7 review.md 로딩 트리거가 stale("중간은 루프 절차 로드 안 함")인 것을 grep이 잡아 수정.

## §4 검증 결과

- **최소 안전선 (core §4.3)**: 테스트=문서 정합 grep(stale 0) ✓ / diff self-review(167줄, 의도 외 변경 없음 — `.gitignore`는 기존 dirty라 커밋 제외) ✓ / rollback=git revert 가능 ✓ / contract=정책 계약(中 리뷰 처우) 일관 확인 ✓ / 반증 질문="다른 호출 경로?"→§7 트리거 stale 발견·수정 ✓
- **light 재판정** (트리아지 #10·#15·#17):
  - #10 운영성(template-guard 마커): **활성→충족** — review-log 케이스에 `## verified` 마커 추가, 템플릿에 섹션 존재 확인.
  - #15 데이터모델링(verified ledger 스키마): **활성→충족** — review.md §2 ledger와 verified 필드 정합(file:line·diff-밖 형식 일관).
  - #17 가시성: **비활성 전환** — 내부 정책 문서, 외부 소비자 없음. 시나리오 워크스루로 라우팅 일관 확인.
  - → 칸6 stakes 재산정: 여전히 **높음**(차원 하한 중간 + 메타·낯섦 = 높음 불변).
- **stakes 비례 검증 (core §5)**: codex 설계+최종 2회 수행, finding은 `review-log.md`에 기록. 결론: 7+15 지적 중 채택분 전부 반영, 잔여 리스크 없음.

## §5 기록

- 측정 1행 기입 □ (`docs/measurement-log.md`)
- **코드 구현 판정**: 문서-only(정책 마크다운) → 제품 산출물 4종(OVERVIEW·changelog·learned·TECHNICAL) **제외**(core §3.5). 5줄 요약:
  - 변경: core §5(中 듀얼1패스 승격·대칭부담 불릿)·§7 트리거 / review.md(제목·트리거·§1 中변형·§2 대칭부담) / review-log 템플릿(verified) / template-guard(마커) / README(표·히스토리24).
  - 검증: grep stale 0, codex 설계+최종 2회, 시나리오 2건.
  - 새로 안 것: dual-pool-review의 "symmetric burden"이 본 하네스의 빈틈(CLEAN 무근거 통과)을 메움. 단 ≥고정수는 날조 함정.
  - 지적받은 것: codex — 中≈高 붕괴 방지엔 "비싼 항목을 高에만" 분리가 정답. 고정 임계값은 날조 유발.
  - 반복 금지: 정책 변경 시 §7 트리거 표·교차참조 열거를 grep으로 전수 점검(전파 누락 = 2026-06-24와 동형 실패).
- **review-log 판정**: codex 교차검증 수행 → `review-log.md` 작성 ✓
