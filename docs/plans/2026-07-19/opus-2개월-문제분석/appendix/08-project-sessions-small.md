# Appendix 08 — project 소형 14곳 세션 분석 (Opus 워커 원문, 2026-07-19)

> 35세션(~35M): Readlog·valhalla·react·cache-split-lab·study·huasheng13-skill·project루트·elasticsearch·db-engine-lab·java-history·acp-test·spring-security·myway·myway-graph.

---

## ① 프로젝트별 인벤토리

| 프로젝트 | 세션수 | 날짜범위 | 모델 | 주제 | 문제 |
|---|---|---|---|---|---|
| Readlog | 1 | 07-04~06 | **fable-5** | 독서앱+백엔드 구축, Oracle 배포 | ●●● git-guard 문구승인 지옥 |
| valhalla | 1 | 06-23 | opus-4-8 | Valhalla 분석 | ●● 12에이전트 동시기동→rate limit |
| react | 6 | 06-20~28 | opus-4-8 | React 이슈 PR(#36430 등) | ●● repo혼동·gate-guard·push차단 |
| cache-split-lab | 2 | 07-18~19 | fable-5 / opus-4-8 | 캐시분할 부하실험 | ●● 노트북오실행·git-guard·lazymode 손상 |
| study | 1 | 06-20~21 | opus-4-8 | 하네스 설계 토론(lazy-busy) | ●● 계획 오해 6회 교정 |
| huasheng13-skill | 1 | 06-28~29 | opus-4-8 | 문서분석+리뷰규칙 논의 | ● push차단·교정 |
| (루트) -home-jun-project | 2 | 06-21 / 07-17 | opus-4-8 | git프로필 / 스케일업실험 | ●●● push 영구차단(7사과) |
| elasticsearch | 1 | 06-20 | opus-4-8 | ES 병렬 리서치 | ● interrupt 6·csv오생성 |
| db-engine-lab | 12 | 06-27~07-18 | opus-4-8 / **sonnet-5** | B-tree/버퍼풀 학습·구현 | ○ 학습대화 교정(대부분 정상) |
| java-history | 1 | 06-22 | opus-4-8 | Java/Spring 버전조사 | ● docs커밋 5회차단 |
| acp-test | 18 | 06-19~22 | opus-4-6 / opus-4-8 | 파일읽기·핸드오프요약(멀티터미널 ACP) | ○ 대부분 사소, tool-abort |
| spring-security | 1 | 06-22 | opus-4-8 | 컨트리뷰터 리서치 | 없음 |
| myway | 1 | 06-29 | opus-4-8 | 알고리즘 폴더 설계 | ● gate-guard·lazymode 손상 |
| myway-graph | 1 | 07-06 | sonnet-5 | assertj 컴파일 질문 | 없음 |

(주: 루트 `-home-jun-project`와 `cache-split-lab`의 `5b98394a`는 **동일 세션이 cwd 이동으로 두 폴더에 중복 기록** — 실질 1개.)

## ② 신호 통계 (모델별)

- **fable-5** (Readlog·cache-split): git-guard 차단 압도(12건·4건). 코드/배포 실작업에서 hook 마찰 집중. 사과 4건(전부 push/docs 승인 실패).
- **opus-4-8** (대다수): interrupt·correction 고른 분포. 하이라이트: 루트 스케일업실험 — 사과 7건(전부 자기 예측오류 자인) + push 10회 차단→영구실패. gate-guard MODE=UNSET 첫차단이 react/myway/valhalla/db-engine에 반복.
- **opus-4-6** (acp-test 초기): 저부하, tool permission abort·MCP write 실패 중심.
- **sonnet-5** (학습세션): 문제 거의 없음. 교정은 전부 개념 재확인용 능동질문.

합계: 사용자 교정 ~40, hook 차단 ~55(git-guard 최다), interrupt ~35, 모델 사과 ~24, "File not read yet" ~15.

## ③ 대표 에피소드 top 9

1. **[루트/5b98394a·opus] push 영구 차단 후 포기.** 커밋 4개 push에 git-guard 10연속 차단. "네" 승인에도 **매번 `tail` 숫자를 바꿔 명령이 달라져 pending 매칭 실패**, 알림턴으로 승인턴도 어긋남. "죄송합니다, 멈추겠습니다"며 `! git push` 우회 안내. git-guard 최악의 사용성 실패.
2. **[Readlog/74c6e545·fable-5] 문구승인 반복 애원.** "'docs 커밋하고 푸시해줘' 정확히 이 문구로 한 번만 보내주세요"를 세 번 반복. 원인은 훅이 `git -C`만 대상경로로 인식하는데 모델이 `cd`로 시도.
3. **[valhalla/254d7849·opus] 12에이전트 동시기동→rate limit 전멸.** "맞습니다, 제 실수예요… 순차 처리로 바꾸겠습니다". 죽은 태스크에 Monitor 걸어 에러 10연발. 인터럽트 7회.
4. **[cache-split-lab/7eef03de·fable-5] 엉뚱한 호스트에서 부하테스트.** 원격 실험서버 대신 노트북에서 실행 → "왜 노트북에서 부하테스트를 하는거지?". 기준환경(금지영역) 오인.
5. **[react/872ffb35·opus] repo slug 혼동.** 이전 task.md의 잘못된 slug 승계. (cross-origin `in` 연산자 throw를 정확히 포착한 긍정 사례도 병존.)
6. **[study/9dc7c1ec·opus] 계획 오해 반복 교정 6회.** "이거 구현 들어갈 때 물어봐야 되는 거 아니야?" — 구현 진입 전 확인 누락 지적.
7. **[myway/770f90e1·opus] lazymode 상태파일 손상.** `.../lazymode/<id>/MODE: 디렉터리가 아닙니다` echo 실패. MODE가 파일이어야 할 자리에 디렉터리. cache-split(mkdir 실패)·react/04c9783c(MODE 부재)에서도 재현 — **실재 버그**.
8. **[java-history/be36a585·opus] docs 단독커밋 5연속 차단.** 순수 문서작업인데도 승인 마찰.
9. **[db-engine-lab/8d018c38·opus] auxPage 설명 혼선.** 학습형 소크라테스 대화의 정상적 이해구축에 가까움.

## ④ 반복 패턴 (빈도순)

1. **git-guard 승인 마찰 — 최다·최악.** 8개 세션. ① 복합명령·`tail` 숫자변경으로 pending 무효화 ② 중간 알림턴이 승인턴을 밀어냄 ③ 조건부 발화 미인식 → **정확한 문구 필사**나 `!` 우회를 애걸하는 데 반복 도달.
2. **gate-guard MODE=UNSET 첫차단.** 6개 세션. 저stakes 대화성 작업엔 과한 마찰.
3. **lazymode 상태파일 손상.** 3개 세션 — `<id>/MODE` 파일↔디렉터리 뒤바뀜/부재 → echo/mkdir 실패. 세션 재개·중복 cwd 기록과 연관 의심.
4. **"File has not been read yet" 자책 오류.** 6개 세션 15+회, 특히 컨텍스트 요약 재개 직후.
5. **`sleep` 폴링 차단.** 4개 세션 — 모델이 여전히 sleep 폴링을 습관적으로 시도(pgrep-loop 교훈과 동일 뿌리).
6. **병렬 에이전트 과기동.** 12개 동시 → rate limit.
7. **기준환경/repo 오인.** 금지영역·기준소스(칸3·4) 미확인이 실작업에서 재현.

**저신호 구분:** db-engine-lab 대다수·myway-graph·acp-test 후반은 학습형 Q&A로 교정이 실패가 아닌 이해구축 질문.
