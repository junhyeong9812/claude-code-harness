# Commit & Push 가이드 — Phase 10 codex 통합 작업

> 작성일: 2026-05-14
> 사용자가 "나중에 커밋 후 푸시" 결정 — 본 문서는 그 시점에 참고하는 가이드.

---

## 현재 git 상태

### Staged (이전에 `git add` 완료된 것 — 본 코어 작업)

```
M  CLAUDE.md
M  dist/CLAUDE.md
M  dist/orchestration-agent.md
M  dist/orchestration-discuss.md
M  dist/orchestration-impl.md
M  dist/orchestration.md
M  dist/templates/checklist.md
A  dist/templates/codex-prompt.md
M  dist/templates/learned.md
M  dist/templates/plan.md
A  dist/templates/research.md
M  docs/HISTORY.md
A  docs/plans/2026-05-14/codex-cross-validation/checklist.md
A  docs/plans/2026-05-14/codex-cross-validation/context.md
A  docs/plans/2026-05-14/codex-cross-validation/learned.md
A  docs/plans/2026-05-14/codex-cross-validation/plan.md
M  orchestration-agent.md
M  orchestration-discuss.md
M  orchestration-impl.md
M  orchestration.md
M  templates/checklist.md
A  templates/codex-prompt.md
M  templates/learned.md
M  templates/plan.md
A  templates/research.md
```

### Unstaged 추가 변경 (부속 토론 마무리분)

```
MM docs/HISTORY.md                                                    # Phase 10 부속 토론 결과 추가
AM docs/plans/2026-05-14/codex-cross-validation/checklist.md         # 수정 기록 + 완료 처리
AM docs/plans/2026-05-14/codex-cross-validation/learned.md           # 11.5 두 항목 추가 (재귀 검토, 외부 권고 위치)
?? docs/analysis/2026-05-14-harness-comparison.md                     # 외부 하네스 비교 분석 신규
?? docs/plans/2026-05-14/codex-cross-validation/commit-message.md     # 본 문서 자체
```

> `.idea/`는 IntelliJ 메타데이터 — 커밋 대상 아님 (gitignore 권장).

---

## 옵션 A — 단일 커밋 (권장)

본 코어 작업 + 부속 토론 + 보존 문서를 한 커밋으로. 시간 흐름이 같은 날 안에서 일관됨.

### 1. 모든 변경분 staging

```bash
cd /home/jun/project/claude_study
git add CLAUDE.md orchestration.md orchestration-impl.md orchestration-discuss.md orchestration-agent.md \
        templates/ dist/ \
        docs/HISTORY.md docs/plans/2026-05-14/ docs/analysis/2026-05-14-harness-comparison.md
git status --short
```

### 2. 커밋

git-guard 가드 통과를 위해 같은 메시지에 `"문서 커밋"` 키워드 포함 필수. **사용자 입력 메시지**(예: 이전 prompt)에서 매칭되므로, Claude를 통해 진행할 때는 한 줄로 명시:

> `"문서 커밋 후 푸시해줘"` (또는 `"docs 커밋하고 푸시해줘"`)

사용자가 직접 shell에서 진행할 때는 가드 영향 없음. 직접 실행 시:

```bash
git commit -m "$(cat <<'EOF'
feat: 오케스트레이션 파이프라인 전 단계에 codex(GPT-5.5) 교차 호출 통합

- X.5(외부 큐레이션 확장) / X.6(모델 교차 검증) / X.7(research.md 작성) 3개 하위 단계 신설
- B/A/C 파이프라인 모두에 codex 의무 호출 (B1.6/B3/B5, A1.6/A2/A3/A5, C1.6/C3/C5)
- B2/A2/C2 게이트를 "방향성 점검"으로 의미 확장 — research.md 기반
- templates/research.md (신규) + templates/codex-prompt.md (5종 표준 프롬프트 + 정책 4개) 추가
- 패턴 기반 보안 게이트(5.7) + 호출 ID/입력 해시 sha256 캐시 도입
- 본 작업 자체를 메타로 시험 — codex plan 검토 8개 지적 중 6개 채택, 1개 기각, 2개 사용자 재확인
- 외부 평가(general-purpose agent + codex 3회) 결과 정리 — Plugin/MCP/Skills 도입 권고 모두 skip
- 재귀 메타 검증의 효용 실증 — codex 자기 정정으로 Skills 전환 권고가 인라인 유지로 뒤집힘
- docs/analysis/2026-05-14-harness-comparison.md 신규 — 외부 하네스 비교 분석 보존
- 후속 작업 11개 후보 정리 (30일 후 2026-06-13 데이터 기반 재검토)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### 3. push

```bash
git log --oneline -3  # 커밋 확인
git push origin main
```

---

## 옵션 B — 분리 커밋 (2개)

코어 작업과 부속 토론을 시간순으로 분리. 히스토리 가독성 우선 시.

### 커밋 1 — 코어 codex 통합 (이미 staged 된 것)

이미 staging은 완료. 추가 변경분만 빼고 커밋. **하지만 현재 HISTORY.md / checklist.md / learned.md는 MM/AM 상태**(이전 staged 위에 더 수정됨)라 두 커밋으로 분리하려면:

```bash
# 1차 커밋용 — 이전 staged 그대로 커밋 (MM/AM의 첫 M/A 버전)
# 단순히 git commit 하면 현재 working tree 버전이 아닌 staged 버전이 커밋됨

