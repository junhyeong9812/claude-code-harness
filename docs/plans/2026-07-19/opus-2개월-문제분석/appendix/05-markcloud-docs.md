# Appendix 05 — markCloud docs 기록 분석 (Opus 워커 원문, 2026-07-19)

> 5개 repo군·180+ 작업 폴더의 하네스 기록(task.md·review-log·changelog·measurement-log) 전수 추출 — 총 ≈745건.

---

# markCloud 하네스 문제 분석 (2026-05-19 ~ 2026-07-18)

## 1. 통계 개관

**총 추출 문제 ≈ 745건** (5개 repo군, 180+개 작업 폴더, 일부 복수 분류 중복 포함)

### 분류별 건수
| 분류 | 건수 | 비중 |
|---|---|---|
| **(a) 모델 행동** | ≈429 | 58% |
| **(b) 훅·하네스 결함** | **9** | 1% |
| **(c) 프로세스**(게이트생략·측정누락·검증갭) | ≈202 | 27% |
| **(d) 도구·환경** | ≈105 | 14% |

(a) 세부: 정합상실/데이터의미 결함이 최다(포팅·마이그레이션 계열), 동시성 미보호 ≈40, 입력검증·예외삼킴 ≈40, 정렬/tie-breaker ≈15, codex 오탐 ≈20, 과잉스코프·지시위반 ≈6, 무근거통과 ≈4.

### repo별 분포
| repo | 건수 | 성격 |
|---|---|---|
| **was-server** | ≈248 | Java/Spring+MySQL — 마이그레이션·동시성·인증보안 결함 밀집 |
| **front-server** | ≈196 | Next/React — 비동기 race·예외삼킴·CSS·MR리뷰 findings |
| **text-server** | ≈174 | ES 다국가 색인 — 데이터 손실·오염·색인 정합 (최우선) |
| **squatting-root + trademark-squatting + 기타 2** | ≈124 | 포팅 검증·데이터 파이프라인·부하테스트 |

### 시간 추이
- **2026-05 (포팅기)**: Python→Java·egov→REST 이관에서 (a)정합상실 집중. 단위테스트 통과 / 실 MySQL·실코드 대조에서만 결함 노출(VARCHAR truncation, 조인 대상 부재, 이벤트 전량 누락). 이 시기 measurement-log **미기록**(checklist로 대체).
- **2026-06 (기능 구축 + 리뷰기)**: 듀얼 리뷰·codex 교차검증 본격화 → 채택 finding 급증. Flyway 병렬 브랜치 충돌 반복 표면화. ES 다국가 마이그레이션 시작(디스크 full·OOM 실사고).
- **2026-07 (리팩토링 캠페인 + pair 모드기)**: 대규모 리팩토링에서 "그린 위장" 테스트 하네스 결함이 최대 결함군으로. stakes 저평가로 인한 듀얼 리뷰 생략 상습화.

## 2. 반복 패턴 Top 6 (하네스 개선 입력 후보)

1. **Silent failure = 마이그레이션 결함의 공통 형태 (최다·최고위험)**. "에러 없이 돌았다 ≠ 완료"가 수십 회 실증: 부분실패해도 job DONE 위장, watermark 미색인 문서 영구 스킵, 예외 삼킴으로 페이지 통째 유실, cap 초과분 조용한 절단, 커서 조기종료로 tid 전량 손실. **core §6.3 데이터 특칙의 존재 이유가 반복 확인됨.**
2. **"그린으로 위장"하는 테스트/검증 하네스 결함**. fail-open 골든(골든 유실·오타가 전부 통과), 자기참조 골든(타입 하드코딩), 관대한 스텁, 과잉 마스킹, 무판별 테스트 케이스, Mock 맹점(.spool·_source 미재현), 통합테스트의 인증모델 미재현(거짓 통과). 진짜 회귀를 가리는 최상위 위험군.
3. **Flyway 병렬 브랜치 충돌 (was-server 9개 작업 반복)**. 버전 번호 선점, authorization_no PK 겹침, 기적용 마이그레이션 수정/리네임. **fresh 컨테이너 IT가 out-of-order를 구조적으로 못 잡는 검증 맹점** 노출. `mvn clean`+신선 컨테이너가 표준 대응으로 정착했으나 근본 미해결.
4. **中·높음 stakes 듀얼 리뷰(Opus 워커 ∥ codex) 생략·미달 (양 repo 합산 ≈16건)**. codex 단독을 듀얼로 오인, "듀얼 루프는 높음 전용" 강도 오해석, 셀프리뷰 갈음, review-log.md 미생성(→ template-guard 미발동, **하네스 커버리지 공백**). core §5 "듀얼 리뷰 누락 금지"에 대한 자체 완화 판단이 상습화.
5. **비동기 stale race / 예외 무음 삼킴 (front 다발)**. 늦은 응답이 최신 상태 덮어쓰기(AbortController 부재) 5회+, 조회 실패를 `[]`로 삼켜 exists 오판→중복 POST, allSettled 무시로 부분실패 은폐. codex와 Opus가 서로 다른 것을 잡는 **듀얼의 상호보완** 실증(역으로 codex 오탐 ≈20건도 전부 메인 실파일 대조로 기각).
6. **check-then-act + DB unique 부재 (4개 도메인 재발)** 및 **stakes 판정 양방향 편향**(계약·인프라 인접 저평가 vs 순수함수 과대). 세션 경계에서 실측·결정 유실→오판 3건(전부 영속 문서 미기록 원인).

