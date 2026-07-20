# review-log: task-01 git-guard push 승인 → ask 반환 + trailer 오탐 수정

> 스키마 = `playbooks/review.md §2`. 이 파일은 인스턴스 + finding 실질 내용.

## 루프 메타

- packet base SHA: `a75e828d611da8bc0d47d91f08bf3167c251f4ca..현재`
- 입력 격리: Opus 워커 packet-only ☑ / codex 임시 디렉터리(`/tmp/gg`) packet 파일 ☑ / 비대칭: 없음
- 리뷰 형태: 병렬 듀얼 루프(높음) — 실제 회차: 루프1(병렬) + 루프2·3(codex 감사) + post-fix 타깃 재점검 1회 = **3-루프 상한 초과(+1)**
- 종료: open(채택·미수정)=0 ☑ / 신규 채택=0(마지막 라운드는 설계 재정리로 finding 소멸) ☑ / 145 tests green + 스모크 ☑
- **⚠ 프로세스 이탈 (투명 보고)**: 높음 3-루프 상한을 초과했다. 사유 — 매 라운드가 *새* 실결함을 냈고(러닝 churn 아님), F3는 내 수정이 도입한 회귀라 방치 불가였다. 5라운드째에 근본 원인(파싱 불가 경로에 trailer 정밀탐지=자기모순)을 파악하고 **F2를 재처리**해 클래스를 소멸시켜 수렴. 경계 P0/P1은 루프3에 독립 확인 완료.

## 리뷰 모드
- codex 교차검증: 수행 ☑ (루프1 병렬 + 루프2·3 감사 + 최종 타깃 재점검 = 4회)
- Opus 워커(독립 서브에이전트): 수행 ☑ (agentId a2d34d4a…, opus, 30개 크래프트 입력 실행 프로빙 — CLEAN)
- 셀프리뷰: 메인 교차확인(스모크·grep) — 보조

## finding ledger

| id | loop | source | 근거(file:line) | 요지 | disposition | 근거 | status | fixed_in_loop |
|----|------|------|-----------|-----------|------|------|------|------|
| F1 | 1 | codex | git-guard.sh push_report | push_report가 훅 cwd/현재브랜치/@{u}만 조회 → `git -C`·refspec·pushRemote 등에서 실제 발행 대상과 다른 값을 ask reason에 표시 → 승인 오도 | 채택 | 권한경계 UX(오도된 승인). §6.5 보고 취지 훼손 | fixed | 3 |
| F2 | 2 | codex | git-guard.sh C2 ② 폴백 | C2 폴백이 trailer 검사 없이 emit_ask → 정제실패+trailer+push 복합에서 승인 시 동반 trailer 커밋 유출 | **재처리(수용된 갭)** | 최초 채택(loop2 하드차단 추가)했으나 fix가 F3·잔여·Pushkin 오탐 4라운드 유발. 근본: 파싱 불가 경로의 trailer 정밀탐지는 자기모순. **won't-fix-in-fallback** — best-effort 갭으로 수용(사유 아래) | accepted-limit | — |
| F3 | 3 | codex | git-guard.sh C2 폴백 | F2 fix(무조건 has_trailer)가 순수 주석 `# Co-Authored-By: Claude`도 exit2 차단 = **내가 도입한 회귀 오탐** | 채택 | 자기도입 FP, 방치 불가 | fixed(→F2 재처리로 소멸) | 5 |
| F3′ | 3(final) | codex | git-guard.sh C2 폴백 | F3 1차 fix(`grep 'commit\|push'` 게이트)가 부분문자열이라 `# commit…`·commitment·Pushkin 주석도 여전히 차단 | 채택 | 부분문자열 게이트의 잔여 FP | fixed(→F2 재처리로 소멸) | 5 |
| F4 | 3 | codex | git-guard.sh push_report | detached HEAD에서 `rev-parse --abbrev-ref HEAD`가 "HEAD" 반환 → "현재 브랜치=HEAD" 오도 | 채택 | 보고 정확도 | fixed | 5 |

### F1 수정
정확 파싱 거부(취약점 재도입·완전커버 불가) → 정직한 축소: 조회값을 정확 명명(`참고용 로컬 컨텍스트(cwd=…): 현재 브랜치·upstream 리모트(branch.<br>.remote)·upstream 대비 HEAD 고유 커밋`) + `⚠ 위 값은 실제 push 대상·범위가 아님`(결정요소=명령+Git설정 명시) + 원본 명령 표시. 네이티브 UI도 명령 독립 표시.

### F2 재처리 근거 (수용된 best-effort 갭 — 사용자 확인 대상)
C2 ② 폴백은 **정의상 정제 불가 경로**(awk/sed 기계오류 또는 전량 주석/인용). 여기서 trailer를 정밀 탐지하려면 부분문자열 매칭이 불가피하고, 매 패치가 새 오탐을 낳았다(commitment·Pushkin). 이 작업의 취지(git-guard의 취약 휴리스틱 제거)와 정면 충돌. 결정: 폴백은 **push 안전망 한 가지만**(raw push→보수 ask), trailer 정책은 **정제 가능한 정상 경로에만**. 잔여 유출(정제실패+trailer커밋+push복합+사용자승인) 수용 근거: ⓐ 정제 실패=기계오류 희소 ⓑ ask UI가 승인 전 복합 명령 전문(동반 trailer 커밋 포함) 표시 ⓒ 정상 경로도 못 잡는 `git ci`·`git merge -m` alias 갭과 대칭. → **사용자 이견 시 폴백 trailer 차단 복원 가능(단 오탐 트레이드오프 재발)**.

### F4 수정
`symbolic-ref --short -q HEAD` + fallback `(detached HEAD 또는 미상)`, detached 시 config 조회 생략·리모트 `(해당 없음)`.

## Opus 워커 결과 (루프1) — CLEAN, 6불변식 실행 입증
①감지 커버리지(git -C·/usr/bin/git·command·cd·-c·--force·heredoc·산술 전부 ask, FP경계 유지) ②malformed/empty→통과+경고 ③ask JSON 유효+git조회 실패 degrade ④trailer 실차단+제품명 통과 ⑤죽은코드 잔재 0 ⑥테스트 non-trivial.

## verified (대칭 부담) — 경계 렌즈
| lens | applicable | 근거 | how | source |
|------|-----------|------|-----|--------|
| 권한경계(push 감지) | Y | GIT_PRE/GIT_OPTS main과 byte-identical | Opus 30입력 실행 전건 ask | opus |
| 예외처리(C2) | Y | git-guard.sh C2 폴백 | malformed→통과+경고, canon실패→차단 실행확인 | opus |
| API계약(ask JSON) | Y | emit_ask jq --arg | jq -e permissionDecision==ask + printf %s 이스케이프 안전 | codex |
| 가시성(§6.5 보고) | Y | push_report | F1·F4로 정확 명명·detached 처리 | codex |
| 동시성·데이터정합 | N/A | 단일 실행 read-only 훅 | — | — |
