# playbook: 리뷰 (中=듀얼 1패스 / 높음=병렬 듀얼 리뷰 루프)

> 트리거: **中·높음**의 리뷰 시점(페이즈 구현 완료·커밋 후). 개발 단계의 설계 자문은 §3 렌즈만 참조. **낮음(셀프체크)만 이 문서를 읽지 않는다.** 中 = §1의 **듀얼 1패스**(⓪~④ + post-fix 타깃 재점검, ⑤ 반복 없음) + §2·§3 / 높음 = §1 전체(반복 루프 max3) + 설계 선검증·blind 테스트 워커. §2 대칭 부담·ledger는 中·높음 공통.
> ★ **산출물 유형 분기 (2026-08-06 — core §4의 정의를 따른다)**: 산출물이 **설계 문서**면 中·높음 공통으로 **中 변형(⓪~④ + post-fix 타깃 재점검 1회)** 이 상한(⑤ 반복 없음 — 높음의 3루프는 실행물 전용, blind 테스트 워커는 비대상). 리뷰어 프롬프트에 명시: **"동기화·표기·색인·버전 정합은 지적 대상이 아니다 — 구조·불변식·판정 충돌만"**(그 유형의 **사냥을 리뷰가 하지 않는다**는 뜻이다 — 검산 도구·구현 소관. 이미 발견된 결함의 수정을 막는 규칙이 아니다. 실측: 문서 리뷰 지적의 ~60%가 이 유형에 소모됐다).
> 원리: 같은 모델 여러 개는 편향을 공유한다 — 독립 신호는 다른 모델(codex)이 제공하고, 최종 판정은 투표가 아니라 근거 품질 재평가다.

## 1. 루프 절차

```
⓪ review packet 생성 → ① Opus 워커 ∥ codex 병렬 리뷰 → ② 메인 종합 → ③ codex 종합 감사
→ ④ 수정 → 테스트 → ⑤ 재리뷰(①로) … 종료 조건 충족 시 탈출, 최대 3루프
```

- **⓪ review packet** (2026-08-27 실측 — diff-only packet이 untracked 누락 오탐 11작업·Opus 단독 채택 37%의 원인): 페이즈 시작 base SHA와 **실제 `$OUT`·미러 경로**를 작업 폴더 log.md에 고정(임시 경로라 사후 재현의 유일한 단서). packet = ① **누적 diff** — base 커밋 vs **index+작업트리**(staged·unstaged 모두). tracked 대용량 binary는 `git diff --stat`으로 크기를 먼저 보고 `-- ':(exclude)<path>'`로 빼되 목록에 표기한다. ② **untracked 정규 파일 전문**(index 무변경 — `git add -N` 금지). 항목마다 `### untracked: <경로> (<크기>)` 헤더를 먼저 적어 **빈 파일도 가시화**한다. symlink는 target 1줄, FIFO·socket·device는 타입 1줄, binary는 `file` 타입 1줄. **untracked 한정으로 파일당 1MB·총 5MB 상한** — 초과분은 *절단하지 않고* 목록만 넣어 `packet truncated`로 표시하고 사용자에게 보고한다. **현재 작업 폴더의 `log.md`는 제외**한다(리뷰 ledger·메인 판단이 리뷰어에게 새는 경로). ③ **spec 원문**(⓪′) ④ **연관 파일 목록** — 변경 hunk의 심볼(함수·타입·설정키)로 돌린 `git grep`의 **명령 원문과 원시 결과를 그대로** 붙인다. 이건 **탐색 힌트지 증거 범위가 아니다** — 메인이 해석·선별·요약을 덧붙이지 않는다(사전 판단 유입 방지). ⑤ 이번 루프 수정 diff는 참고로만 별도 표기(마지막 수정만 보면 전체 일관성 문제를 놓친다) ⑥ **read-only 미러**(①) — tracked 정규 파일 + ②에서 본문을 붙인 untracked만, `log.md` 제외, packet 산출물은 미러 안 `_packet/`에 둔다. **리뷰어에게 주는 것은 `$PKT`(= 미러의 `_packet/`)뿐이고 `$RES`(codex 출력·워커 회수물·로그)는 주지 않는다.** **보안 스캔(§5①)은 packet 전체 + 미러 전체**에 적용하고, 통과한 동일 입력을 양쪽에 제공 — 비대칭 입력이 불가피하면 결과 신뢰도에 명시.

