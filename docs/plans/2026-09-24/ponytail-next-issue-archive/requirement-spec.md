# 요구사항 명세서 (requirement-spec)

> 작성일: 2026-09-24 · 작업 폴더: `docs/plans/2026-09-24/ponytail-next-issue-archive/`

---

## 0. 요구사항 원문 (인터뷰 기록)

- 원문(요지): 하네스가 작업에 주는 불편·리스크·토큰 비용 확인 → ①Ponytail 규칙 이식 ②"설계 때 미리 문제를 작업"하던 무게를 줄이고, **필요한 작업을 끝까지 완료·테스트·검증한 뒤** 다음 작업에서 생길 문제·방법론·대처를 **별도 문서로 리스트업** ③개발 사이클 종료 시 이슈를 `/home/jun/project/study-note/cs/issue`에 추상화 아카이브 — 같은 문제·같은 방안이면 그대로, 같은 문제·다른 방안이면 방안 기록+비교+더 나은 방안 정리(append-only), 문서마다 커밋. "우선 하네스 수정 및 커밋 후 푸시".
- Q/A (전부 권장안 채택, 예외만 기재):
  - A1 Ponytail = core §4 압축 3~5줄 + review.md §3 렌즈 1줄. Output 규칙·Intensity·Persistence 훅·플러그인 설치는 이식 제외.
  - A2 인터뷰·load-bearing 가정 스모크 유지, **설계 선검증은 "신설 불변식이 있을 때만"** 으로 축소 — 줄인 몫은 완료 후 NEXT 문서로.
  - A3 프로젝트 롤링 단일 문서 `docs/plans/NEXT.md` — 사이클 완료(검증 후) 시 갱신, 세션 재개 시 선독. 모든 L1, 자명 작업은 1행.
  - A4 모든 프로젝트(markCloud·하네스 포함)의 L1 완료 시 log.md에서 **CS 이슈만** 추출(도메인 제외), 0건이면 1행 기록.
  - A5 같은 방안 = 본문 불변(B2 확정으로 출처 미기재 → 사례 줄 append도 없음) / 다른 방안 = `3-answer.md`에 `## 방안 비교` append(표+결론+조건).
  - A6 카드(패턴 폴더) 1개 = 커밋 1개(인덱스 README 동반). study-note push는 배치 끝 1회 확인.
  - A7 훅 없음 — 절차 규칙(core §7 1줄 + `playbooks/issue-archive.md`). study-note 경로 하드코딩 허용.
  - A8 듀얼 리뷰 루프(≤3), 훅 무변경이라 blind 테스트 워커 비대상. 브랜치 작업 → main 병합 → push(ask).
  - **B2 수정(사용자)**: 이슈 카드에는 **실제 파일·라인 근거를 노출하지 않는다** — 파일·라인은 검증 시에만 사용(작업 log에 기록). 카드는 시스템·코드 설계 원리를 추상화하고 코드는 단순화된 예시로만. markCloud 등 회사 작업은 시스템 동작 이슈만, 도메인 제외, 실코드 유출 금지. **하네스 자체도 CS 이슈에 포함**.
  - **B2 확정(사용자 2차)**: 규칙 자체를 바꾼다 — 카드에 파일·라인·프로젝트 출처를 적지 않고, **문제 코드와 연결된 코드를 가져와 추상화한 코드로 구조를 직접 표현**한다(출처 불필요). 기존 카드에도 적용.
  - 모드: **auto**. 명세 합의: 2026-09-24 사용자 "둘 다 합의".

---

## 1. 목표·대상 (필수)

claude-code-harness의 `src/core.md`·`playbooks/review.md`·신규 `playbooks/issue-archive.md`·신규 `templates/next.md`(+README·HISTORY 동기)에 ①Ponytail 사다리 ②완료 후 NEXT 문서 ③사이클 종료 이슈 아카이브 절차를 반영하고, main에 병합·push·`deploy.sh` 배포까지 마치면 끝.

## 2. 경계·불변식 (필수)

