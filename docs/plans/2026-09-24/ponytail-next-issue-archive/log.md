# log — ponytail-next-issue-archive

## 타임라인

| 시각 | 사건 | 결과/결정 |
|------|------|----------|
| 2026-09-24 | 리서치(8개 도구) → 하네스 영향 질의 → 전수 인터뷰(A1~A8·B1~B7) | 전부 권장안, B2 사용자 수정(파일·라인 비노출 → 2차: 출처 대신 추상화 코드로 구조 직접 표현, 규칙 변경·기존 카드 적용) |
| 2026-09-24 | spec 작성·사용자 "둘 다 합의" | set-state spec-approved + mode auto 기록(TASK_PATH=이 폴더). study-note 명세는 scratchpad 초안으로 사전 합의 — 하네스 완료 후 study-note repo에 Write(리셋)→동일 합의로 set-state |
| 2026-09-24 | Ponytail 원문 clone(e3ba2aa) 정독 — SKILL.md·AGENTS.md·ponytail-review | 이식 대상: 사다리 7단·근본원인 수정·Rules·Not-lazy·check 1개 / 제외: Output·Intensity·Persistence·hooks |
| 2026-09-24 | 브랜치 `feat/ponytail-next-issue-archive` 생성(base 1754f16) | — |
| 2026-09-24 | study-note task02(추출) 선행 — Opus 워커 W1~W7 백그라운드(읽기 전용, 산출=scratchpad/extract/W*.md) | 하네스 작업과 파일 비중첩 |
| 2026-09-24 00:40 | task01·02 구현 — core §4 사다리·강도표 선검증 조건화·§7 사이클 마감 2단·§8 등재·변경이력 / review.md 선검증 문구·과잉 구현 렌즈 / issue-archive.md(40줄)·templates/next.md(34줄) / README 트리·HISTORY 행 | core 129→134줄(순증 5 ≤10). spec A5는 B2 확정에 맞춰 "사례 줄 append 없음"으로 정정 |
| 2026-09-24 00:48 | 검증: `bash hooks/tests/run.sh` → `258 passed, 0 failed` / `deploy.sh --dry-run` manifest diff = core·HISTORY·review.md 변경 + playbooks/issue-archive.md·templates/next.md 신규(디렉토리 단위 자동 포함) | load-bearing 가정 2 실증. 가정 1(사다리↔기존 §4 개발 자세 무모순) 정독 확인 |
| 2026-09-24 00:50 | 커밋 850f014(정책)·1697f1f(docs) — 브랜치 feat/ponytail-next-issue-archive | — |
| 2026-09-24 00:52 | loop1 packet: base 1754f16 / OUT=/tmp/tmp.eMwWJznqgr / mirror=/tmp/tmp.Th5keGzLhQ / untracked 0건 / 보안 스캔 매칭 = 테스트 픽스처 가짜 토큰·예제 코드뿐(오탐) → 통과 | — |
| 2026-09-24 00:55 | codex loop1 실패: `ERROR: You've hit your usage limit ... try again at 2:55 AM` / Opus 리뷰어 실행 실패: 동시 서브에이전트 20 상한(추출 워커 W1~W7의 하위 에이전트 포함) | review.md §1① 실패 분기 — codex 재시도 불가(한도). **대체 독립 리뷰어 = Fable 워커(다른 모델)** 로 같은 packet 진행, 슬롯 확보 후 Opus ∥ Fable. 사용자 보고 |
| 2026-09-24 01:20 | loop1 리뷰 회수: Opus(F1~F9 + OQ2) ∥ Fable 대체(F1~F6 + OQ4) — 미회수 0 | 메인 종합 → R1~R8 채택(공통 5·단독 3), OQ 5건 반영, 기각 0 |
| 2026-09-24 01:30 | loop1 수정: core §4 사다리 ①극성·⑤보안 예외·근본원인↔계획외 우선·ponytail 주석 repo 관례·강도표 선검증 판정기준+생략 기록·§7 마감 시점(병합 후·DEBT=0 후)·NEXT 신호기반+착수=새 spec / review.md 렌즈 비적용 항목 참조+shrink open question / next.md 가설 허용 삭제 / issue-archive 보류 기록·미패치 보안 제외·공개 안전선 절·브랜치·노출 스캔·push 제시 | run.sh `258 passed, 0 failed`, core 134줄(순증 5 유지), playbook 43줄 |
| 2026-09-24 01:35 | ③ 종합 감사: codex 한도 소진으로 미실행 — loop2 재리뷰(Opus ∥ Fable)가 loop1 판정 교차 확인으로 대체 | 한계 기록(감사≠독립 리뷰). loop3는 codex 복귀 시 codex 포함 |
| 2026-09-24 01:40 | loop2 packet: OUT=/tmp/tmp.lRQvq0yxnC / mirror=/tmp/tmp.FF9Gqrp4DX (+_packet/loop1-fix-diff.md) → Opus(A~C + OQ3) ∥ Fable(F1~F9 + OQ6) 회수 | 신규 채택 11 (P1 1: NEXT.md가 packet·미러로 새는 절단 계약 우회) |
| 2026-09-24 02:10 | W7·W8 추출 워커 + W8 하위 2개: 세션 레이트 리밋(429, resets 02:50)으로 중단 | 02:51 리셋 후 SendMessage로 재개(중간 산출 W7-parts·W8_g0~2 보존) |
| 2026-09-24 02:50 | loop2 수정: review.md EXCLP·case 가드·⓪ 서술에 NEXT.md 제외 / 렌즈 비적용 목록 재열거 삭제(정본 참조) / core 사다리 '삭제>추가' 범위·실패 가시화·명시 요청=spec 합의 포함 / 선검증 생략 기록을 ② 항목별 file:line로 / 설계 문서 분기 조건 동일 명시 / 마감 시점 = 검증 후·병합 전 작업 브랜치 docs 커밋 / NEXT ≤80줄·병합 상태 행 / issue-archive 게이트 L1 주의·보안 출처 무관·guide 하한 조항·ff 실패 처리·노출 스캔 오탐 판정 | run.sh `258 passed, 0 failed` · review.md mkpacket 블록 `bash -n` syntax-ok(placeholder 치환) · core 134줄 |
| 2026-09-24 02:55 | loop3 packet: OUT=/tmp/tmp.vDzsz0azuy / mirror=/tmp/tmp.0Aoreiprdp → Opus(R1~R6 + OQ2) 회수 / codex(미러 cwd): `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`로 파일 읽기 불가 → review blocked 응답 | bypass 플래그는 사용자 승인 사항이라 미사용 — 동일 입력을 stdin 인라인(spec+누적 diff+전문 4개, 100KB)으로 재실행(loop3 수정 반영 상태) |
| 2026-09-24 03:05 | loop3 수정(Opus R1~R6·OQ) → codex 인라인 리뷰 F1(P1: study-note 쓰기 '금지영역 판정 대상 아님'이 spec 금지영역·재합의 무력화 — 내 loop3 수정이 도입)·F2(병합 뒤 검증 결과 main docs 커밋 = §6 충돌) → 수정 | **3루프 상한 도달** — review.md §1 종료조건 미충족(loop3 신규 채택 8) → `review unresolved`. post-fix 타깃 재점검(codex 인라인) PF-01 1건(노출 스캔이 제거 커밋의 삭제 행을 잡아 교착) → 수정. run.sh `258 passed, 0 failed` |
| 2026-09-24 03:15 | 사용자 결정 "리뷰 1회 더" → loop4 packet: OUT=/tmp/tmp.CnbHPoEbFi / mirror=/tmp/tmp.wxtO6T9aqy → codex 인라인(R4-01 P1 SPEC=1≠승인 범위 · R4-02 NEXT 상한이 미해소 보류 삭제) ∥ Opus(R1 P3 긴급 DEBT 이월 시 아카이브 무음 누락 + OQ3) | 채택 3 + OQ 1(선검증=동작 불변식 한정) → 보류 사유 5종 단일 경로 통합 |
| 2026-09-24 03:25 | loop4 post-fix 재점검(codex 인라인) PF-01(DEBT 이월 보류 기록 시점 부재)·PF-02(범위 제약에 file:line 증빙 요구=날조 유발) → 수정 | run.sh `258 passed, 0 failed` |
| 2026-09-24 03:35 | 사용자 "병합·push·배포" → main ff 병합(1754f16..97aab55) → push `9b828a2..97aab55 main -> main`(git-guard ask 승인; 이전 세션 미push 1754f16 포함 — 사용자에게 고지) → `deploy.sh`: `smoke 검증 통과`·`배포 완료 (diff 0 검증)` | — |
| 2026-09-24 03:40 | 신규 세션 스모크: `claude -p --model haiku` → "필요성 검증 → 코드베이스 재사용 → stdlib → 플랫폼 기본 → 의존성 → 1줄 → 동작하는 최소 코드" / "① NEXT.md 갱신 ② CS 이슈 아카이브" | v4.2 주입 확인 |
| 2026-09-24 03:45 | 사이클 마감(후속 docs 브랜치 docs/v4.2-closeout): ① docs/plans/NEXT.md 생성(N1~N4, 46줄) ② 아카이브 = 별도 작업 cs-issue-archive(spec §4 금지영역 — 합의된 별도 작업으로 이관) / measurement-log 1행 / 완료 요약(Opus 워커 초안, 스니펫 7줄 git show 대조 검증) | — |

