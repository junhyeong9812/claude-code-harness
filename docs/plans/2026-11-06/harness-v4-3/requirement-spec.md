# 요구사항 명세서 — v4.3 일괄 개정 (에이전트 탐색 실측 + 탐색 위임 측정)

> 작성일: 2026-11-06 · 작업 폴더: `docs/plans/2026-11-06/harness-v4-3/` · 브랜치 `harness-search-findings`(main `c2254f0`, WIP `ad80173` 위에서 이어감)
> 산출물 유형: **실행 효력 문서**(core·playbook·template·agent 정의) + 배포 스크립트 1줄 + README·HISTORY — 실행물 규칙.
> 전신: `docs/plans/2026-11-02/agent-search-findings/`(보류 — 이 작업이 흡수. 그 spec의 "워커 기본 모델 변경 금지(측정 전)"는 측정이 끝나 해제).

## 0. 요구사항 원문 (인터뷰 기록)

- 2026-11-02 원문 1·2·사용자 결정: 전신 spec §0 그대로(이름 지침·측정 로그 워커 열·전부 문서화 + README·패치 기록).
- 2026-11-02: "우선 바로 적용하지말고 우리 실험 마무리하고 한번에 하네스를 바꾸는게 맞지않아?" → 보류, 실험 결론 뒤 일괄.
- 2026-11-06 원문: "결국 위임하는게 컨텍스트를 보호해서 매인맥락을 오래 유지하고 노이즈를 없애기 위함인데, 기존의 우리하네스도 그래서 위임형태로 하고있잖아? … 컨텍스트 보호를 기반으로 봤을때 … 적은 비용으로 고 가치를 뽑아낼수 있다는 결론은 소넷인거 아니야?" · "이실험의 결론에 대해서 프로젝트 리드미 최상위에 기록하고 우리 하네스 수정 들어가볼까?"
- Q/A(2026-11-06):
  - Haiku → **Sonnet만**(Haiku는 README에 '불확실 — 고칠 곳 누락 형태 실측'으로 기록만).
  - 적용 방식 → **core 문구 + explorer 정의 배포**(`agents/explorer.md`, model sonnet, 읽기 전용 도구).
  - 범위 → **탐색·대량 읽기 워커만** Sonnet. 구현·리뷰·테스트 설계·독립 검증·완료 요약은 Opus·high 유지.
  - 위임 문구 → **목적 명시(메인 컨텍스트 보호) + 위치를 아는 작은 조회는 메인 직접**.
  - 끝나면 CLI 창에 before/after 요약(이전 합의).

## 1. 목표·대상 (필수)

claude-code-harness v4.3이 아래로 바뀌고 기록되면 끝:
1. **탐색 위임(신규):** `src/core.md` §5 — 넓은 탐색·대량 읽기는 `explorer` 워커(Sonnet, 읽기 전용)에, 목적은 메인 컨텍스트 보호(비용 절감 아님), 위치를 아는 작은 조회는 메인 직접. 나머지 워커는 기본 Opus·high 그대로. core §2의 "넓은 탐색은 워커 위임(§5)"와 문구 정합.
2. **explorer 정의(신규):** `agents/explorer.md`(frontmatter `name`·`description`·`model: sonnet`·`tools` 읽기 도구, 본문 = 탐색 전담·파일 쓰기 금지·경로·줄 번호·요지 보고 — 실험 ADR-0009 §3.1 정의를 옮김). `hooks/deploy.sh` MANIFEST에 `agents` 추가 → `~/.claude/agents/explorer.md`로 배포.
3. **WIP 흡수(전신 spec §1):** core §4 이름 권장 1구 · design-taste §6 찾히는 이름 · refactoring ③ 1줄 · measurement-log 13열 `워커` · core §7 워커 토큰 · §8 트리거 — 리뷰 루프 1 반영분 그대로 두고 이번 리뷰 루프에 다시 넣는다.
4. **기록:** README "실측" 절에 4차 결론 요약(근거 링크·적용 기준·적용하지 않은 것: Haiku·컨텍스트 보호 효과·탐색 외 워커) + 이력 v4.3 행 갱신 · HISTORY v4.3 · core 변경 이력 줄 · 이 log에 **적용 기준표**(지침 → 근거 관찰 → 적용 형태 → 강도)와 **패치 기록**(파일별 before/after 실파일 복사) · `docs/plans/NEXT.md`(N0 완료·후속 후보) · 전신 폴더 log에 "흡수됨" 1행.
5. 마지막에 CLI 창 before/after 요약.

## 2. 경계·불변식 (필수)

- **근거가 받치는 만큼만 규칙화.** 근거 = clean-code-llm-experiment 4차 결론(`docs/results/fourth-conclusion.md`, 본 실행 168) + 1~3차(이름 지침).
  - 받침: Sonnet 탐색 워커 ÷ Opus 탐색 워커 R 0.71 [0.63, 0.84], 성공 비열등(사전 등록 첫 행) · Opus 위임 ÷ 혼자 R 1.76(셋째 행 — 위임은 비용 손해) · 작은 조회 직접 = 측정한 위임 지시(ADR-0009 §3.2)에 있던 문장.
  - 받치지 않음(규칙화 금지): 컨텍스트 보호 효과의 크기(미측정 — "목적" 서술은 사용자 해석으로 표시) · Haiku 사용 · 탐색 외 워커의 모델 변경 · "위임이 비용을 줄인다" · effort 변경(실험은 기본 effort).