git commit -m "$(cat <<'EOF'
feat: 오케스트레이션 파이프라인 전 단계에 codex(GPT-5.5) 교차 호출 통합

- X.5(외부 큐레이션 확장) / X.6(모델 교차 검증) / X.7(research.md 작성) 3개 하위 단계 신설
- B/A/C 파이프라인 모두에 codex 의무 호출 (B1.6/B3/B5, A1.6/A2/A3/A5, C1.6/C3/C5)
- B2/A2/C2 게이트를 "방향성 점검"으로 의미 확장 — research.md 기반
- templates/research.md (신규) + templates/codex-prompt.md (5종 표준 프롬프트 + 정책 4개) 추가
- 패턴 기반 보안 게이트(5.7) + 호출 ID/입력 해시 sha256 캐시 도입
- 본 작업 자체를 메타로 시험 — codex plan 검토 8개 지적 중 6개 채택
- 외부 평가 결과는 30일 후 재검토 자료로 보존
- 후속 작업 9개 후보 정리

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### 커밋 2 — 부속 토론 + 분석 문서

```bash
git add docs/HISTORY.md \
        docs/plans/2026-05-14/codex-cross-validation/checklist.md \
        docs/plans/2026-05-14/codex-cross-validation/learned.md \
        docs/analysis/2026-05-14-harness-comparison.md \
        docs/plans/2026-05-14/codex-cross-validation/commit-message.md

git commit -m "$(cat <<'EOF'
docs: Phase 10 직후 외부 하네스 비교 분석 + 후속 토론 결과 보존

- docs/analysis/2026-05-14-harness-comparison.md 신규 작성 — WebSearch + codex 2회 + 사용자 결론 통합
- 외부 평가의 1순위 도입 권고 3종(Plugin/MCP/Skills) 모두 사용자 운용 맥락 필터링 후 skip 결정
- codex 자기 정정 사례(Skills 권고 → 인라인 유지)로 재귀 메타 검증의 효용 실증
- 사용자 직관이 외부 평가보다 정확했음 — 운용 패턴 깊이 아는 결정권자 + 외부 검증 패턴 확립
- 후속 작업 후보 9 → 11 확장 (#10 codex 응답 판정 절차, #11 hook 실패 해석 runbook 신규)
- HISTORY.md Phase 10에 부속 토론 절 추가
- learned.md 11.5에 재귀 검토 + 외부 권고 위치 학습 2개 추가

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### push

```bash
git log --oneline -5
git push origin main
```

---

## git-guard 통과 안내

`hooks/git-guard.sh`가 다음 두 가드를 적용함:

1. **docs-only commit 가드**: staged 파일이 모두 docs/*.md 류인 경우, 사용자 명시 메시지에서 다음 패턴 매칭 필요
   - `docs commit`, `docs 커밋`, `문서 commit`, `문서 커밋`
   - `commit 해 (... docs)`, `커밋 해 (... 문서)`

2. **push 가드**: `git push` 시 사용자 명시 메시지에 다음 패턴 매칭 필요
   - `push`, `푸시`, `배포`, `밀어`, `올려`, `merge.*main`

**한 메시지로 둘 다 통과시키려면**: `"문서 커밋 후 푸시해줘"` 또는 `"docs 커밋하고 푸시해줘"`

**Claude 세션 외 직접 shell 실행**: git-guard는 Claude Code의 Bash 도구 PreToolUse에서만 동작. 사용자가 터미널에서 직접 `git commit` / `git push` 실행 시 가드 영향 없음.

---

## 권장 진행 순서

1. (선택) `.idea/`를 `.gitignore`에 추가:
   ```bash
   echo ".idea/" >> .gitignore
   git add .gitignore
   ```
2. **옵션 A** (단일 커밋) 권장 — 본 작업의 시간 흐름이 같은 날 안에서 일관됨
3. `git push origin main`
4. 본 commit-message.md는 커밋 후에도 보존 (다음 작업 시 참고)

---

## 변경 이력

| 시각 | 변경 내용 |
|------|----------|
| 2026-05-14 14:15 | 신규 작성 — 사용자 "나중에 커밋 후 푸시" 결정에 따른 가이드 |