```bash
# repo 루트에서 실행(하위 cwd면 untracked 수집이 잘린다). 함수는 현재 셸에서 돌아 실패해도 셸이 죽지 않고 $OUT/$PKT/$RES/$mirror가 남는다
set -o pipefail; OUT=$(mktemp -d); PKT="$OUT/packet"; RES="$OUT/results"; mkdir -p "$PKT" "$RES"
#   OUT·mirror는 반드시 repo 밖 — repo 안에 두면 packet 산출물이 untracked로 잡혀 자기 자신을 읽는다
BASE=<페이즈 시작 SHA>; TASK=docs/plans/<날짜>/<작업>; MAX_F=1048576; MAX_T=5242880   # 상한은 untracked 한정
mkpacket() {
  git diff --stat "$BASE" -- . ":(exclude)$TASK/log.md"        # ① 크기 점검 → 대용량 binary는 ':(exclude)<path>' 추가
  git diff --binary "$BASE" -- . ":(exclude)$TASK/log.md" > "$PKT/packet-diff.md"    # ① base vs index+작업트리
  : > "$OUT/untracked-included.txt"
  git ls-files --others --exclude-standard -z |                # ② untracked (index 무변경)
    { tot=0; while IFS= read -r -d '' f; do
        case "$f" in "$TASK"/log.md) continue;; esac           # 리뷰 ledger·메인 판단 차단
        sz=$(stat -c %s "$f" 2>/dev/null || echo 0); echo "### untracked: $f ($sz B)"
        if   [ -L "$f" ];   then echo "symlink: $f -> $(readlink "$f")"
        elif [ ! -f "$f" ]; then echo "special: $f ($(stat -c %F "$f"))"
        elif [ "$sz" -gt "$MAX_F" ] || [ $((tot+sz)) -gt "$MAX_T" ]; then echo "packet truncated (목록만): $f"
        elif [ -s "$f" ] && file -b --mime-encoding "$f" | grep -q binary; then echo "binary: $f ($(file -b "$f"))"
        else tot=$((tot+sz)); echo "$f" >> "$OUT/untracked-included.txt"
             git diff --no-index /dev/null "$f" || { rc=$?; [ "$rc" -le 1 ] || echo "packet error: $f (rc=$rc)"; }
        fi
      done; } >> "$PKT/packet-diff.md"
  # ④ 탐색 힌트 — 명령 원문과 원시 결과를 그대로 (메인 해석 금지)
  git grep -n --untracked '<변경 심볼>' -- . ':(exclude)'"$TASK"/log.md > "$PKT/packet-related-raw.txt"
  # ⑥ read-only 미러 — tracked 정규 파일(심링크·삭제분·gitlink 제외) + ②에서 본문을 붙인 untracked만
  mirror=$(mktemp -d)
  git ls-files -z -- . ":(exclude)$TASK/log.md" \
    | { while IFS= read -r -d '' f; do [ -L "$f" ] && continue; [ -f "$f" ] || continue; printf '%s\0' "$f"; done; } \
    | tar --null -T - -cf - | tar -xf - -C "$mirror" || { echo "mirror 생성 실패"; rm -rf "$mirror"; return 1; }
  while IFS= read -r f; do install -D -m 0444 "$f" "$mirror/$f" || { echo "mirror 복사 실패: $f"; rm -rf "$mirror"; return 1; }; done < "$OUT/untracked-included.txt"
  for q in "$PKT"/*; do install -D -m 0444 "$q" "$mirror/_packet/${q##*/}" || { echo "_packet 복사 실패: $q"; rm -rf "$mirror"; return 1; }; done
}
mkpacket || echo "packet 생성 실패 — 위 메시지 확인"
set +o pipefail
#   $PKT = 리뷰어 제공물(packet-diff·related-raw·spec 원문) → 미러의 _packet/ 로만 전달 / $RES = codex 출력·워커 회수물·로그(리뷰어에 주지 않는다)
#   _packet/엔 공통 packet만 — 프롬프트는 각 호출의 stdin·Agent 프롬프트로만 주고 다른 리뷰어의 프롬프트·출력은 넣지 않는다(①단계 원문 격리)
#   ignored(.env 등)·.git·~/.claude·대화 저장소·log.md는 미러에 없다. §5① 스캔을 미러 전체에 돌린 뒤 전달. 리뷰 종료 후: rm -rf "$mirror"
```

