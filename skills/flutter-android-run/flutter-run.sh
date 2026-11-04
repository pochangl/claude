#!/usr/bin/env bash
# Start `flutter run` in a tmux session and wait for it, telling "still
# building" apart from "hung" and "dead" instead of waiting blind.
#
#   flutter-run.sh start <device> [session] [-- extra flutter run flags]
#   flutter-run.sh status <session>
#   flutter-run.sh kill <session>
#
# Run `start` from the Flutter project root. The session defaults to the
# project directory name; the log is /tmp/flutter-run-<session>.log.
#
# Exit codes (start and status):
#   0 app running        1 error in log         2 flutter run exited
#   3 session live       4 stale session        5 hung (no output, no CPU)
#   6 still busy at cap  7 device not online    8 no such session
set -u

STALL=${STALL:-90}    # seconds of no log output AND no CPU use = hung
CAP=${CAP:-480}       # overall wait cap in seconds
EXIT_MARK='__FLUTTER_RUN_EXITED__'
READY_RE='Flutter run key commands|^I/flutter'
FATAL_RE='Lost connection to device|No supported devices'   # fatal even after the app is up
ERROR_RE='^Error:|FAILURE:|Gradle task .* failed'                # fatal only before the app is up

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
[ -d "$SDK" ] || SDK="$HOME/Library/Android/sdk"
ADB="$SDK/platform-tools/adb"

log_of() { echo "/tmp/flutter-run-$1.log"; }
pane_of() { tmux list-panes -t "$1" -F '#{pane_pid}' 2>/dev/null | head -1; }

# Total CPU seconds of the session's processes plus any Gradle daemon (the
# daemon detaches from the build, so it is not a descendant of the pane).
cpu_of() {
  local pane pids
  pane=$(pane_of "$1")
  [ -n "$pane" ] || { echo 0; return; }
  pids=$(ps -e -o pid=,ppid= | awk -v root="$pane" '
    { kids[$2] = kids[$2] " " $1 }
    END { q[1] = root; n = 1; for (i = 1; i <= n; i++) { print q[i]
          split(kids[q[i]], k, " "); for (j in k) if (k[j] != "") q[++n] = k[j] } }')
  pids="$pids $(pgrep -f GradleDaemon | tr '\n' ' ')"
  # shellcheck disable=SC2086
  ps -o cputimes= -p $(echo $pids | tr ' ' ',') 2>/dev/null | awk '{ s += $1 } END { print s + 0 }'
}

# Classify a session from its log: prints a state word, returns its exit code.
classify() {
  local s=$1 log; log=$(log_of "$s")
  tmux has-session -t "$s" 2>/dev/null || { echo missing; return 8; }
  if [ -f "$log" ] && grep -q "$EXIT_MARK" "$log"; then echo exited; return 2; fi
  if [ -f "$log" ] && grep -qE "$FATAL_RE" "$log"; then echo error; return 1; fi
  if [ -f "$log" ] && grep -qE "$READY_RE" "$log"; then echo running; return 0; fi
  if [ -f "$log" ] && grep -qE "$ERROR_RE" "$log"; then echo error; return 1; fi
  # No marker, no banner, nothing running under the pane: an idle prompt left
  # from an older run (or a crashed one) is stale.
  pgrep -P "$(pane_of "$s")" >/dev/null || { echo stale; return 4; }
  echo busy; return 6
}

report() {
  local s=$1 state=$2 log; log=$(log_of "$s")
  echo "== session=$s state=$state log=$log"
  [ -f "$log" ] && tail -15 "$log"
}

wait_for() {
  local s=$1 log start last_size=-1 last_cpu=-1 quiet_since state code size cpu now
  log=$(log_of "$s"); start=$(date +%s); quiet_since=$start
  while :; do
    state=$(classify "$s"); code=$?
    [ "$state" = busy ] || { report "$s" "$state"; return $code; }
    now=$(date +%s)
    size=$(stat -c %s "$log" 2>/dev/null || echo 0); cpu=$(cpu_of "$s")
    if [ "$size" != "$last_size" ] || awk -v a="$cpu" -v b="$last_cpu" 'BEGIN { exit !(a - b > 1) }'; then
      quiet_since=$now; last_size=$size; last_cpu=$cpu
    fi
    if [ $((now - quiet_since)) -ge "$STALL" ]; then
      report "$s" "hung: no output and no CPU for ${STALL}s"; return 5
    fi
    if [ $((now - start)) -ge "$CAP" ]; then
      report "$s" "still busy after ${CAP}s (output or CPU still moving)"; return 6
    fi
    timeout 5 tail -f /dev/null
  done
}

cmd=${1:-}; shift || true
case "$cmd" in
  start)
    dev=${1:?device id}; s=${2:-$(basename "$PWD")}; shift 2 2>/dev/null || shift
    [ "${1:-}" = -- ] && shift
    [ "$("$ADB" -s "$dev" get-state 2>/dev/null)" = device ] || { echo "device $dev not online"; "$ADB" devices; exit 7; }
    if tmux has-session -t "$s" 2>/dev/null; then
      state=$(classify "$s"); code=$?
      report "$s" "$state (already exists; not starting another)"
      [ "$state" = stale ] || [ "$state" = exited ] && echo "kill it with: $0 kill $s"
      exit $(( code == 0 || code == 6 ? 3 : code ))
    fi
    log=$(log_of "$s"); : > "$log"
    tmux new-session -d -s "$s" -c "$PWD" \
      "{ flutter run -d $dev $*; echo \"$EXIT_MARK \$?\"; } 2>&1 | tee $log; exec bash" \
      || { echo "tmux new-session failed"; exit 2; }
    wait_for "$s" ;;
  status)
    s=${1:?session}; state=$(classify "$s"); code=$?
    if [ "$state" = busy ]; then STALL=${STALL_STATUS:-15} CAP=${STALL_STATUS:-15}; wait_for "$s"; exit $?; fi
    report "$s" "$state"; exit $code ;;
  kill)
    s=${1:?session}; tmux kill-session -t "$s" && echo "killed $s" ;;
  *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 64 ;;
esac
