# checklist.md — usage report 개선안 반영

## 0단계: 분석·문서화 (이번 단계)
- [x] usage-data 정량 집계(139 세션-meta / 50 facets)
- [x] Claude 추가 분석: 위임강도↔마찰 상관(상위 8% vs 하위 28%)
- [x] codex 개선안 12항목 실파일 대조 검증
- [x] 기존 규칙 중복·충돌 5건 식별(5.2 / 3.7결정 / plan 3.1 / hooks desync / 우선순위)
- [x] codex 교차검증(쟁점 5건 전부 동의 + dist원본 위험 추가)
- [x] report.html 직접 추출(data-text 5개 + Features/Horizon/Multi-Clauding) → §9 반영
- [x] 감축 후보 codex 교차검증 → §10 반영(소/중/대+위험승격 모델)
- [x] 페이즈 게이트 부재 확인(impl 실파일) + codex 설계검증 → §11 반영(master+phase 구조)
- [x] plan.md / context.md / checklist.md 작성
- [x] D1~D7 전체 결정 완료(2026-06-05): D1유지·D2 hooks원본·D3·D6·D7채택·D4먼저커밋·D5 MCP제외→접속정보규칙
- [ ] 사용자 plan 재검토 (착수 방식: 검토 후 구현 — 현 단계 문서화까지)

## P0단계: 선행 정리 (승인 후)
- [ ] D4: 2026-05-14 미커밋 산출물(codex-prompt.md/research.md/docs/plans/2026-05-14) 커밋 여부 결정·처리
- [ ] D2: hooks canonical 정책 확정(hooks/=원본 권고)
- [ ] dist/hooks → hooks/ 역동기화(git-guard.sh, session-context-loader.sh)
- [ ] install.sh / README에 root→dist sync 절차 1줄 추가

## P1단계: 문서/템플릿 contract (한 항목=한 커밋, root+dist 동시)
- [ ] CLAUDE.md `## 반복 실패 방지 규칙` 추가 (+dist)
- [ ] orchestration.md `## 2.4 작업 기준 확정 게이트` 추가 (+dist)
- [ ] orchestration-impl.md `5.2` 확장: 한 단계=한 의도, 중간 검증 가능 단위 (+dist)
- [ ] orchestration-impl.md `## 데이터/마이그레이션 작업 특칙` 추가 (+dist)
- [ ] templates/plan.md `## 0. 작업 기준`(금지영역 3.1 참조) (+dist)
- [ ] templates/checklist.md `## 단일 변경 체크` (+dist)
- [ ] templates/learned.md `## 마찰 흡수 후보` (+dist)
- [ ] 각 문서 하단 변경 이력에 2026-06-05 행 추가

## P2단계: 훅/런북 (contract 안정화 후, warn-only)
- [ ] git-guard.sh: commit trailer 차단 + code/docs 혼합 commit 경고
- [ ] scope-guard.sh 신규(warn-only) + dist/settings.json PostToolUse 등록
- [ ] docs/runbooks/hook-failure.md 신규
- [ ] 1~2주 로그 수집 후 차단 전환 판단

## 검증
- [ ] 2026-06-13 재검토: usage-data 기준 wrong_approach·excessive_changes 감소 측정

## 단계별 codex 호출 기록
| 단계 | 호출 ID | 입력 해시 | 응답 요약 / 스킵 사유 |
|------|---------|----------|----------------------|
| 0.분석 | usage-improve/analysis/001 | (arg 직접전달, stdin 미사용) | 쟁점5건 전부 동의, 2·4번 강한 동의. 추가: 단일변경='중간검증가능단위' 정의, plan0번 완전참조 금지, dist가 실제 설치원본=canonical 위험, 2.5는 다파일 동시변경 위험. 우선순위 Claude와 일치 |
| 0.감축 | usage-improve/reduce/002 | (arg 직접전달) | 감축은 '삭제'가 아닌 소/중/대+위험승격 모델. 후보 R1 소규모4문서·R2 learned10항목·R3 codex기록3중복·R4 추론금지4중반복·R5 전체읽기→범위기반. 불가침: D1 codex의무·추론금지 원칙·보안게이트·고위험 full path. D3 도입 시 R1~R2 자동해결 |
| 0.페이즈 | usage-improve/phasegate/003 | (arg 직접전달) | 공통 페이즈 게이트 도입 찬성. 중/대+위험승격에만 강제, 소규모 면제. 문서구조=(다)master+phase plan. 페이즈게이트=로컬테스트, B5=codex검증 역할분리. 자동롤백 비추(승인 후). 위험: 절차과잉·페이즈=문서단위 함정·검증명령 모호시 가짜통과·의존성강하면 가짜green |
| 4.검증 | usage-improve/review/004 | (arg 직접전달) | **편집 후 정합성 검수**. 치명 4건(B3/A3/C3 3문서 강제·B1.7 research.md·위험승격 중/대 모순·learned.md 전제) + 경미 다수(5.8 vs 13.2 임계, 셀프체크 10→11절, 깨진 2.5 참조, 템플릿 절참조 파일명). Claude opus 에이전트와 교차 — 둘 다 §8 모순 수렴. **전부 수정 완료** |

---

## 실행 완료 기록 (2026-06-05)

| 페이즈 | 결과 | 커밋 |
|--------|------|------|
| Phase 0 — 14일자 베이스라인 | ✅ | `8ef5495` |
| Phase 1 — canonical(hooks/settings root 동기화 + build.sh) D2 | ✅ | `91f28ad` |
| Phase 2 — P1 콘텐츠(반복실패·2.4게이트·5.8페이즈게이트·6.6데이터·감축) + master/phase 템플릿 | ✅ | `8673074` |
| Phase 4 — dual 검증(Claude opus 에이전트 + codex) → 치명 4·경미 다수 수정 | ✅ | (8673074에 포함) |
| Phase 5 — `~/.claude/` 이설 (CLAUDE/orchestration/templates/hooks/settings/runbook) | ✅ | (백업 `~/.claude/.backup-2026-06-05`) |
| P2 — git-guard 확장·scope-guard(warn-only)·hook-failure 런북 | ✅ | `54fa51f` |

- 모든 결정 D1~D7 반영 완료. P2 훅은 **warn-only**로 시작(1~2주 로그 후 차단 전환 판단).
- 잔여(pre-existing, 내 변경 아님): checklist/learned codex ledger `X.5` 표기 중복 — 표기 분리는 후속.
- 재검토 예정일: **2026-06-13** (usage-data 기준 wrong_approach·excessive_changes 감소 측정).