- **⓪′ spec 기준 판정 (구현이 아닌 spec)**: packet ③는 **spec 원문**이며, 리뷰어 프롬프트에 "구현이 그럴듯한가가 아니라 **spec과 일치하는가**로 판정하라"를 명시한다 — 잘못된 구현을 "의도대로"로 오검증한 사고(03c 관찰)를 spec 원문 대조로 차단. 구현 diff는 "무엇이 바뀌었나"의 근거일 뿐, 정답의 기준이 아니다.
- **① 병렬 리뷰**: Opus 워커(Agent 호출, model: opus) ∥ codex(`codex exec` — §5②). **리뷰어는 packet + read-only 미러를 받고, 원 repo가 아니라 미러를 탐색한다** — packet-only가 아니라 **미러-only**다. 미러 = tracked 작업트리 내용 + 승인된 untracked 정규 파일이며 **ignored 파일(`.env` 등)·`.git`·`~/.claude`·대화 저장소는 미러에 없다**(⓪ ⑥). Opus 워커는 미러 경로에서 Read/Grep/Glob 허용·**Edit/Write/Bash 쓰기 금지**, codex는 **cwd=미러**(§5②) — 양쪽 프롬프트에 **"미러(`_packet/` 포함) 밖 읽기 금지"**를 명시하고 리뷰 종료 후 미러를 삭제한다. **리뷰어에게 주는 문서는 spec 원문뿐** — `log.md`(리뷰 ledger)·`measurement-log`·대화 요약은 주지 않는다. `_packet/`엔 공통 packet만 두고 **프롬프트는 각 호출의 stdin·Agent 프롬프트로만** 전달한다 — 다른 리뷰어의 프롬프트·출력은 넣지 않는다(①단계 원문 격리). **절단 계약의 본질은 파일 차단이 아니라 맥락 차단이다** — 리뷰어에게 주지 않는 것: 대화 맥락·구현 의도·메인의 사전 판단·(①단계에서) 다른 리뷰어의 원문. 이 금지는 **워커 브리핑 본문에도 적용된다** — 점검 대상 지목은 spec 조항 인용으로만 하고, 가설 목록·"특히 …가 의심된다" 류는 쓰지 않는다. packet 밖 미러 파일을 근거로 쓴 finding은 **`file:line` 필수**(메인이 재현할 수 있어야 채택 — §2 자격조건 ②). 비대칭 플래그는 **한쪽만 미러 접근이 가능했던 경우**에만 붙인다.
- **① 실패 분기**: 한쪽 실패 시 1회 재시도 → 그래도 실패면 **`review blocked`** — 정상 종료 불가. 같은 packet으로 동등한 대체 독립 리뷰어를 실행하면 루프 계속 가능. 사용자가 단일 리뷰 진행을 명시 승인하면 **`user override`로 기록**하고 잔여 리스크를 보고 — 머지 가부는 사용자 결정 (높음 codex 스킵 불가 — core §4).
- **② 메인 종합**: 중복 병합 + finding별 채택/기각. **허용 근거는 packet + 미러 실파일(`file:line` — 원 repo와 동일 내용)로 제한** — 기각 사유도 file:line 또는 spec 조항에 귀속. **대화 맥락·숨은 구현 의도는 근거로 쓰지 않는다** (절단 계약 보호).
- **③ codex 종합 감사 (1회)**: 입력 = packet + 양 리뷰 원문 + 메인 채택/기각표. 역할은 "메인 판정 오류·누락 후보 지적"까지 — codex가 자기 finding의 기각을 재검토하는 것이므로 **독립 리뷰 1표가 아니라 종합 품질 감사**다. 추가 왕복 금지.
- **④ 수정 → 테스트**: core §4 검증대로. finding 재현 테스트는 **"fix verification test"로 분류** — blind 테스트 설계(구현 diff 미열람 계약)와 구분하고, 그 계약을 소급 오염시키지 않는다.
- **⑤ 재리뷰**: ①로 복귀. 입력은 갱신된 누적 diff packet.

**종료 조건 (높음 — 반복 루프)**: `open(채택·미수정) finding 0` **AND** `이번 루프 신규 채택 finding 0` **AND** `대칭 부담 충족(§2)`. **최대 3루프** — 초과 시 `review unresolved`로 중단하고 미해소 finding·기각 목록·잔여 리스크·필요한 사용자 결정을 보고한다 (해소 또는 사용자 보류 결정 전 머지 불가).

