# task: 커밋 메시지·코드 주석에 검증 출처 기재 금지

- 정의 6칸 (자명 — 사용자 지시 전사): 목표 = core §6.4·implementation §5에 "codex 지적·리뷰 반영" 류 출처를 커밋·주석에 쓰지 않는 규칙 추가 / 불변식 = 근거 이력은 task.md·changelog.md 소유(단일 출처) / 기준소스 = 사용자 결정(2026-06-12) / 금지영역 = 그 외 규칙 / 검증 = grep 배선 확인 / stakes = 낮음(전사 수준 — 하네스 변경이나 판단 여지 0, codex 검증은 사용자 보고로 대체)
- 트리아지: 전 차원 비활성 (문서 2줄 추가, 실행 코드 없음) — 1행 축약.
- 변경: core.md §6.4 1줄 + 변경 이력 1행 / implementation.md §5 1줄.
- 검증: grep "검증 과정 출처\|검증 출처" core.md playbooks/ — 규칙 본문은 core §6.4, implementation은 포인터. 측정 1행 기입 ☑. changelog 판정: 문서-only 제외 ☑.
