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