## 3. ★ ES/DB 데이터 마이그레이션 결함 (실사고 최우선, 약 70건 중 발췌)

| 사건 | repo/날짜 | 상태 |
|---|---|---|
| 디스크 full → VN 45%/ID 15% 문서 silent drop인데 job은 DONE | text 06-02 | 사후 인지, 근본 이월 |
| ES 힙 OOM → VN 색인 부분실패(774k중 534k failed), 인덱스 삭제 후 재실행 | text 06-14 | 힙 30g로 해결 |
| CN 커서 페이징 조기종료 → 삭제건 윈도우 이후 tid 전량 silent loss | text 06-26 | 리뷰 채택·수정 |
| watermark silent 누락 → 미색인 문서 영구 스킵 | text 06-29 | 채택·수정 |
| 디스크 1.8TB 99~100% → ES read-only → 검색 500 운영장애, US 3%만 적재 후 중단 | text 06-29 | 부분해소(증설 대기) |
| **US child batch 실패 예외 삼킴 → 페이지 통째 유실 미집계** | text 07-09 | **미수정 백로그** |
| US 직렬화 키 21건 잠복(19건 역직렬화 이미 파손) | text 07-09 | @JsonProperty+계약테스트 수정 |
| 골든 하네스 fail-open(골든 유실·오타 전부 "그린" 위장) | text 07-13 | fail-closed 수정 |
| image_saved VARCHAR(16) 오버플로 → ID 잡 99.8% 실패(198,579건) | trademark-squatting 05-27 | VARCHAR(255) 해결 |
| replace_children 데드락 → ID 60%/VN 15% 실패 | trademark-squatting 05-27 | TRUNCATE 우회, **근본 미해결** |
| V112 `LIKE 'SUS_SEED%'` 와일드카드 `_` → 관리자 행 오삭제 + CASCADE 대표상표 유실 | was 07-16 | ESCAPE 채택·해결 |
| V89 columnDefinition TEXT↔MEDIUMTEXT 불일치 → 130KB 콘텐츠 절단 | was 07-03 | 채택·수정 |
| V66 `DROP COLUMN IF EXISTS` MySQL 8.4 방언 미확인 ERROR 1064 | was 06-23 | 실측 후 수정 |
| 경로 복수화에 권한 시드 단수 잔존 → fail-closed 신경로 전체 403 회귀 | was 06-16 | V50 UPDATE 해결 |
| Python→Java 포팅: events 전량 누락·publication_number 폐기·vienna/nice 파싱 불일치 8건 | squatting 05-21 | **대부분 미해결**(검증 리포트 단계 종료) |
| VN cartesian 곱 폭발(1건=4096 변형, 100.5GB→15GB) | text-server 부하 06-22 | 캡 100 재색인 해결 |
| 이미지↔텍스트 출원번호 정규화 불일치 → 이미지검색 결과 항상 빔 | was 06-16 | 국가별 정규화 해결 |

**공통 미해결 요주의**: US child silent data-loss, migration-robustness terminal-state/saveAll/zombie 3건, US/CN 전량 미적재(디스크 증설 대기), kor-pron 신구 매핑 혼재 재색인 미완, US backfill 14,247건 유보, poison row watermark 정체, int_reg_num 파괴적 정규화 원본 미보전.

## 4. 분류별 대표 문제