- **위임 금지 목록 불변:** 메인 소유(인터뷰·명세·게이트·종합·log writer)는 그대로. explorer는 쓰기 금지 — 훅이 워커 쓰기를 못 보므로 **도구 제한(frontmatter tools)이 1차, 본문 지시가 2차**(core §0.5 "강제는 훅" 한계 명시).
- **배포 불변식:** deploy.sh는 manifest 디렉터리를 통째 교체한다 → `~/.claude/agents/`에 사용자가 따로 둔 정의가 있으면 삭제된다. 현재 없음(2026-11-06 확인) — dry-run의 'DEST에만' 경고로 다시 확인하고, README/deploy 주석에 "agents/는 repo가 정본" 명시.
- 상시 문서 비용: core ≤150줄(현 WIP 135) · playbook ≤80줄.
- 훅 로직·상태·settings.json 무변경(deploy.sh MANIFEST 1줄 + 주석만).
- 기존 measurement-log 행 read-only.

## 3. 기준소스 (필수)

clean-code-llm-experiment `docs/results/fourth-conclusion.md`·ADR-0009(§3.1 explorer 정의·§3.2 위임 지시)·README 4차 결론 절(커밋 `856f930`) + 전신 spec §3 · 하네스 `src/core.md`(WIP) · `hooks/deploy.sh` · `hooks/tests/run.sh` · Claude Code 서브에이전트 정의 형식(`~/.claude/agents/*.md` frontmatter — 착수 때 호스트 CLI에서 스모크로 실증).

## 4. 금지영역 (필수)

훅 로직(gate-guard 등)·settings.json·상태 파일 · 다른 playbook(review·lazymode·open-source·issue-archive) · 탐색 외 워커 기본 모델 · 배포·push·병합(각각 사용자 확인) · study-note 쓰기 · 실험 repo 변경.

## 5. 검증 방법 (필수)

- 스모크(가정 1): 호스트 CLI에서 `explorer` 정의를 읽고 Sonnet으로 도는지 — 배포 전에는 임시 HOME/프로젝트 `.claude/agents`로, 배포 후 신규 세션에서 1회.
- 줄 수(core ≤150·playbook ≤80) · `hooks/tests/run.sh` 통과 · `deploy.sh --dry-run` manifest diff = 의도한 대상만(+ agents 신규, 'DEST에만' 0).
- 근거 대조: 지침마다 인용 수치·문구가 4차 결론 문서에 실제로 있는지 메인 대조(log 적용 기준표).
- **듀얼 리뷰 루프 ≤3**(Opus 워커 ∥ codex, review.md) — 렌즈: 근거 초과(과장)·core 내 규칙 충돌(§2·§5·메인 소유)·단일 출처·상시 비용·explorer 쓰기 차단 실효·deploy 삭제 위험·기록 완결성.

## 6. stakes (필수)

- **높음** — 하네스 정책 변경(core §2) + 배포 대상 추가. 외부 근거 = 실험 repo 4차 결론(사전 등록·168실행) + codex 교차.
- 설계 선검증: spec ②의 동작 불변식 = explorer 쓰기 금지(신규 — 도구 제한으로 강제, 스모크로 확인), deploy agents 통째 교체(신규 — dry-run으로 확인). log에 강제 위치 기록.

## 7. 자율성

- [x] auto (이전 작업과 같음 — 합의 때 확인)
- [ ] lazy

## 8. load-bearing 가정

1. 호스트 Claude Code가 `~/.claude/agents/explorer.md`의 `model: sonnet`·`tools`를 따른다(실험 컨테이너 CLI 2.1.308에서는 실증 — 호스트 버전에서 스모크).
2. 메인이 core 문구만으로 탐색을 `explorer`로 보낸다(실험: 위임 지시 하에 D 54/54 호출, 작은 과제는 미호출) — 실사용 확인은 측정 로그 `워커` 열로 사후 관찰.

## 9. task 분해

| task | 목표 | 의존 | acceptance |
|------|------|------|-----------|
| 01 | explorer 정의 + 스모크(가정 1) | — | 임시 경로에서 Sonnet 모델 키 확인 |
| 02 | core §5·§2 문구 + 변경 이력 · deploy MANIFEST | 01 | 줄 수·run.sh·dry-run |
| 03 | README 실측 절·HISTORY·NEXT·log 적용 기준표·패치 기록 | 02 | 근거 대조 |
| 04 | 듀얼 리뷰 루프(WIP 포함 전체 diff main...HEAD) | 03 | 신규 지적 0 또는 3루프 |
| 05 | 커밋 → (사용자 확인) push·병합·배포 → 신규 세션 smoke → CLI before/after | 04 | smoke 통과 |