- 게이트·훅 동작 불변: `hooks/` 무변경, `hooks/tests/run.sh` 기존 전건 green 유지.
- 기존 안전선(§4 최소 안전선·§6 불변 정책·실측 귀속 방어선) 삭제·약화 없음 — Ponytail의 "게으름"은 신뢰경계 검증·데이터 손실 방지·보안·문제 이해·검증에는 적용되지 않음을 명시.
- core.md 부피 증가 최소(순증 ≤ 10줄), 새 playbook ≤ 80줄(core §8).
- 규칙 단일 출처: 아카이브 형식의 정본은 study-note `cs/issue/authoring-guide.md` — playbook은 절차만, 형식은 링크.
- 작업폴더 산출물은 여전히 spec+log 2파일(NEXT.md는 작업폴더 밖 프로젝트 단위 1개).

## 3. 기준소스 (필수)

- Ponytail 원문: `github.com/DietrichGebert/ponytail` @ e3ba2aa (2026-09-14) `skills/ponytail/SKILL.md`·`AGENTS.md`·`skills/ponytail-review/SKILL.md` (MIT) — 출처 표기.
- 하네스 현행: main `1754f16`의 `src/core.md`(=배포본 동일 확인)·`playbooks/review.md`.
- 아카이브 형식: `/home/jun/project/study-note/cs/issue/authoring-guide.md`(B2 개정은 별도 작업 cs-issue-archive에서).
- 사용자 인터뷰 답변(§0).

## 4. 금지영역 (필수)

- `hooks/**`(스크립트·테스트)·`settings.json` 수정 금지.
- study-note repo는 이 작업에서 수정 금지(별도 작업).
- `~/.claude` 직접 수정 금지 — 배포는 `hooks/deploy.sh`만.
- main 직접 작업 금지(브랜치), force push 금지.

## 5. 검증 방법 (필수)

- `bash hooks/tests/run.sh` 전건 green(무변경 확인).
- core.md 줄 수 diff·playbook ≤80줄 확인, grep 정합(§8 표에 새 문서·트리거 등재, README/HISTORY 반영, "설계 선검증" 문구 일관).
- 듀얼 리뷰 루프(Opus 워커 ∥ codex, ≤3) — 렌즈: 기존 안전선 약화 여부·Ponytail과 하네스 규칙 충돌·단일출처.
- 배포: `deploy.sh` dry-run → 실배포 → `diff src/core.md ~/.claude/core.md` 0 + 신규 세션 스모크(`claude -p`로 core §4 사다리 인지 확인).

## 6. stakes (필수)

- 판정: **높음** — 근거: 하네스·정책 변경(core §2 명시 높음), 전 프로젝트 세션에 상시 주입되는 규칙.

---

## 7. 자율성

- [x] auto
- [ ] lazy

## 8. load-bearing 가정 (1~2개)

1. Ponytail 사다리를 core §4에 3~5줄로 압축해도 기존 "최소 검증가능 증분·계획 외 파일 수정 금지"와 모순 없이 합쳐진다(중복이면 병합) — 초안 직후 grep·정독으로 실증.
2. `deploy.sh` MANIFEST가 `playbooks`·`templates` 디렉토리 단위라 새 파일이 자동 배포된다 — dry-run manifest diff로 실증.

## 9. task 분해

| task | 목표 | 의존 | acceptance |
|------|------|------|-----------|
| 01 | core §4 Ponytail 사다리·§4 강도표 설계 선검증 조건화·§7 NEXT·아카이브 1줄·§8 표 등재 | — | 순증 ≤10줄, 테스트 green |
| 02 | `playbooks/issue-archive.md`(≤80줄)·`templates/next.md`·review.md §3 ponytail 렌즈 1행 | 01 | grep 정합 |
| 03 | README·HISTORY 동기 → 듀얼 리뷰 루프 → 수정 | 02 | 종료조건(review.md §1) |
| 04 | main 병합·push(ask)·deploy·신규 세션 스모크·measurement-log·NEXT.md(하네스 dogfood) | 03 | diff 0·스모크 통과 |

---

## 승인 상태

- [x] 필수 6칸 전부 기입
- [x] 사용자 합의 → SPEC=1
- [ ] 자율성 선택 → MODE 기록 (auto 사전 선택됨)
