# 아카이브 노트 — 하네스 v2 스냅샷 (2026-06-20)

> **이 폴더는 `lazy-busy` 모드 도입 직전의 현재 하네스 전체 복사본이다.** 되돌릴 기준점.
> (이 폴더의 `README.md`는 스냅샷된 하네스 본래 README이므로 건드리지 않는다. 설명은 이 파일에.)

## 무엇인가
- 시점: 2026-06-20, `lazy-busy` 모드(README 정의 단계)를 시작하기 **직전**.
- 범위: 운영 하네스 정의 파일 + 설계 docs 전체.
  - `core.md` · `CLAUDE.md` · `README.md` · `dimensions*.md` · `settings.json` · `.gitignore`
  - `playbooks/` · `templates/` · `hooks/` · `docs/`
  - 제외: `.git` · `.idea` · `.claude` · `archive/`(자기복제 방지)
- 이 스냅샷의 `core.md`는 떠놓은 시점의 루트 `core.md`와 **바이트 일치**(diff 확인).

## 왜 떠놨나
다음 단계로 `lazy-busy` 모드(구현마다 사용자 이해를 객관식으로 검증하며 진행, 자동주행 금지)를
도입하면서 `core.md`·`CLAUDE.md`·`playbooks`·`templates`·`dimensions`·`hooks`·`settings`가 바뀔 예정이다.
바꾸기 전 현재 동작본을 통째로 보존해, 문제가 생기면 이 폴더로 롤백할 수 있게 한다.

## 계보
- `archive/2026-06-10-opus-harness/` — 그 이전(Fable 5 재설계 전) 시스템.
- **`archive/2026-06-20-harness-v2/`(이 폴더)** — Fable 5 재설계로 만들어진 현재(v2) 시스템. lazy-busy(v3) 도입 직전 상태.

## lazy-busy 설계 결정(사용자 선택, 2026-06-20)
다음 단계 README가 반영할 4개 결정:
1. **게이트 형식**: 자기설명(자유 회상) 후 객관식으로 확정·채점.
2. **오답 처리**: 통과까지 재학습·재출제(이해할 때까지 다음 단계 차단).
3. **코드 이해 게이트 단위**: 논리적 변경 단위마다.
4. **발동 범위**: 전 작업 기본(자동 모드를 사실상 대체) — 단 core.md 배선은 후속 순차 단계.