## 리뷰 ledger

- review packet: loop1 base 1754f16 / OUT=/tmp/tmp.eMwWJznqgr / mirror=/tmp/tmp.Th5keGzLhQ — codex 한도 소진 → 대체 독립 리뷰어 Fable
- review packet: loop2 base 1754f16 / OUT=/tmp/tmp.lRQvq0yxnC / mirror=/tmp/tmp.FF9Gqrp4DX — Opus ∥ Fable(대체)
- review packet: loop3 base 1754f16 / OUT=/tmp/tmp.vDzsz0azuy / mirror=/tmp/tmp.0Aoreiprdp — Opus ∥ codex(bwrap 실패 → stdin 인라인 codex-inline.md) + post-fix codex-postfix.md
- review packet: loop4(사용자 요청 추가 1회) OUT=/tmp/tmp.CnbHPoEbFi / mirror=/tmp/tmp.wxtO6T9aqy — Opus ∥ codex 인라인 + post-fix
- **(loop3 시점) 종료 상태: `review unresolved`(3루프 상한, loop3 신규 채택 8 전부 fixed, post-fix 1 fixed)** — 잔여 리스크: 마지막 PF-01 수정(1행)은 재점검 없이 메인 확인만 / Ponytail MIT 고지 open question / codex ③ 종합 감사 loop1 미실행(한도)

