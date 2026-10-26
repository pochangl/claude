---
name: android-multi-emulator
description: Run several Android emulators at once from one AVD — e.g. two or three devices for multiplayer, chat, sync or push testing, each signed in as a different user. Triggers on "多開 emulator", "多開模擬器", "開兩台/三台模擬器", "multiple emulators", "second emulator", "run the app on two devices", "/android-multi-emulator".
user-invocable: true
---

# Android Multi-Emulator

Boot N instances of one AVD side by side, each with its own adb serial, and
optionally run the app on each. Single-device runs belong to
`flutter-android-run`; this skill covers what changes when there are several.

## Rules

- **Every instance runs `-read-only`, the first one included.** The emulator
  locks a writable AVD, so a second instance of it refuses to start while a
  normal (writable) one is running. If one is already up without
  `-read-only`, ask before killing it (`"$ADB" -s <serial> emu kill`), then
  start them all read-only.
- **Read-only means nothing persists.** Installs, logins and settings are
  lost when an instance shuts down; expect to install and sign in again next
  time.
- **Give each instance its own even port** (`-port 5554`, `5556`, `5558`, …,
  up to 5682). The serial is `emulator-<port>`; the odd port above it is its
  adb port, so never use odd numbers.
- **Launch detached with `setsid … & disown`**, or the emulator dies with the
  shell that started it.
- **Cold-boot with `-no-snapshot`.** Read-only instances resuming the shared
  snapshot can drop off adb.
- **Always pass `-s <serial>` to adb.** With more than one device, a bare
  `adb shell` fails with "more than one device/emulator".
- RAM: each instance takes ~2–4 GB. Check `free -g` before going past three.

## 1. Resolve the SDK and pick the AVD

```bash
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
[ -d "$SDK" ] || SDK="$HOME/Library/Android/sdk"   # macOS default
ADB="$SDK/platform-tools/adb"; EMU="$SDK/emulator/emulator"
"$EMU" -list-avds   # ask if there are several and none is obvious
"$ADB" devices      # what is already running, and on which ports
```

## 2. Boot the instances

Skip ports already listed by `adb devices` as a read-only instance of the
same AVD; reuse those.

```bash
AVD=<avd>; PORTS="5554 5556 5558"
for P in $PORTS; do
  setsid nohup "$EMU" -avd "$AVD" -read-only -port "$P" -no-snapshot \
      > "/tmp/emu-$P.log" 2>&1 < /dev/null & disown
done
```

Wait for all of them, capped at ~4 minutes in total:

```bash
for P in $PORTS; do
  for i in $(seq 1 80); do
    [ "$("$ADB" -s emulator-$P shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break
    timeout 3 tail -f /dev/null
  done
done
"$ADB" devices
```

An instance that never shows up as `device`: report the tail of
`/tmp/emu-<port>.log` and stop rather than looping again.

## 3. Run the app on each

Follow `flutter-android-run` steps 3–5 once per serial, with the tmux session
and log named per device so they don't collide:

```bash
S="$(basename "$PWD")-$P"; LOG="/tmp/flutter-run-$S.log"
: > "$LOG"
tmux new-session -d -s "$S" -c "$PWD" "flutter run -d emulator-$P 2>&1 | tee $LOG; exec bash"
```

Starting the runs one after another (wait for the first build to finish
before starting the next) avoids several Gradle builds racing on the same
`build/` directory; later runs reuse the built APK and start fast.

For a non-Flutter app, install the same APK on each:
`"$ADB" -s emulator-$P install -r <apk>`.

## 4. Drive each device

- Type into a field: tap it, then `"$ADB" -s emulator-$P shell input text <value>`.
- Screenshot one device:
  `"$ADB" -s emulator-$P exec-out screencap -p > /tmp/shot-$P.png`.
- Use a different account on each device when the app identifies people by
  user — the same account on two devices usually shows up as one person
  twice. A project's own test-account skill (e.g. `e4f-test-accounts`) lists
  which accounts to use.

## 5. Report and clean up

Tell the user each serial, its tmux session, and its log path. To shut one
down: `"$ADB" -s emulator-$P emu kill`; all of them:
`for P in $PORTS; do "$ADB" -s emulator-$P emu kill; done`.
