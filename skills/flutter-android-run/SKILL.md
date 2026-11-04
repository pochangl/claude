---
name: flutter-android-run
description: Start a Flutter app on an Android emulator (or connected phone) inside a tmux session, with hot reload available. Triggers on "start app in emulator", "run the app on android", "flutter run in tmux", "啟動 app", "開模擬器跑 app", "/flutter-android-run".
user-invocable: true
---

# Flutter Android Run

Boot (or reuse) an Android device, start `flutter run` in a detached tmux
session, and report once the app is actually running. Run every command from
the Flutter project root (the directory with `pubspec.yaml`).

## Rules that keep this from hanging

- **Never assume `adb` / `emulator` are on PATH.** Resolve them from the SDK
  (step 1) and call them by full path.
- **Never poll the tmux screen.** `tmux capture-pane -p` returns only the
  visible lines; app logs scroll the "ready" banner into scrollback and a
  screen-grepping loop waits forever. Pipe `flutter run` through `tee` to a
  log file and grep the file.
- **Every wait has a cap and a hang check.** `flutter-run.sh` (step 3) does
  both; any other wait loop (e.g. emulator boot) gets a cap and prints what it
  saw when it gives up, instead of waiting silently. Do not use bare foreground `sleep`; use
  `timeout N tail -f /dev/null` as the delay.

## 1. Resolve the SDK tools

```bash
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
[ -d "$SDK" ] || SDK="$HOME/Library/Android/sdk"   # macOS default
ADB="$SDK/platform-tools/adb"; EMU="$SDK/emulator/emulator"
"$ADB" version >/dev/null || echo "adb not found under $SDK"
```

## 2. Pick a device

```bash
"$ADB" devices    # an emulator-XXXX or phone already listed as "device"? use it, skip to step 3
"$EMU" -list-avds # otherwise pick an AVD (ask if there are several and none is obvious)
```

Boot the AVD detached so the command returns immediately, then wait at most
~3 minutes for boot:

```bash
nohup "$EMU" -avd <avd> >/dev/null 2>&1 &
for i in $(seq 1 60); do
  [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break
  timeout 3 tail -f /dev/null
done
"$ADB" devices
```

If it still isn't booted, report that and stop rather than looping again.

## 3. Start `flutter run` and wait — with `flutter-run.sh`

Never hand-roll the tmux launch or the wait loop: use the bundled script,
which is the one place that knows how to tell "still building" from "hung"
from "dead". From the project root:

```bash
F=~/.claude/skills/flutter-android-run/flutter-run.sh
$F start <device> [session] [-- extra flutter run flags]   # session defaults to the dir name
```

It refuses to start over an existing session (reporting whether that session
is live, stale or dead), checks the device is online, runs `flutter run`
through `tee` into `/tmp/flutter-run-<session>.log` with an exit marker, and
then waits until one of these happens, printing the state and log tail:

| Exit | State | What to do |
| --- | --- | --- |
| 0 | running (`Flutter run key commands` / `I/flutter`) | report (step 4) |
| 1 | error (`Error:`, `FAILURE:`, lost connection) | report the error lines |
| 2 | `flutter run` exited | report the log tail |
| 3 | session already exists and is live | reuse it; don't start another |
| 4 | stale session (idle prompt from an older run) | ask, then `$F kill <session>` and start again |
| 5 | **hung**: no log output *and* no CPU use (session + Gradle daemon) for `STALL`s (default 90) | tell the user it's hung; don't wait more |
| 6 | still busy at the `CAP` (default 480s), output or CPU still moving | tell the user, ask whether to keep waiting |
| 7 | device not online | go back to step 2 |

A silent Gradle build is not a hang: the CPU check keeps it "busy". Run the
script in the foreground with a Bash timeout above `CAP` (e.g. 540000 ms).

Add project-specific flags (`--flavor`, `-t lib/main_dev.dart`,
`--dart-define`) after `--` when the project's CLAUDE.md or build scripts call
for them.

**"Is it hung?"** — for any session, answer with `$F status <session>` (same
exit codes; samples for ~20s when the session is still busy) instead of
reading the tmux screen.

## 4. Report

Tell the user the device, the tmux session name (`tmux attach -t <S>` for
`r` hot reload / `R` hot restart / `q` quit), and the log path. To send a key
without attaching: `tmux send-keys -t <S> r`.
