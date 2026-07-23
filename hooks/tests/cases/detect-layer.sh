# detect-layer.sh 테스트 — Claude Code 훅 3종(InstructionsLoaded·ConfigChange·SubagentStop) 관측 기록기
# 헬퍼: lib.sh (run_hook·run_hook_stdout·write_state·write_sidecar·assert_*·sandbox 변수)
# 주의: 사이드카는 $STATE_DIR/$SID.events (상태파일 $STATE·$SIDECAR 와 별개). CWD=.cwd=$REPO.
# 관례: sandbox_init 은 run.sh 러너가 각 테스트 앞에서 호출한다 — 케이스 함수는 호출하지 않는다.
# 설계: blind 워커(구현 미열람 계약 — spec·프로브 실측 JSON에서 출발), 통합: 메인.

# ── 케이스 전용 JSON 빌더 (lib.sh json_* 는 detect-layer 이벤트 형태가 아님 — 여기서 자체 정의)
dl_il() { # <file_path> <load_reason> <memory_type> [parent_file_path]
  if [ -n "${4:-}" ]; then
    jq -cn --arg s "$SID" --arg c "$REPO" --arg f "$1" --arg r "$2" --arg m "$3" --arg p "$4" \
      '{session_id:$s,cwd:$c,hook_event_name:"InstructionsLoaded",file_path:$f,memory_type:$m,load_reason:$r,parent_file_path:$p}'
  else
    jq -cn --arg s "$SID" --arg c "$REPO" --arg f "$1" --arg r "$2" --arg m "$3" \
      '{session_id:$s,cwd:$c,hook_event_name:"InstructionsLoaded",file_path:$f,memory_type:$m,load_reason:$r}'
  fi
}
dl_cc() { # <source> <file_path>
  jq -cn --arg s "$SID" --arg c "$REPO" --arg src "$1" --arg f "$2" \
    '{session_id:$s,cwd:$c,prompt_id:"p1",hook_event_name:"ConfigChange",source:$src,file_path:$f}'
}
dl_sas() { # <agent_type> <agent_id> <last_assistant_message>
  jq -cn --arg s "$SID" --arg c "$REPO" --arg at "$1" --arg id "$2" --arg msg "$3" \
    '{session_id:$s,cwd:$c,prompt_id:"p1",permission_mode:"default",agent_id:$id,agent_type:$at,
      hook_event_name:"SubagentStop",stop_hook_active:false,last_assistant_message:$msg,
      background_tasks:[],session_crons:[]}'
}