| id | first_seen_loop | source | 근거(file:line) | disposition | status | fixed_in_loop |
|----|-----------------|--------|-----------------|-------------|--------|---------------|
| R1 선검증 조건 판정기준·생략 기록 부재(silent skip) | 1 | opus F2 · fable F1 | src/core.md:87 | 채택 | fixed | 1 |
| R2 근본원인 1회 수정 ↔ 계획 외 파일 금지 우선순위 부재 | 1 | opus F3 · fable F2 | src/core.md:74-75 | 채택 | fixed | 1 |
| R3 NEXT `(가설)` 허용이 예측형 나열 금지(core §1) 우회 | 1 | opus F5 · fable F5 | templates/next.md:4,17 | 채택 | fixed | 1 |
| R4 NEXT 착수가 새 spec 없이 직전 SPEC=1 재사용 유도 | 1 | opus F4 | templates/next.md·core:112 | 채택 | fixed | 1 |
| R5 과잉 구현 렌즈 예외가 core 비적용 목록보다 좁음 + shrink churn | 1 | opus F1 · fable F6 | playbooks/review.md:92 | 채택 | fixed | 1 |
| R6 study-note 브랜치 정책 부재(core §6 충돌) | 1 | opus F6 | playbooks/issue-archive.md:37 | 채택 — archive/<날짜> 브랜치→ff 병합 | fixed | 1 |
| R7 공개 repo 커밋 전 노출 점검 부재 + 미패치 보안 공개 | 1 | opus F7 · fable F4 | playbooks/issue-archive.md:35-38 | 채택 | fixed | 1 |
| R8 §3 형식 재서술 = 단일 출처 위반·과도기 충돌 | 1 | opus F8 · fable F3 | playbooks/issue-archive.md:28-33 | 채택 — 공개 안전선만 남기고 우선순위 명시 | fixed | 1 |
| R9 사다리 ① 극성 모호·보안 영역 자작 유도 | 1 | opus F9 | src/core.md:75 | 채택 | fixed | 1 |
| OQ ponytail 주석 repo 관례 / 경로 부재 보류 기록 / DEBT 시 마감 시점 / DB 제약 예시 / 마감 순서 | 1 | opus OQ1·2 · fable OQ2·3·4 | — | 채택(문구 반영, DB 제약 예시 삭제) | fixed | 1 |
| L2-1 NEXT.md(메인 사전 판단)가 packet·미러에 포함 — 절단 계약 우회 | 2 | fable F1 | playbooks/review.md:14,21,30 | 채택(P1) | fixed | 2 |
| L2-2 마감 시점 '병합 후' — OSS·타인 병합 시 무기한·main 직접 커밋 유도 | 2 | opus A · fable F2 | src/core.md:114 | 채택 | fixed | 2 |
| L2-3 비적용 목록에 실패 가시화(무음 실패 방지) 누락 | 2 | opus B | src/core.md:75 | 채택 | fixed | 2 |
| L2-4 렌즈가 비적용 목록을 재열거(단일 출처) + playbook §3 우선권 조항 이중 정본 | 2 | opus C · fable F7 | playbooks/review.md:92, issue-archive.md:30 | 채택 — 렌즈는 참조만, §3은 guide 하한 조항 | fixed | 2 |
| L2-5 선검증 생략 판정이 자기판정·검증 불가 | 2 | fable F3 · opus OQ1 | src/core.md:87 | 부분 채택 — 생략 기록을 ② 항목별 기존 강제 file:line로(검증 가능), 사용자 확인은 A2(사용자 축소 결정)로 미도입 | fixed | 2 |
| L2-6 study-note 카드 쓰기 = gate-guard L1 — lazy·리셋 후 상호작용 미기재 | 2 | fable F4 | playbooks/issue-archive.md:3 | 채택 | fixed | 2 |
| L2-7 노출 스캔 '0건만' — 일반 명사 오탐 교착 | 2 | fable F5 | playbooks/issue-archive.md:31 | 채택 | fixed | 2 |
| L2-8 미패치 보안 제한이 회사·외부만 | 2 | fable F6 | playbooks/issue-archive.md:12 | 채택 | fixed | 2 |
| L2-9 NEXT.md 상시 선독 상한 없음 | 2 | fable F8 | templates/next.md:5 | 채택 | fixed | 2 |
| L2-10 설계 문서 분기 선검증 조건 상속 모호 | 2 | fable F9 | src/core.md:90 | 채택 | fixed | 2 |
| L2-11 '삭제>추가' 범위·명시 요청 정의·ff 실패·archive 브랜치 잔존 | 2 | opus OQ2·3 · fable OQ1·2·4 | core:75, issue-archive:38 | 채택(문구) | fixed | 2 |
| L2-OQ Ponytail MIT 고지(요약 이식이 substantial portion인가) | 2 | fable OQ6 | src/core.md:75 | open question — 원문 비복제·요지 한국어 압축, 출처 표기 유지 | open-question | — |
| L3-1 마감 '검증 완료' 정의 부재 — 배포 smoke 등 병합 후 검증과 충돌 | 3 | opus R1 | src/core.md:114 | 채택 | fixed | 3 |
| L3-2 보안 보류가 기록·재개 경로 없이 무음 누락 | 3 | opus R2 | playbooks/issue-archive.md:14 | 채택 | fixed | 3 |
| L3-3 카드 쓰기 범위가 spec 금지영역·재합의와 충돌 | 3 | opus R3 → codex F1(내 수정이 면제 조항으로 악화, P1) | src/core.md:114, issue-archive.md:4 | 채택 — 금지영역 우선·보류+재합의 | fixed | 3 |
| L3-4 append-only가 공개 안전선 위반 제거를 막음 | 3 | opus R4 | playbooks/issue-archive.md:28 | 채택 — 제거 예외+log, push된 이력 퍼지는 사용자 확인 | fixed | 3 |
| L3-5 lazy 일괄 gate-pass = lazymode 게이트 우회 신설 | 3 | opus R5 | playbooks/issue-archive.md:4 | 채택 | fixed | 3 |
| L3-6 ⓒ 내부 구성 재정의(단일 출처) | 3 | opus R6 | playbooks/issue-archive.md:28 | 채택 — 섹션명만 앵커 | fixed | 3 |
| L3-7 cwd 이동 시 상태 해소 변화 / 원 식별자 기록 의무 | 3 | opus OQ1·OQ2 | issue-archive.md:4,8 | 채택 | fixed | 3 |
| L3-8 병합 뒤 검증 결과 main docs 커밋 = §6 충돌 | 3 | codex F2 | src/core.md:114 | 채택 — 후속 docs 브랜치→병합 | fixed | 3 |
| PF-01 노출 스캔이 제거 커밋의 삭제 행을 잡아 교착 | post-fix | codex | playbooks/issue-archive.md:39 | 채택 | fixed | post-fix |
| L4-1 SPEC=1을 승인 범위로 오인 — spec ①에 아카이브 없을 때 범위 확인 부재 | 4 | codex R4-01 · opus OQ1 | issue-archive.md:4 | 채택 — 쓰기 전 범위 확인 1회 | fixed | 4 |
| L4-2 NEXT 상한 삭제가 미해소 보류를 지움 | 4 | codex R4-02 | templates/next.md:5 | 채택 | fixed | 4 |
| L4-3 긴급 DEBT 이월 시 아카이브 무음 누락 | 4 | opus R1 | core:114, issue-archive.md:4 | 채택 — 보류 단일 경로 | fixed | 4 |
| L4-4 선검증 조건이 범위 제약에 과잉 발동 | 4 | opus OQ2 | src/core.md:87 | 채택 — 동작 불변식 한정 | fixed | 4 |
| L4-PF1 DEBT 이월 보류 기록 시점 부재 | post-fix4 | codex | issue-archive.md:13 | 채택 | fixed | post-fix4 |
| L4-PF2 범위 제약에 file:line 증빙 요구 | post-fix4 | codex | src/core.md:87 | 채택 | fixed | post-fix4 |
| L4-OQ 긴급 경로에서 사다리 '계획 밖' 기준선 | 4 | opus OQ3 | src/core.md:75 | open question — 긴급은 긴급 확인 범위가 기준선(core §1), 문구 미추가 | open-question | — |