- **中 변형 (듀얼 1패스 — 반복 루프 없음)**: 中 stakes는 ⓪~④를 1회 수행하고 **⑤ 재리뷰 반복을 하지 않는다**. ④ 수정 후 **post-fix 타깃 재점검 1회**(채택 finding을 고친 hunks + 인접 호출부 + 새 테스트만 — codex 또는 Opus 워커 중 하나가 재검토하되 **독립성 위해 원 수정 근거를 낸 쪽이 아닌 리뷰어 권장(codex 우선)**, 종합 감사 재실행 없음, 전체 packet 재리뷰 아님)로 수정-새결함을 차단한다. **中 종료 조건**: `채택 finding 전부 fixed` + `post-fix 재점검 clean(신규 finding 0)` + core §4 최소 안전선 + **대칭 부담(§2 — 이 신규 0 상태에 적용)**. 설계 선검증·blind 테스트 워커는 中 비대상(高 전용 — 中 테스트는 core §4대로 spec-우선 + 테스트 코드 자체 정합성 점검). 진행 중 설계 리스크가 드러나면(테스트 설계 막힘·불변식 한 문장 설명 실패·변경 확산 — core §3) **높음 승격**, 이미 수행한 듀얼 1패스를 높음 루프 **1회차로 인정**(처음부터 다시 X).

## 2. finding 규칙

- **자격 조건 (전부 충족해야 finding)**: ① 현재 diff가 도입·변경한 **산출물**(코드·문서·정책 등) ② **근거 위치** — `file:line`(**packet 밖 미러 파일도 `file:line`을 적으면 허용** — 메인 재현 가능성이 조건), 또는 "diff에 *없는 것*"(완전성·통합 렌즈) finding은 누락 산출물 경로·deploy 단계·runtime 계약 형식 허용 ③ 실질 리스크(코드=정확성·성능·유지보수 / 문서·정책=정확성·일관성·운영·유지보수 중 무엇인지 명시) ④ spec 또는 변경 의도와의 연결. 하나라도 없으면 "범위 밖" 또는 open question — 단순 선호·취향은 finding이 아니다.
- **상태 ledger** (필수 필드 — 종료 판정의 입력): `id / first_seen_loop / source(opus·codex·감사·main-synthesis) / 근거(file:line, 또는 diff-밖 finding은 누락 경로·deploy·runtime 계약) / disposition(채택·기각·범위 밖·open question) / status(open·fixed·user-deferred·unresolved) / fixed_in_loop`. 기록 위치: **작업 폴더 `log.md`의 리뷰 ledger 섹션**(`templates/log.md` — 이 스키마의 인스턴스 + finding별 실질 내용. core §7). **종료식**: open = disposition=채택 AND status=open / 신규 채택 = first_seen_loop=현재 루프 AND disposition=채택. **finding 단위**: 같은 `file:line`·같은 불변식 위반은 1건(출처가 둘이면 source 병기) — 쪼개거나 합쳐 종료식을 조작하지 않는다. 코드 변경 없이 테스트만 추가한 수정도 재점검 대상. **메인 종합 중 양 리뷰 비교로 발견한 결함**은 `source: main-synthesis`로 등록 — 독립 신호는 아니나 유효 finding(귀속·자격은 동일).
- **대칭 부담 (신규 채택 finding 0인 루프 — 무근거 통과 차단)**: finding 0을 종료로 인정하려면 §3 렌즈마다 **applicable / not-applicable을 근거 1줄로 판정**하고(예: "동시성 = N/A: 단일 인스턴스 read-only"), **applicable 렌즈를 전부 `verified`로 입증**한다. **고정 개수 요구 없음** — 적용 안 되는 렌즈를 형식 충족용으로 verified 처리하는 것이 더 큰 위반(과거 "필수 finding 강제 → 날조" 재현). **verified ledger 필드**: `lens / 근거(file:line, 또는 "diff에 *없는 것*" 렌즈는 누락 산출물 경로·deploy 단계·runtime 계약 허용) / how(충족 방식 1줄) / source(opus·codex)`. 근거는 병렬 리뷰 원문에서 인용(메인 사후 창작 금지). **양쪽 균형**: applicable 렌즈를 Opus·codex가 합쳐서 전부 커버하면 충족 — applicable verified 전체를 통틀어 한 source(opus 또는 codex)의 기여가 0건이면 종료는 가능하되 `비대칭` 플래그로 리스크 기록(편향 공유 가능성). 中·높음 공통, 신규 finding 있는 루프엔 불필요(검사가 이미 입증됨).
- 애매하면 단정하지 않는다 — open question으로 남긴다 ("이 컬렉션의 최대 크기는 어디서 제한되나?").

