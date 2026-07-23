# 종합: 사용 인사이트 + 활용도 평가 + 후속 점검 (2026-07-23)

> 메인(Fable5) 종합. 입력: 워커 리서치 4건(같은 폴더 research-*.md — goal-mode·usage-map·features·usage-profile). L0 기록 — 하네스 변경은 별도 L1 게이트.

## 평가 결론

**Claude Code 안에서는 최상위 깊이(훅 하네스·듀얼 리뷰·워커 오케스트레이션·문서 규율), 단 깊이가 "제어·검증" 한 축에 집중 — "자동화·위임" 축(스킬·커맨드·Routines)과 코딩 밖 표면(Cowork·Connectors)은 미개척.**

1. **제품보다 앞서 있던 부분**: §8 JIT 트리거 ≈ Skills 점진적 로드, 게이트/Stop 훅 ⊃ `/goal`(오히려 결정론 강화판). `/goal`은 하네스 대체 불가(Haiku 평가자=자기보고 신뢰 → 그린 위장 취약) — 일회성 장기 작업+종료 절 한정 유용.
2. **정책 vs 실측 불일치 발견**: core §4 "높음 stakes → 외부 검색 의무" ↔ **WebSearch 실측 0건**. codex가 사실상 대역이나 codex는 최신 외부 근거가 아님 — 습관을 바꾸거나 룰을 현실화할 것.
3. **CC 내 아까운 미사용(우선순위)**: ① playbooks→Skills 이식(절차 규칙의 로드를 하네스 밖 강제로) ② 새 훅 이벤트(`InstructionsLoaded`·`ConfigChange`·`PermissionRequest`) 채택 검토 — §5 "훅 관측 불가" 영역 일부를 결정론화 가능 ③ Routines(measurement-log 점검·PR CI 감시) ④ 슬래시 커맨드(set-state 등 반복 타이핑).
4. **코딩 밖**: "채팅만 사용 = 못 쓰는 게 맞다"가 리서치 판정 — 원인은 패러다임 미이전. Cowork+클라우드 Routines·Connectors가 1순위, Memory 자동요약·Artifacts 미니앱은 이 사용자 스타일에선 한계효용 작음.

## 후속 점검 결과

### ② 버전·훅 영향 점검 (완료)

- 설치 버전 **2.1.218** — matcher 정확일치(2.1.195)·auto mode ask-floor(2.1.211) 수정 **모두 포함**.
- settings.json matcher 실측: `"Bash"` · `"Edit|Write|MultiEdit"` — 하이픈 식별자 없음 → **2.1.195 변경 영향 없음**. git-guard의 `ask`는 auto mode에서도 floor로 동작(2.1.211+ 충족).
- 유의 1건: **SessionStart 신뢰 워크스페이스 요구(2.1.218)** — 미신뢰 폴더에서 session-mode-guard 미실행 가능. 신규 머신/clone 배포 시나리오(README 설치 안내)에 trust 수락 선행 명시 후보.

### ③ playbooks→Skills 이식 타당성 (확인만 — 미착수)

현황: playbooks 5종(48~173줄), `~/.claude/skills/`·`~/.claude/commands/` 부재.

| playbook | §8 트리거 | 스킬 적합도 |
|---|---|---|
| review.md(69줄) | 中↑ 리뷰 시점 | **높음** — 주제형 트리거. 단 `context: fork` 금지(메인 소유 종합·ledger — §5) → 인라인 로드형으로 |
| refactoring.md(54줄) | 리팩토링 착수 | **높음** — 자연어 트리거 명확 |
| open-source.md(173줄) | OSS 기여·PR | **높음** |
| design-taste.md(48줄) | 리뷰 렌즈·그룹핑 대화 | 중간 |
| implementation-lazymode.md(54줄) | MODE=lazy | **낮음** — 상태 기반 트리거는 description 매칭과 부정합. reinject-mode가 로드 지시하는 편이 자연스러움 |

- 기대 효과: "해당하면 읽어라"(모델 준수 의존)→스킬 목록 상시 노출+Skill 도구 호출로 준수 확률↑. §8 표 슬림화 여지.
- 한계: 스킬 호출도 결국 모델 판단(결정론 아님) — 강제력 "개선"이지 "보장" 아님.
- 착수 시 필요(전부 **L1** — 인터뷰→명세 게이트): deploy.sh에 playbooks→`~/.claude/skills/<name>/SKILL.md` 매핑 추가, frontmatter(name/description) 부여, core §8 표 갱신(단일 출처 유지), hooks 테스트 영향 확인. 채택 전 skills.md 원문 재확인(core §2).

## 남은 후보 (사용자 결정 대기)

- playbooks→Skills 이식 착수 여부(L1 게이트행)
- 새 훅 이벤트 채택 정밀 조사(hooks.md 원문) 여부
- WebSearch 정책 vs 실측 불일치 처리 방향
- README에 SessionStart trust 전제 추가 여부
- 코딩 밖 표면(Cowork·Connectors)은 하네스 밖 개인 선택