## 생략한 검증

- (없음)

## 완료 요약

### ① 무엇이 됐나
- core v4.2: §4에 Ponytail 구현 사다리(7단·근본원인 수정·게으름 비적용 목록) 이식, 강도표 높음의 설계 선검증을 "새 동작 불변식이 있을 때만"으로 조건화, §7에 사이클 마감 2단(NEXT.md 갱신 + CS 이슈 study-note 아카이브) 신설, §8에 issue-archive.md·templates/next.md 등재.
- 신규 `playbooks/issue-archive.md`·`templates/next.md`, `playbooks/review.md`(선검증 문구·과잉 구현 렌즈·NEXT.md packet 제외), README·HISTORY 동기. `hooks/` 무변경, core 129→134줄(순증 5 ≤10).
- 검증: `hooks/tests/run.sh` 258 passed, 0 failed(수정 루프마다 재실행), deploy dry-run manifest diff 확인. 듀얼 리뷰 4루프(3루프 상한 후 사용자 요청으로 1회 추가) + post-fix 2회.
- 병합 상태: 1754f16..97aab55 커밋 10개가 main·origin/main에 포함. `~/.claude/core.md` = `src/core.md` 동일(배포 반영 확인).

### ② 핵심 diff (실파일 복사)

**§4 구현 사다리** — before(1754f16:74, 바로 뒤에 신규 행 삽입) / after(src/core.md:75, 신규)
```diff
 - **개발 자세**: 최소 검증가능 증분(계약은 앞단 고정) · 계획에 없는 파일 수정 금지(필요해지면 멈추고 보고) · **load-bearing 가정은 착수 직후 스모크로 조기 실증**(그 위에 쌓기 전에) · 테스트 설계는 구현 diff가 아닌 spec(명세서)에서 출발.
+- **구현 사다리 (Ponytail 이식 — MIT, DietrichGebert/ponytail)**: 문제와 변경이 닿는 코드·실제 흐름을 **끝까지 읽은 뒤**, 처음 성립하는 단에서 멈춘다 — ①정말 필요한가(불필요·추측성이면 만들지 않고 1줄 보고) ②이 코드베이스에 이미 있나(재사용) ③stdlib ④플랫폼 기본 기능 ⑤설치된 의존성(새 의존성은 최후 — 단 보안·암호·파서·인증은 검증된 라이브러리가 자작보다 우선) ⑥한 줄 ⑦그제야 동작하는 최소 코드. 요청 없는 추상화·보일러플레이트·'나중용' 스캐폴딩 금지, 삭제>추가, 같은 크기면 엣지케이스에 맞는 쪽. **버그는 근본 원인에서** — 고칠 함수의 호출처를 전수 grep해 공유 지점에서 1회(공유 지점이 계획 밖 파일이면 위 '멈추고 보고'가 우선 + §3 승격 판정). 알려진 상한이 있는 의도적 단순화는 `ponytail:` 주석(상한·업그레이드 경로 — 외부 OSS·회사 repo는 그 repo 주석 관례 우선). '삭제>추가'는 이번 변경 범위 안에서만(계획 밖 기존 코드 삭제는 §6). **게으름 비적용**: 문제 이해·신뢰경계 입력 검증·데이터 손실 방지·**실패 가시화**(에러 전파·무음 실패 방지·운영 관측)·보안·접근성·명시 요청(spec 합의 항목 포함)·테스트와 검증(§4 안전선·강도표 그대로).
```