## 3. 판단 렌즈 (리뷰는 diff 기반, 판단은 이 레벨로 — 설계 시에도 선적용)

> diff 정확성(아래 처음 4렌즈)만 보면 **"빠진 능력"을 못 잡는다** — 완전성·운영성 렌즈는 diff 안에 *없는 것*을 본다(codex 가 약한 지점, 독립 리뷰어가 메우는 관점).

| 렌즈 | 판단 질문 |
|------|----------|
| **API 단위** | 전체 프로세스에서 발생 가능한 예외와 전파 경로가 처리되나 — 입력 오류·권한·의존 실패·타임아웃·부분 실패. 예외가 계약된 형태로 드러나나(무음 실패 없음) |
| **메서드 내부** | 알고리즘 설계가 입력 규모·서버 자원·속도에 적절한가(§4 체크리스트) · 정상/예외 흐름이 분리되어 있나 · 예외 처리가 기존 전략과 일관된가 |
| **네이밍** | 메서드/함수명이 도메인을 직관적으로 드러내나 — 이름만 읽고 행동·부작용을 예측할 수 있나 |
| **리포지토리/쿼리** | ORM이 생성하는 쿼리·SQL이 사용 DB의 실행계획·옵티마이저를 고려해 처리되나 — N+1·인덱스 사용·페이징·불필요한 전체 적재 (JPA는 대표 예시 — 표현은 ORM 범용) |
| **완전성·운영성 (diff에 *없는 것*)** | CRUD·기능에 빠진 경로가 없나 — 생성만 있고 조회/수정/복구가 없나 · **public/필터 경로(useYn='Y' 등)가 관리자를 가두지 않나** — 숨김·비활성·소프트삭제 데이터의 admin 조회·복구 경로가 있나 · 운영자가 배포 후 상태를 관찰·되돌릴 수 있나 · 통합 단절(이 변경이 옮긴 소스를 다른 경로가 옛 소스로 계속 읽나) |
| **통합·부작용 (이 변경 밖)** | 이 변경이 공유 자원·라이브 데이터·다른 경로에 미치는 부작용 — 공유 테이블 컬럼 무단 덮어쓰기, 식별자/소스 전환이 미처리 경로(비번재설정·부트스트랩·배치)와 단절되나 |
| **설계 품질·취향** | 응집·경계·이름·냄새가 좋은 설계인가 — DDD 용어 일관성·도메인 경계(기술 트랜잭션 ≠ Aggregate) · 이름붙은 코드냄새 · 슬롭↔오버킬 사이에서 판단을 commit했나. 냄새 목록·8앵커·슬롭↔오버킬 예시 카탈로그: `design-taste.md`. **순수 취향·선호는 finding 아님**(§2) — 단정 가능한 냄새·불변식·경계 위반만 |

## 4. 자원·속도 체크리스트 (메서드 내부 렌즈 — 프로파일링 없이 diff만으로 판단)

1. 입력 크기 상한이 spec·validation·pagination·limit·batch로 명시·강제되나?
2. 시간복잡도가 입력 크기로 설명 가능한가 — unbounded 입력에 O(n²)+·중첩 스캔·반복 정렬이 새로 생겼나?
3. 루프 안에서 DB 쿼리·리포지토리 호출·네트워크·파일 I/O·외부 API 호출이 발생하나?
4. 대량 데이터를 한 번에 메모리 적재·복사하나 — streaming/cursor/pagination/chunking 없는 전체 조회·전체 read?
5. fan-out·병렬·async·blocking 호출이 입력 크기만큼 무제한 증가하나 — timeout·동시성 상한·backpressure 있나?
6. 루프마다 불변 작업을 반복하나 — regex compile·파서 생성·직렬화·권한 조회·config fetch?
7. 정상·예외 경로 모두에서 자원이 해제되나 — connection·stream·lock·temp file·트랜잭션 범위 누수?
8. 같은 결과를 더 비싼 알고리즘으로 바꿨나 — 기존 pagination/batching/cache/인덱스 친화 접근을 제거·우회했나?