# ── 케이스 전용 헬퍼
dl_ev() { echo "$STATE_DIR/$SID.events"; }                       # 기본 sid 의 사이드카 경로
dl_nlines() { grep -c '' "$1" 2>/dev/null || true; }            # 레코드 수(마지막 개행 유무 무관)
dl_grep_re() { grep -qE "$2" "$1" 2>/dev/null || fail "$3"; }   # <file> <ERE> <id>
dl_ngrep_re() { if grep -qE "$2" "$1" 2>/dev/null; then fail "$3"; fi; }
# process cwd 를 지정해 훅 실행(.cwd 부재 시 $PWD 폴백 검증용 — $PWD 오염을 sandbox 안으로 가둔다)
dl_run_in() { # <dir> <hook> <json>
  set +e
  HOOK_STDERR=$(cd "$1" && printf '%s' "$3" | env HOME="$HOME_DIR" GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" bash "$HOOKS_DIR/$2" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
}
# jq 미존재 PATH 로 실행(inert 계약 검증). env -i 로 환경 청소, PATH 는 빈 디렉토리.
dl_run_nopath() { # <hook> <json>
  local eb="$SANDBOX/emptybin"; mkdir -p "$eb"
  set +e
  HOOK_STDERR=$(printf '%s' "$2" | env -i HOME="$HOME_DIR" PATH="$eb" "${BASH:-/bin/bash}" \
    "$HOOKS_DIR/$1" 2>&1 >/dev/null)
  HOOK_EXIT=$?
  set -e
}

# ── ① 3이벤트 정상 기록 (형식 정합: epoch|태그|요지) ─────────────────────────
test_dl_il_line() { # InstructionsLoaded + parent 있음
  local ev; ev=$(dl_ev)
  run_hook detect-layer.sh "$(dl_il /home/jun/.claude/core.md include User /home/jun/.claude/CLAUDE.md)"
  assert_exit 0 dl-il-exit
  assert_file_contains "$ev" '|IL|/home/jun/.claude/core.md reason=include type=User parent=/home/jun/.claude/CLAUDE.md' dl-il-line
  dl_grep_re "$ev" '^[0-9]+\|IL\|' dl-il-epoch
}

test_dl_il_noparent() { # parent 없는 변형(session_start) — parent= 세그먼트 미출력
  local ev; ev=$(dl_ev)
  run_hook detect-layer.sh "$(dl_il /home/jun/.claude/CLAUDE.md session_start User)"
  assert_exit 0 dl-ilnp-exit
  assert_file_contains "$ev" '|IL|/home/jun/.claude/CLAUDE.md reason=session_start type=User' dl-ilnp-line
  assert_file_not_contains "$ev" 'parent=' dl-ilnp-noparent
}

test_dl_cc_line() { # ConfigChange
  local ev; ev=$(dl_ev)
  run_hook detect-layer.sh "$(dl_cc local_settings /home/jun/.claude/settings.local.json)"
  assert_exit 0 dl-cc-exit
  assert_file_contains "$ev" '|CC|local_settings /home/jun/.claude/settings.local.json' dl-cc-line
  dl_grep_re "$ev" '^[0-9]+\|CC\|' dl-cc-epoch
}

test_dl_sas_line() { # SubagentStop — msg[원문길이]=앞120자
  local ev; ev=$(dl_ev)
  run_hook detect-layer.sh "$(dl_sas general-purpose ab923fd23ab3083ac DONE)"
  assert_exit 0 dl-sas-exit
  assert_file_contains "$ev" '|SAS|general-purpose id=ab923fd23ab3083ac msg[4]=DONE' dl-sas-line
  dl_grep_re "$ev" '^[0-9]+\|SAS\|' dl-sas-epoch
}

# ── ② 하드 불변식: 어떤 입력·실패에서도 exit 0 ─────────────────────────────
test_dl_broken_json() { # 깨진 JSON
  run_hook detect-layer.sh '{broken json'
  assert_exit 0 dl-broken-exit
}

test_dl_empty_stdin() { # 빈 stdin
  run_hook detect-layer.sh ''
  assert_exit 0 dl-empty-exit
}

test_dl_missing_sid() { # session_id 부재 → 기록 없이 exit 0
  local j; j=$(jq -cn --arg c "$REPO" '{cwd:$c,hook_event_name:"ConfigChange",source:"s",file_path:"/x"}')
  run_hook detect-layer.sh "$j"
  assert_exit 0 dl-nosid-exit
  ! ls "$STATE_DIR"/*.events >/dev/null 2>&1 || fail dl-nosid-noevents
}

test_dl_empty_sid() { # session_id="" (sanitize 후 빈 sid) → 기록 없이 exit 0
  local j; j=$(jq -cn --arg c "$REPO" '{session_id:"",cwd:$c,hook_event_name:"ConfigChange",source:"s",file_path:"/x"}')
  run_hook detect-layer.sh "$j"
  assert_exit 0 dl-emptysid-exit
  ! ls "$STATE_DIR"/*.events >/dev/null 2>&1 || fail dl-emptysid-noevents
}

test_dl_unknown_event() { # 미지 hook_event_name → 기록 없이 exit 0
  local ev; ev=$(dl_ev)
  local j; j=$(jq -cn --arg s "$SID" --arg c "$REPO" '{session_id:$s,cwd:$c,hook_event_name:"PreToolUse",tool_name:"Bash"}')
  run_hook detect-layer.sh "$j"
  assert_exit 0 dl-unknown-exit
  [ ! -e "$ev" ] || fail dl-unknown-noevents
}

test_dl_missing_cwd_fallback() { # .cwd 부재 → $PWD 폴백 + exit 0 (오염은 sandbox 안으로 가둠)
  local ev; ev=$(dl_ev)
  local j; j=$(jq -cn --arg s "$SID" '{session_id:$s,hook_event_name:"ConfigChange",source:"s",file_path:"/x"}')
  dl_run_in "$REPO" detect-layer.sh "$j"     # process cwd=$REPO → 폴백 대상도 $REPO
  assert_exit 0 dl-nocwd-exit
  assert_file_contains "$ev" '|CC|s /x' dl-nocwd-fallback-line
}

test_dl_no_jq_inert() { # jq 없는 PATH → 파싱 불가라도 inert exit 0
  dl_run_nopath detect-layer.sh "$(dl_cc s /x)"
  assert_exit 0 dl-nojq-exit
}

# ── ③ sanitize(개행·탭·|→공백) + 120자 절단 ────────────────────────────────
test_dl_sanitize_msg() { # last_assistant_message 의 개행·탭·| 가 행 구조를 깨지 않음
  local ev; ev=$(dl_ev)
  local msg; msg=$(printf 'line1\nline2\ttab|pipe end')
  run_hook detect-layer.sh "$(dl_sas general-purpose id1 "$msg")"
  assert_exit 0 dl-san-exit
  local n; n=$(dl_nlines "$ev")
  [ "$n" = "1" ] || { echo "  [dbg] lines=$n"; fail dl-san-oneline; }   # 임베드 개행이 행을 쪼개지 않음
  dl_grep_re "$ev" '^[0-9]+\|SAS\|general-purpose id=id1 msg\[' dl-san-prefix
  local pipes; pipes=$(grep -o '|' "$ev" | wc -l || true)
  [ "$pipes" = "2" ] || { echo "  [dbg] pipes=$pipes"; fail dl-san-pipe; }  # 구조상 | 2개뿐(값 내부 | 제거됨)
  dl_ngrep_re "$ev" $'\t' dl-san-tab                                        # 값 내부 탭 제거됨
}

test_dl_truncate_120() { # 원문길이 기록 + 저장은 앞 120자
  local ev; ev=$(dl_ev)
  local long; long=$(printf 'A%.0s' {1..300})
  run_hook detect-layer.sh "$(dl_sas general-purpose id2 "$long")"
  assert_exit 0 dl-trunc-exit
  assert_file_contains "$ev" 'msg[300]=' dl-trunc-origlen
  # 발췌 길이는 msg[300]= 뒤만 측정 — 태그 'SAS'의 A가 grep -o 'A+' 집계에 섞이는 blind 설계 맹점 교정
  local as; as=$(sed 's/.*msg\[300\]=//' "$ev" | tr -d '\n' | wc -c || true)
  [ "$as" = "120" ] || { echo "  [dbg] excerpt len=$as"; fail dl-trunc-120; }
}

# ── ④ 캡: append 전 ≥400 → 최신 200행만 남기고 압축 후 append ────────────────
test_dl_cap_compress() { # 400행 선재 → 압축(200) + append(1) = 201
  local ev; ev=$(dl_ev)
  local i; for i in $(seq 1 400); do printf '%d|CC|seed p%d END\n' "$i" "$i" >> "$ev"; done
  run_hook detect-layer.sh "$(dl_cc newsrc /newpath)"
  assert_exit 0 dl-cap-exit
  [ -f "$ev" ] || fail dl-cap-nofile
  local n; n=$(dl_nlines "$ev")
  [ "$n" = "201" ] || { echo "  [dbg] lines=$n"; fail dl-cap-count; }
  assert_file_not_contains "$ev" 'p50 END'  dl-cap-oldest-dropped   # 최신 200(=201..400) 밖 → 제거
  assert_file_not_contains "$ev" 'p200 END' dl-cap-boundary-dropped
  assert_file_contains     "$ev" 'p201 END' dl-cap-boundary-kept    # 경계 안쪽 잔존
  assert_file_contains     "$ev" 'p400 END' dl-cap-newest-kept
  assert_file_contains     "$ev" '|CC|newsrc /newpath' dl-cap-appended
}

test_dl_no_compress_under_cap() { # 399행 선재 → 압축 없음, append 만 = 400
  local ev; ev=$(dl_ev)
  local i; for i in $(seq 1 399); do printf '%d|CC|seed p%d END\n' "$i" "$i" >> "$ev"; done
  run_hook detect-layer.sh "$(dl_cc newsrc /newpath)"
  assert_exit 0 dl-nocap-exit
  local n; n=$(dl_nlines "$ev")
  [ "$n" = "400" ] || { echo "  [dbg] lines=$n"; fail dl-nocap-count; }
  assert_file_contains "$ev" 'p1 END' dl-nocap-oldest-kept          # 압축 안 됐으므로 최고참 잔존
  assert_file_contains "$ev" '|CC|newsrc /newpath' dl-nocap-appended
}

# ── ⑤ 불가침: 상태파일 $STATE·사이드카 $SIDECAR 무변경 ──────────────────────
test_dl_state_untouched() {
  write_state auto 0 1 1
  write_sidecar 5 12345 'prompt body here'
  local bs bp; bs=$(cat "$STATE"); bp=$(cat "$SIDECAR")
  run_hook detect-layer.sh "$(dl_sas general-purpose id9 hello)"
  assert_exit 0 dl-immut-exit
  [ "$(cat "$STATE")" = "$bs" ]   || fail dl-immut-state
  [ "$(cat "$SIDECAR")" = "$bp" ] || fail dl-immut-sidecar
  assert_file_contains "$(dl_ev)" '|SAS|general-purpose id=id9' dl-immut-did-record  # 제 일은 했음
}

# ── ⑥ 동시성: 병렬 N회 → 행 손상 없음(각 행 패턴 정합) ────────────────────────
test_dl_concurrency() {
  local ev; ev=$(dl_ev)
  local n=20 i
  for i in $(seq 1 "$n"); do
    printf '%s' "$(dl_cc "s$i" "/p$i")" | env HOME="$HOME_DIR" GIT_CONFIG_NOSYSTEM=1 \
      GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$XDG_DIR" bash "$HOOKS_DIR/detect-layer.sh" \
      >/dev/null 2>&1 &
  done
  wait
  [ -f "$ev" ] || fail dl-conc-nofile
  local bad; bad=$(grep -cvE '^[0-9]+\|(IL|CC|SAS)\|' "$ev" || true)
  [ "$bad" = "0" ] || { echo "  [dbg] bad lines=$bad"; fail dl-conc-corrupt; }   # 찢긴/뒤섞인 행 없음
  local total; total=$(dl_nlines "$ev")
  [ "$total" -ge 1 ]   || fail dl-conc-progress                                  # 최소 1건은 기록(진전)
  [ "$total" -le "$n" ] || { echo "  [dbg] total=$total > $n"; fail dl-conc-nodup; }  # 유령 증식 없음
}

# ── sid sanitize / path-traversal 방어 ──────────────────────────────────────
test_dl_sid_sanitize() { # session_id 의 / . | → 제거(tr -cd 'A-Za-z0-9_-'), 경로 이탈 없음
  local raw='aa/../bb|cc' san='aabbcc'
  local j; j=$(jq -cn --arg s "$raw" --arg c "$REPO" '{session_id:$s,cwd:$c,hook_event_name:"ConfigChange",source:"s",file_path:"/x"}')
  run_hook detect-layer.sh "$j"
  assert_exit 0 dl-sidsan-exit
  [ -f "$STATE_DIR/$san.events" ] || fail dl-sidsan-file
  [ ! -e "$REPO/.claude/aa" ]     || fail dl-sidsan-notraversal
}

# ── ⑦ stdout 무출력 ─────────────────────────────────────────────────────────
test_dl_no_stdout() {
  run_hook_stdout detect-layer.sh "$(dl_sas general-purpose idz hi)"
  assert_exit 0 dl-nostdout-exit
  [ -z "$HOOK_STDOUT" ] || { echo "  [dbg] stdout=$(printf '%s' "$HOOK_STDOUT" | head -c 120)"; fail dl-nostdout-empty; }
}