**강도표 높음 셀 — 설계 선검증** — before(1754f16:86) / after(src/core.md:87)
```diff
-| 리뷰 | 셀프체크 | **듀얼 1패스**(Opus 워커 ∥ codex → 종합 → 감사 → post-fix 재점검 1회) | **듀얼 리뷰 루프**(≤3) + 설계 선검증 + blind 테스트 워커 |
+| 리뷰 | 셀프체크 | **듀얼 1패스**(Opus 워커 ∥ codex → 종합 → 감사 → post-fix 재점검 1회) | **듀얼 리뷰 루프**(≤3) + 설계 선검증(spec ②에 코드베이스에 없던 **동작 불변식**이 있을 때만 — 범위 제약(무변경·줄 수)은 대상 아님, 생략 시 log 1행: 동작 불변식별 기존 강제 위치 file:line, 없으면 '동작 불변식 없음') + blind 테스트 워커 |
```

**§7 세션 재개 + 사이클 마감 2단** — before(1754f16:111) / after(src/core.md:112, 114 신규)
```diff
-- **저장 위치 = 변경된 프로젝트**(cwd 아님). 상위 repo에는 roll-up 1줄만. 대상이 docs를 gitignore하면 로컬-only 기록으로 인정. **세션 재개** = 최신 작업 폴더의 spec 승인 상태 + log 마지막 행부터.
+- **저장 위치 = 변경된 프로젝트**(cwd 아님). 상위 repo에는 roll-up 1줄만. 대상이 docs를 gitignore하면 로컬-only 기록으로 인정. **세션 재개** = 최신 작업 폴더의 spec 승인 상태 + log 마지막 행 + `docs/plans/NEXT.md`부터.
+- **사이클 마감 2단 (검증 완료 *후* — '검증 완료' = §4 안전선+stakes 리뷰. 병합·push 전 작업 브랜치의 docs 커밋으로, 병합이 통제 밖이어도 이 시점. 병합 뒤 검증(배포 smoke 등) 결과는 후속 docs 브랜치 커밋→병합으로 NEXT에 반영 · 긴급은 DEBT=0 후 · 사전 예측 대신 사후 전망 · ②의 study-note 쓰기는 spec 범위 확인·금지영역이 우선 — 못 쓰면 보류 경로(issue-archive §1))**: ①프로젝트 `docs/plans/NEXT.md`(롤링 단일 문서, `templates/next.md`) 갱신 — 다음 작업 후보·발생 가능 문제·방법론 비교·대처·우선순위(관측 신호 기반만 — 자명 작업은 1행. NEXT 항목 착수도 새 작업 폴더 spec부터 — §1) ②log의 **CS 이슈**를 study-note `cs/issue`에 아카이브(`playbooks/issue-archive.md` — 0건이면 log 1행).
```

