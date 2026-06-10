# 프로젝트 작업 규칙

> 이 파일은 모든 대화 시작 시 자동으로 로드된다.

## 핵심 원칙
1. 요구사항을 받으면 절대 바로 구현하지 않는다.
2. 반드시 `orchestration.md`를 읽고 **모드를 먼저 판단**한다.
3. 모드에 따라 해당 문서를 따른다:
   - **구현 모드** → `orchestration-impl.md` (리서치 → 계획 → 구현 → 테스트 → 피드백)
   - **토론/학습/설계 모드** → `orchestration-discuss.md` (자유 대화 흐름)
4. **코드를 추론하지 않는다. 반드시 실제로 열어서 읽는다.**
   - 토큰을 아끼려고 파일을 건너뛰거나 내용을 짐작하지 않는다.
   - 관련 파일이 많으면 전부 읽는다. 일부만 읽고 나머지를 추측하지 않는다.
   - 파일이 길어도 전체를 읽는다. 앞부분만 보고 뒷부분을 가정하지 않는다.
   - 추론으로 절약한 토큰보다 추론 오류로 인한 재작업 비용이 훨씬 크다.
5. **외부 큐레이션을 게을리하지 않는다.** 새 라이브러리/패턴/최신 트렌드/학습 컷오프 이후 영역은 답변·구현 전에 `WebSearch`/`WebFetch`로 외부 정보를 가져온다. LLM의 다수결 편향을 사람의 큐레이션으로 보정하는 절차다. 상세는 `orchestration-impl.md` B1.5절, `orchestration-discuss.md` 3.6절 참조.
6. **모델 교차 검증을 모든 단계에서 수행한다.** 분석·계획·검증 단계마다 `codex`(외부 LLM, GPT-5.5)를 호출하여 Claude 추론에 대한 second opinion을 받고, Claude 의견과 codex 의견을 사용자에게 교차 보고한다. WebSearch(사람 큐레이션)와는 **다른 신호원**으로 LLM 다수결 편향을 한 번 더 보정한다. 호출 실패 시 자동 스킵 + 사유 기록. 상세는 `orchestration-impl.md` B1.6/B3/B5절, `orchestration-discuss.md` 3.7절, `orchestration-agent.md` 11절, `templates/codex-prompt.md` 참조.

## 반복 실패 방지 규칙

> 30일+ 사용 분석(usage report)에서 반복된 마찰(over-scoping, 잘못된 기준 소스 고착, credential grep)을 진입점에서 차단한다. 상세 근거·결정: `docs/plans/2026-06-05/usage-report-개선반영/`.

1. **변경은 한 번에 하나만.** 리팩토링·예외 구조 변경·상속 구조 변경·폴더 이동을 한 번에 묶지 않는다. 한 단계 변경 후 **빌드/테스트/사용자 확인**을 거치고 다음으로 넘어간다. (중/대규모는 `orchestration-impl.md` 페이즈 게이트로 강제)
2. **작업 전 기준 소스를 먼저 확정한다.** DB / ES / CSV / 파일 / 브랜치 / 레퍼런스 프로젝트 중 무엇이 canonical source인지 확인한다. 사용자가 지정한 기준 경로가 있으면 그 경로를 최우선으로 사용한다.
3. **문서 작업과 구현 작업을 섞지 않는다.** "문서만" 요청이면 코드/테스트/파이프라인 파일을 만들지 않는다. "구현" 요청이면 docs 변경은 별도 요청 시에만.
4. **커밋은 스코프를 보존한다.** code commit에 docs를 자동 포함하지 않는다. commit message에 Claude/Codex trailer를 넣지 않는다.
5. **포팅/이관 작업에서는 원본 주석과 엔티티를 보존한다.** 원본 주석 삭제·entity 삭제·data flow 재구성은 명시 요청이 있을 때만 한다.
6. **접속 정보는 사용자에게 받는다.** DB/ES/외부 서비스 접속이 필요하면 작업 시작 시 사용자에게 접속정보(host/port/계정 경로 등)를 요청한다. credential·config를 찾으려 파일시스템 전체 grep을 하지 않는다. 관련 코드/설정 파일을 직접 읽는다.

## 진입점
- 모든 작업은 `orchestration.md`(라우터)에서 시작한다.
- 라우터가 모드를 판단하고, 해당 오케스트레이션 문서로 분기한다.
- 에이전트 활용은 `orchestration-agent.md`를 참조한다.
- 템플릿(`templates/`)은 구현 모드에서 산출물 작성에 참조한다.

## 문서 체계
```
orchestration.md           ← 라우터 (모드 판단 + 공통 규칙)
├── orchestration-impl.md  ← 구현 오케스트레이션
├── orchestration-discuss.md ← 토론/학습/설계 오케스트레이션
└── orchestration-agent.md ← 서브 에이전트 운용 가이드
```

## 경로 규칙
- 이 파일(`CLAUDE.md`), `orchestration*.md`, `templates/`는 **이 파일과 같은 디렉토리**에 있다.
- `.claude/`로 옮긴 후에는, 실제 작업 대상은 **Claude가 호출된 프로젝트 디렉토리**가 된다.
- 구현 산출물(plan.md, context.md, checklist.md, learned.md)은 **대상 프로젝트의** `docs/` 폴더에 저장한다.
