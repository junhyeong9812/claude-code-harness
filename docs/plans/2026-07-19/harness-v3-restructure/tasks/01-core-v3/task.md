# task-01: core.md v3 재작성

> 정의·계약: master-plan.md §1(D1~D9)·§2(C1~C5)가 정본. 이 task는 그것을 core.md에 이식한다.

## 범위
- `core.md` 전면 개정: §1 상태 모델(L0/L1 + 모드 5종 + C4 계약표), §3 문서 구조(master-plan→tasks·task-process·fast 빚), §5 오케스트레이션(D7 — Opus 워커·depth-2·packet C3), §6 git(D1 push-only)·훅 목록·C1/C2 표, §7 트리거 표 갱신
- `CLAUDE.md`(repo 로컬) 정합 — 산출물 규칙 문구
- **변경하지 않음**: hooks/*(02·03 소관), playbooks/·templates/(04 소관), ~/.claude(05 소관)

## 검증
- 폐지 용어 grep 0 (`auto-write|lazy-write|WRITE_PHASE|write-handoff|writing\.md` — core.md·CLAUDE.md 내)
- C1·C2·C4 표가 core.md에 정본으로 존재, master-plan과 불일치 0
- §7 표의 문서명이 실파일과 1:1 (04 이후 생길 파일은 "(04에서 신설)" 표기)

## 진행 로그 → ../../task-process.md (단일 타임라인)