### ③ 배운 것 (log ledger 근거)
- 리뷰 수정 자체가 새 결함을 만든다: loop3에서 메인이 넣은 "금지영역 판정 대상 아님" 문구가 spec 금지영역·재합의를 무력화(L3-3, codex F1 P1). 수정분도 반드시 다음 루프나 post-fix 점검에 넣어야 한다.
- 문서 규칙의 결함은 대부분 경계와 우선순위 누락이었다: 근본원인 수정과 계획 밖 파일 금지(R2), 마감 시점과 병합·DEBT(L2-2·L3-1·L4-3), SPEC=1과 승인 범위(L4-1). 새 규칙을 넣을 때는 기존 규칙과의 우선순위를 한 줄 명시해야 한다.
- 리뷰어 가용성이 흔들렸다: codex 사용량 한도(loop1)·bwrap 샌드박스 실패(loop3)·동시 서브에이전트 20 상한. Fable 대체 리뷰어와 stdin 인라인 codex로 우회했고, 병렬 워커 fan-out은 리뷰 슬롯과 경합한다.

### ④ 남은 리스크 / 이월
- open-question L2-OQ: Ponytail MIT 고지. 원문을 복제하지 않고 한국어로 요약 이식했으며 출처는 표기했다. 요약 이식이 substantial portion에 해당하는지는 판단하지 않았다.
- open-question L4-OQ: 긴급 경로에서 사다리의 "계획 밖" 기준선은 긴급 확인 범위로 해석했다(core §1). 문구는 추가하지 않았다.
- loop3 종료 시점 `review unresolved`(3루프 상한, 신규 채택 8). loop4는 사용자 요청으로 1회 더 돌렸고 post-fix 2건을 반영했다. 마지막 수정의 재점검 범위는 타깃 post-fix에 그쳤고, codex ③ 종합 감사는 loop1에서 실행하지 못했다(한도 소진, loop2 재리뷰로 대체).
- spec task04: 완료 — main ff 병합·push(9b828a2..97aab55, 이전 세션 미push 1754f16 포함)·deploy(smoke 통과·diff 0)·신규 세션 스모크 통과·NEXT.md 생성·measurement-log 1행(후속 docs 브랜치 docs/v4.2-closeout). study-note 쪽 authoring-guide B2 개정과 이번 사이클 CS 이슈 아카이브는 별도 작업(cs-issue-archive)에서 수행(spec §4 금지영역 — 보류 경로 대신 합의된 별도 작업).