- **finding 증거 형식**: file:line / 도달 경로(어떤 API·입력이 닿나) / 복잡도 추정(N×M, N번 원격 호출 등) / 입력 규모 가정(상한 또는 "상한 없음" 근거) / 현실적 영향(latency·memory·DB 부하·자원 고갈·timeout 중 무엇) / 완화 부재 사유(limit·batch·cache·timeout이 왜 불충분한지) / 수정 방향(클래스 수준 — batch query·streaming·bounded concurrency·상한 강제. 특정 구현 강요 금지).
- **지적한다**: unbounded 입력에 superlinear 작업·per-item I/O·무제한 fan-out을 신설/악화 · 기존 limit/pagination/batching/cache 제거·우회 · 상한 없이 입력 전체에 비례하는 메모리 적재 · production request path에서 입력 크기만큼 자원(thread·connection·트랜잭션 시간) 점유가 file:line으로 보일 때.
- **넘어간다**: 상한이 작고 코드로 강제되며 그 규모에서 복잡도가 합리적 · one-time migration/admin/startup 경로로 빈도·규모 제한이 spec/code에 보임 · 상수배 미세 최적화·취향 수준 · 입력 규모가 diff/spec에서 증명 안 돼 귀속 불가(→ open question).

## 5. codex 호출 (외부 전송 게이트)

> ①~③은 codex를 실제로 호출하는 절차. §1 ⓪·①의 "보안 스캔·codex 실행"이 이 절을 참조한다.

- **① 보안 스캔 (전송 전 필수)**: **packet 전체(누적 diff·untracked 전문·spec·연관 파일 원시 결과) + 미러 전체**에서 `sk-`·`ghp_`·`AKIA`·`PRIVATE KEY`·`password|token|secret[:=]` 값·PII·내부 호스트/경로를 스캔 — 매칭 0건만 자동 통과, 발견 시 오탐 여부 개별 판정 후 redact(미러 파일은 미러에서 redact) 또는 사용자 확인 — 해소 못 하면 `review blocked`.
- **② 호출**: `cd "$mirror" && cat "$OUT/codex-input.md" | codex exec --skip-git-repo-check --sandbox read-only -c model_reasoning_effort=medium --ephemeral -o "$RES/출력.md" -` (Bash, 백그라운드 권장) — **cwd=미러**(§1 ①), 미러는 git repo가 아니므로 `--skip-git-repo-check`가 필요하다. 출력은 **미러 밖 `$OUT`** 에 받는다(미러는 리뷰 후 삭제되므로 안에 두면 결과가 사라진다). packet은 `_packet/` 아래 있고, 프롬프트에 "미러(`_packet/` 포함) 밖 읽기 금지"를 명시한다.
- **③ 비대화형 PATH 함정**: codex는 nvm 설치라 Claude Bash(비대화형)의 PATH에 안 잡힌다 — `CODEX=$(ls ~/.nvm/versions/node/*/bin/codex 2>/dev/null | head -1)`로 전체 경로를 확보한다(`which codex` 실패 ≠ 미설치).
- **④ 샌드박스 중첩 페널티 (2026-07-20 실측)**: Claude Bash가 이미 외부 샌드박스라, `-s read-only`로 codex를 부르면 codex가 **자체 bubblewrap 샌드박스를 중첩 생성**하려다 user namespace 문제로 모델갱신 자식이 hang → 매 호출 **+~30s** 고정 페널티(`failed to refresh available models: timeout waiting for child process to exit`). 그럼에도 **리뷰는 `--sandbox read-only`로 돈다** — +~30s는 비용으로 수용한다. `read-only`는 **쓰기** 제한이지 읽기 경계가 아니다: 읽기 경계를 만드는 것은 **미러 + 프롬프트 지시**("미러(`_packet/` 포함) 밖 읽기 금지")다. `--dangerously-bypass-approvals-and-sandbox`는 **사용자가 명시 승인한 경우에만** 대안으로 쓰고 `user override`로 기록한다. config `model_reasoning_effort=high`도 리뷰를 느리게 하니 호출 시 `medium`으로 낮춘다(52s→12s 실측). **타임아웃을 너무 짧게(≤4분) 걸면 high-effort 추론을 완주 전 죽인다** — 넉넉히(6분+) 주거나 백그라운드로 회수하라. (codex가 셸 명령을 실제 실행하는 용도라면 bypass 금지 — 리뷰 전용.)
