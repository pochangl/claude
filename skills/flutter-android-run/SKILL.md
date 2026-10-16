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
- **Every wait loop has a cap** and prints the log tail when it gives up,
  instead of waiting silently. Do not use bare foreground `sleep`; use
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

## 3. Start `flutter run` in tmux

Name the session and log after the project directory so several projects can
run side by side. If the session already exists, ask before killing it — the
user may be using it.

```bash
S=$(basename "$PWD"); LOG="/tmp/flutter-run-$S.log"; DEV=<device id from step 2>
tmux has-session -t "$S" 2>/dev/null && echo "session $S already exists"
: > "$LOG"
tmux new-session -d -s "$S" -c "$PWD" "flutter run -d $DEV 2>&1 | tee $LOG; exec bash"
```

Add project-specific flags (`--flavor`, `-t lib/main_dev.dart`,
`--dart-define`) when the project's CLAUDE.md or build scripts call for them.

## 4. Wait for the app, from the log

The first build can take several minutes; later ones are much faster. Cap the
wait at ~6 minutes:

```bash
for i in $(seq 1 72); do
  grep -qE 'Flutter run key commands|^I/flutter|Error:|FAILURE|Exception' "$LOG" && break
  timeout 5 tail -f /dev/null
done
tail -15 "$LOG"
```

- `Flutter run key commands` or `I/flutter` lines → the app is running.
- `Error:` / `FAILURE` / `Exception` → report the error lines from the log.
- Neither after the cap → report the log tail; do not start another loop
  without telling the user.

## 5. Report

Tell the user the device, the tmux session name (`tmux attach -t <S>` for
`r` hot reload / `R` hot restart / `q` quit), and the log path. To send a key
without attaching: `tmux send-keys -t <S> r`.
