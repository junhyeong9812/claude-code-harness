# W5 — claude-workbench 아카이브 백필 실행 (packet)

- **task ID**: W5 (아카이브 백필 실행)
- **기준 SHA**: claude-workbench `f929815c719c9e3ec51d79d3a72692377112d45c` (2026-08-14, worktree clean)
- **워커 모델**: Opus 5 (1M), effort high / 추출 서브프로세스 = `claude -p --model opus --effort xhigh`

## 1. 바이너리 신선도

- 기존 `target/release/archive-backfill` = 2026-08-12 16:22 빌드.
- `git log -- core/src` 로 그 이후 커밋 4건 확인: `f04b531`(ssh.rs) · `705533b`(lib.rs, remote/*) · `0491294`(remote/*, ssh.rs) · `b8bd493`(remote/*, ssh.rs) — **아카이브 경로 소스는 무변경**(`core/src/bin/archive_backfill.rs`·`core/src/archive.rs` 최종 `d5dbd4e` 2026-08-06, `core/src/knowledge.rs` 최종 `7f7acfe` 2026-07-19).
- 그럼에도 lib.rs 가 바뀌었으므로 재빌드: `cargo build --release -p core --bin archive-backfill` → 성공(21.04s, 경고 1건 `unused_mut`).
- **재빌드 산출물**: 2026-08-27 22:25, size 1,856,632
  `sha256 = f6b6ed75d81d437f30b88b4b940e1e2e9ace982d5ca71208ff7ff8734162dbeb`
- 소스 수정·커밋·push 없음(브리핑 금지사항 준수).

## 2. 제외 대상

dry-run 후보 206개 / 38 프로젝트 중 실험 세션 2개를 제외.

| 제외 cwd | 세션 | 사유 |
|---|---|---|
| `/tmp` | 22f8cc60 | 일회성 스크래치 (CLI 자동 스킵은 `/tmp/` 접두만 걸러 정확히 `/tmp` 는 통과 → 명시 제외 필요) |
| `/run/user/1000/cwc-smoke/work` | a4c19b3c | 워크벤치 스모크 테스트 산출물 |

`scratchpad`·`acp-test`·`smoke` 패턴도 지정했으나 후보에 해당 cwd 없음(0건 매칭, `smoke` 는 위 cwc-smoke 와 중복 매칭).
그 외 실사용 프로젝트(`/home/jun`, `/home/jun/다운로드` 포함) 전부 포함 → **대상 204 세션 / 36 프로젝트**.

## 3. 실행 (원문)

```
cd /home/jun/project/claude-workbench
nohup ./target/release/archive-backfill --days 3650 --concurrency 3 \
  --exclude /tmp --exclude /run/user/1000/cwc-smoke \
  --exclude scratchpad --exclude acp-test --exclude smoke \
  > <scratchpad>/backfill.log 2>&1 &
```

- pid 1157523 · **시작 2026-08-27T22:26:05+09:00 → 종료 2026-08-28T02:33:57+09:00 (4시간 08분)**
- concurrency 3 유지(레이트리밋·429·overloaded 로그 0건 → 2로 낮출 사유 없음).
- 로그: `<scratchpad>/backfill.log` (204행 결과 + 요약).
- ⚠️ 중간에 메인이 "프로세스가 사라졌다"고 통보했으나 **오진**이었다 — `/proc/1157523/stat`(state=S, pgrp=1157523, sess=1157520)·`ps -p`·로그 mtime 증가로 생존 확인. 재실행하지 않았다(중복 인스턴스는 프로젝트별 `knowledge/INDEX.md` 공유 자원을 동시에 써 손상 위험).

**최종 요약 라인**: `완료: ok 191 · 부분(추출실패) 10 · skip 3 · fail 0`

## 4. record-level 검증

### (a) 후보 잔량 (동일 인자 dry-run 재실행)

- before: `후보 206개 (완료 12 skip, 재추출 대상 103)` / 대상 204
- after: `후보 17개 (완료 198 skip, 재추출 대상 10)` / **대상 15**
- 잔여 15 = **부분 10**(4-d) + **0턴 skip 3**(빈 세션 — 아카이브 대상 아님) + **2**(백필 실행 중 계속 자라던 라이브 세션: 본 리서치 세션들 `claude-code-harness`·`claude-workbench` — 전사가 아카이브 시점보다 커져 다시 후보로 잡힘, 정상 동작).

### (b) `.extraction-ok` 마커 (세션 디렉토리 레벨)

| | before | after |
|---|---|---|
| 세션 레벨 마커 | **12** | **199** |
| history 버전 디렉토리 내 마커 | 0 | 6 |
| 마커 총계(재귀) | 14 | 205 |

### (c) 프로젝트/세션 디렉토리 수

| | before | after |
|---|---|---|
| project_key 수 | 31 | **43** (+12 신규 키: analyze, deploy, deploy-study-note, final, handover, jun-bank, live-test-makestar, markcloud-kr-maria-in-elastic, study-note, text-server, 한글 키 2종) |
| 세션 디렉토리 수 | 179 | **283** (+104) |

주요 프로젝트 증감(before→after, `sessions=n ok=m`):
`squatting-project 53/14 → 56/48` · `resume 26/0 → 44/37` · `spring-framework-fork 12/0 → 22/17` · `multi-terminal 14/0 → 24/10` · `db-engine-lab 11/0 → 19/19` · `claude-workbench 12/0 → 18/5` · `claude-code-harness 6/0 → 12/8` · `local-llm 6/0 → 8/8` · `live-test-makestar 0 → 8/8`.

**마커 없는 디렉토리 84개**를 전수 분류(같은 uuid8 형제 디렉토리의 마커 유무로 판정):
- **10** = 이번에 재추출되며 슬러그가 바뀌어 새 디렉토리가 생긴 뒤 남은 **구 디렉토리(stale duplicate)** — 마커 있는 쌍둥이 존재.
- **74** = 마커 없는 고아. 이 중 10개는 아래 (d) 부분 실패분, **64개는 마커 도입 이전(2026-06-19~06-27) 아카이브인데 원본 전사가 `~/.claude/projects` 에 더 이상 없다**(샘플 6건 전수 `live_jsonl=0`) → 스캔 후보로 잡히지 않아 백필로는 영구 복구 불가. 재추출하려면 아카이브의 `session.jsonl` 을 입력으로 쓰는 별도 경로가 필요.

### (d) 부분(추출실패) 10건 — 전부 `Claude timed out` (1차 + 재시도 1회 모두 타임아웃)

| uuid8 | 프로젝트 | 라이브 전사 크기 |
|---|---|---|
| 579bace3 | /home/jun/project/resume | 70.7 MB |
| 8a4f44d2 | /home/jun/markCloud/squatting-project/text-server | 41.7 MB |
| 2ed50d87 | /home/jun/markCloud/squatting-project | 39.6 MB |
| c4f3efc3 | /home/jun/project/jun-bank | 37.0 MB |
| d2d9500c | /home/jun/project/claude-workbench | 28.6 MB |
| 78d6bf36 | /home/jun/markCloud/squatting-project | 21.4 MB |
| c9c7b399 | /home/jun/project/jun-bank | 16.2 MB |
| 363def28 | /home/jun/markCloud/squatting-project | 15.1 MB |
| 68f26ee6 | /home/jun/project/claude-code-harness | 13.5 MB |
| 1761423a | /home/jun/project/spring-framework-fork | 8.8 MB |

- 에러 문구 원형: `추출 실패: Claude timed out, 추출 1차 실패(Claude timed out) — 재시도` (68f26ee6·78d6bf36 은 `요약은 이전 아카이브분을 유지` 추가).
- **공통 원인 = 초대형 전사**(전체 후보 중 최상위 크기군). 같은 접근으로 이미 2회 실패 → core §4 "같은 접근 2회 실패 시 3번째 전 사용자 확인"에 따라 **3차 재시도는 하지 않았다**. 해결하려면 추출 타임아웃 상향 또는 전사 청킹이 필요(코드 변경 = 별도 L1 작업).
- skip 3건(0턴 = 대화 없는 빈 세션): `spring-framework-fork 0b989820` · `db-engine-lab 407c6f34` · `/home/jun 85506350`.

### (e) summary.md 샘플 확인

- ok 아카이브는 파일 6종 완비: `.extraction-ok`(0B) · `book.html` · `meta.json` · `normalized.json` · `session.jsonl` · `summary.md`. 샘플 3건 모두 정상.
- summary 내용 샘플 2건(handover 프로젝트, 3,451B / 2,964B) — 실제 세션 내용을 담은 한국어 서술(플레이스홀더·실패 문구 아님).
- **부분 실패분 샘플(579bace3)**: `summary.md` 자체가 **없고** 마커도 없다 → 성공 위장 없이 미완으로 남는다(설계대로). `book.html`·`normalized.json`·`session.jsonl` 은 생성됨(코어 아카이브는 착지).

### (f) knowledge/INDEX.md 갱신

- knowledge 디렉토리 43개(= project_key 수와 동일).
- `db-engine-lab`: INDEX.md 19,266B, mtime **2026-08-28 00:09**, 79행.
- `resume`: INDEX.md 59,342B, mtime **2026-08-28 00:08**, 225행. 둘 다 이번 실행 중 갱신됨, 항목이 실제 세션 지식으로 채워짐.

### (g) 부수효과 — `.mcp.json` 등록

- `knowledge-mcp` 바이너리 존재 확인: `/home/jun/.local/share/claude-workbench/knowledge-mcp` (1,068,000B, 2026-08-10 17:09) → 등록 로직 활성.
- 36개 대상 cwd 중 **34개에 `.mcp.json` 존재, 전부 `workbench-knowledge` 항목 보유**. 그중 **13개가 이번 실행에서 갱신(mtime 08-27/28)**, 나머지는 2026-07 기존 등록분(멱등 무변경).
- 부재 2개: `/home/jun/project/db-engine-lab`, `/home/jun/project/multi-terminal` — **두 디렉토리 모두 현재 존재하지 않는다**(이동/삭제된 과거 프로젝트). 아카이브는 정상 생성됐고 등록만 대상 없음.

## 5. 미완료 / 이월

1. **부분 10건**(초대형 전사 타임아웃) — 재실행해도 같은 타임아웃 예상. 추출 타임아웃 상향 또는 분할 추출이 필요(claude-workbench 코드 변경 = 별도 L1).
2. **구 아카이브 고아 64건** — 원본 전사가 `~/.claude/projects` 에서 사라져 백필 경로로는 재추출 불가. 아카이브 내 `session.jsonl` 을 입력으로 받는 추출 경로가 있어야 복구 가능.
3. **stale duplicate 10건** — 재추출로 슬러그가 바뀌며 생긴 구 디렉토리. 아카이브 하위 파일 삭제는 금지 지시라 손대지 않음(사용자 판단 필요).
4. 라이브 세션 2건(본 리서치 세션)은 세션 종료 후 재백필하면 최신 상태로 갱신된다.