### (a) 모델 행동 — 중대 사건
- **인증·보안 회귀 도입/미방어** (was 다수): updatePassword/updateInfo 현재비번 미검증(탈취 토큰만으로 비번변경), 타이밍 기반 계정열거, JWT fail-open 단락평가, XFF 무조건 신뢰 레이트리밋 우회, 공개 익명 3GB 멀티파트 DoS, KIPRIS accessKey URL 로그 노출.
- **동시성 미보호**: LoginLock off-by-one 조기잠금, 채번 SELECT MAX+1 레이스, @Cacheable sync=false 중복 외부호출, common-code stale stomp, claim TOCTOU(Opus 워커 오판·codex 단독 검출).
- **지시위반·과잉스코프** (전부 사용자 지적으로 교정): 정의 게이트 작성 전 코드 수정 선행 2회, 타인 도메인 리포지토리 재배치 2회, 요청범위 초과 "더 깔끔한데" 수정 후 revert.
- **무근거통과** (codex 반례로 적발): 블랭킷 409 fallback을 "선검사가 막음"으로 합리화, 시뮬 PASS가 운영 실패모드 은폐(deploy-pipeline /health 200만 확인).
- **오귀속·무근거 결론 후 실측 정정**: ASEAN을 damage_case로 안 걸러 정상 대기업 혼입("약한 신호" 오결론→전면 재작성), "US=JPA"·"common=CSV" 무근거 추론, 웜캐시 벤치마크 방법론 결함으로 샤드 결론 정정.

### (b) 훅·하네스 결함 (9건 — 유일하게 하네스 자체 귀속)
- **P10 리뷰 워커 오귀속**: 공유 워킹트리 미커밋 누적으로 git diff 페이즈 구분 불가 → 타 페이즈 변경을 "범위위반 Critical"로 오판. 해결(페이즈 커밋·scope 브리핑·워크트리 격리 도입).
- **git-guard push false-block** (jsonl 지연 — 기지 결함, capture-prompt 사이드카로 수정).
- lazy 모드 세션키잉 혼란(resume 후 CWD별 상태파일)·git-guard 턴스코프 마찰, TC reuse checksum, vitest include에 shared/** 누락으로 테스트 여태 미실행 등. **front·text repo 기록엔 하네스 오작동 0건** — 도구 실패는 codex 샌드박스/빌드/ES 인프라 (d)에 집중.

### (c) 프로세스
- 듀얼 리뷰 생략·stakes 저평가, review-log.md 미생성 4건(하네스 미발동), 리뷰 게이트 순서 위반(dev 머지 후 codex→실버그 머지 뒤 발견), 실환경 e2e 대량 이월(WAS 미배포·ES 부재), 2026-05 measurement-log 전면 누락, 세션 간 실측·결정 유실 오판 3건, "보이는 시점" 미검증(헤드리스가 렌더완료 후 측정해 로딩/SSR 버그 통과).

### (d) 도구·환경
- **TC reuse × Flyway checksum 반복 7회+**, stale target/classes 3회(mvn clean 누락), **codex 샌드박스 bwrap/exec 실패 반복**(→ 독립 리뷰 대체, 인라인 발췌 잘림이 오탐 유발), 미설치 devDep(vite-tsconfig-paths)로 빌드/테스트 게이트 불능 4회, 멀티세션 브랜치 오염(git add -A 스윕·cwd 잔류로 사용자 미커밋 4파일 오입 사고), GitLab 토큰 만료.

## 5. 핵심 결론

1. **하네스 자체 결함은 극소(9/745, 1%)** — 규칙·훅 설계는 대체로 견고. 문제의 압도적 다수는 모델 행동(58%)과 프로세스 준수(27%)이며, 이는 하네스가 **막지 못한** 영역(판단 게이트)에 집중.
2. **데이터 작업의 silent failure가 최고위험군**이며 실제 운영 데이터 손실·장애로 여러 번 실현됨 — core §6.3(record-level 검증)·§3.4("테스트 통과≠완료")의 강화 근거가 압도적으로 축적. 특히 **미수정 백로그로 남은 US child data-loss·terminal-state 3건·파괴적 정규화**는 추적 필요.
3. **검증 하네스가 스스로를 속이는 결함**(fail-open 골든·거짓 통과 IT·관대한 스텁)이 리팩토링기에 최대 결함군으로 부상 — 하네스 자기검증(리네임 실증·DDL 매트릭스) 외엔 방어 수단이 없었음.
4. **듀얼 리뷰 생략의 상습화 + review-log 미생성 시 template-guard 미발동**이 반복 관측 — 이 커버리지 공백이 하네스 개선의 유력 후보. 반면 실제로 돌린 듀얼 리뷰는 codex·Opus 양방향 단독 검출로 독립 신호 가치를 실증.
