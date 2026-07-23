# 리서치: Claude 파워유저 활용 지도 — "채팅만 쓰는 개발자"가 놓치는 것

> 조사: Opus 워커(딥서치), 2026-07-23. 🟢=공식 원문 확인 / 🟡=2차 출처만(날짜·수치 액면 신뢰 금지). L0 기록.

## TLDR

**놓치는 게 크다 — 단 "기능을 몰라서"가 아니라 "패러다임을 안 옮겨서".** Claude Code에서 체화한 브리핑→자율실행→회수 패턴을 코딩 밖으로 확장한 표면(Cowork·Skills·Connectors·Routines)이 2026년 현재 통째로 존재. 반대로 Memory 자동요약·Artifacts 미니앱은 파일 기반 정밀 통제형 사용자에겐 한계효용 작음 — "전부 켜라"가 아니라 겹치는 상위 5개 집중.

## 기능 지도

### claude.ai 표면
- **Projects** 🟡 — 프로젝트별 영속 작업공간(참고 문서+커스텀 지침 자동 적용). 재브리핑 낭비 제거.
- **Skills** 🟢 — SKILL.md 모듈, 점진적 공개(메타 ~100톤 상시 → 트리거 시 본문 <5k → 리소스). 커스텀 스킬은 Settings>Features zip 업로드(유료+코드실행). **표면 간 동기화 안 됨**(claude.ai/API/CC 각각). https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview · https://github.com/anthropics/skills
- **Artifacts** 🟡 — 영속 스토리지(20MB)·직접 API 호출·MCP 연결·Live Artifacts. 2026-07-13 공개 공유+멀티플레이어 편집(2차).
- **Memory** 🟡 — 2026-03 전 사용자 출시(2차). 채팅 메모리(자동 요약)와 파일시스템 메모리(에이전트) 2층. **채팅 메모리는 API·Claude Code 미적용**. Memory tool 공식 문서 🟢: https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool
- **Connectors/MCP** 🟡 — Google Workspace(Gmail·Drive·Calendar) 2026-02-24 전 플랜 출시(2차), 매 행동 승인. **한계: Drive 기존 파일 편집·정리 불가, Calendar 이벤트 트리거 없음**. 공식 헬프 원문은 404로 미확보.
- **Research 모드** 🟡 — 오케스트레이터-워커(Opus 리드+Sonnet 서브) 병렬 리서치, 최대 45분(2차). 설계 공개 글 🟢: https://www.anthropic.com/engineering/multi-agent-research-system

### Cowork 🟢 — 구조적으로 가장 큰 놓침
- Claude Code의 형제격 **일반 지식노동 에이전트**: 지정 폴더 파일 읽기·편집·생성, 멀티스텝 자율 완수. 데스크톱 2026-01, 웹·모바일 베타 2026-07, 클라우드 실행(기기 꺼도 지속). **사용의 91%가 비코딩**. https://claude.com/product/cowork
- **Scheduled Tasks/Routines** 🟢 — `/schedule`로 반복 작업. **데스크톱 스케줄은 앱 켜둬야 실행** — 클라우드 Routines를 쓸 것. https://support.claude.com/en/articles/13854387

### Claude Code 비코딩 활용(커뮤니티 패턴, 2차)
- Obsidian PKM(자동 백링크·지식 갭 검출), 일일 브리핑·뉴스레터 요약 cron, deep-research 스킬.

## 맞춤 상위 5 (하네스 설계자 기준)

1. **Cowork + 클라우드 Routines** — 위임 패턴을 문서·행정으로.
2. **커스텀 Skills 이식** — playbooks/templates 규율을 claude.ai에도. 점진적 공개=core §0-2 철학 동일.
3. **Connectors** — 매 행동 승인 게이트(gate-guard 궁합). Calendar 트리거 없음·Drive 편집 불가 기대치 반영.
4. **Projects (+Memory는 보조)** — 명시적 지침 > 자동요약.
5. **Research 모드** — 메인=PM 구조와 판박이, 반복 fan-out 위임.

## 과대평가 목록

- Memory "마법" 서사(자동요약은 정밀 통제형에겐 노이즈·CC 미적용) · Artifacts 미니앱(CC 사용자에겐 한계효용↓) · Calendar 커넥터(트리거 없음) · 데스크톱 Scheduled Tasks(앱 상주 필요) · "414+ 통합" 수치(공식 미확인).

## 미확보(정직 기록)

Connectors 공식 헬프 원문(404) · "45분"·"414개"·각 출시일은 2차 기준. Skills·Cowork·Research 설계·Memory tool은 공식 확인.
