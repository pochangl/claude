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
- **Boot one at a time: wait for `sys.boot_completed` before launching the
  next.** Launched together, only one instance survives and every later one
  dies 6–9 s after launch (see "A second instance keeps dying").
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

Launch each one only after the one before it has booted, capped at ~2 minutes
per instance. The loop stops as soon as an instance's process disappears
instead of waiting out the cap:

```bash
AVD=<avd>; PORTS="5554 5556 5558"
for P in $PORTS; do
  setsid nohup "$EMU" -avd "$AVD" -read-only -port "$P" -no-snapshot \
      > "/tmp/emu-$P.log" 2>&1 < /dev/null & disown
  for i in $(seq 1 40); do
    [ "$("$ADB" -s emulator-$P shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] \
      && { echo "$P booted"; break; }
    [ "$i" -gt 2 ] && ! pgrep -f "port $P " >/dev/null \
      && { echo "$P died after ~$((i*3))s"; break 2; }
    timeout 3 tail -f /dev/null
  done
done
"$ADB" devices
```

An instance that never shows up as `device`: report the tail of
`/tmp/emu-<port>.log` and stop rather than looping again — unless it died
within seconds, which is the case below.

### A second instance keeps dying

**Symptom.** One instance boots; every other one exits 6–9 s after launch
and never appears in `adb devices`. Its log ends at

```
INFO | Activated packet streamer for uwb emulation
INFO | Activated packet streamer for bluetooth emulation
```

followed by a burst of crash-dump noise (`process_memory_range.cc … read out
of range`, `elf_dynamic_array_reader.h … tag not found`) and no error line.
A healthy instance goes on from there to `Monitoring duration of emulator
setup`. Read the log past the noise with
`grep -v -e process_memory_range -e elf_dynamic /tmp/emu-<port>.log | tail`.

**Cause.** All instances share one `netsimd` (the emulator's Bluetooth/UWB
simulator, spawned by the first instance to start). Launching instances at the
same moment leaves it in a state where later instances crash on connecting to
it; `pgrep -af netsimd` then typically shows a `[netsimd] <defunct>` child.
The broken `netsimd` outlives the launch, so retrying the dead instance fails
the same way every time, even on its own. That it is `netsimd` is inferred
from where the log stops and from the fix; what is verified is that a clean
sequential restart cures it (seen 2026-11-15 and 2026-11-16, emulator
36.2.12).

**What does not help** (each tried, same crash): another port, `-no-window`,
relaunching the dead instance alone while the survivor keeps running.
`-feature -Netsim` is rejected as a bad feature name. Disk space, RAM and GPU
memory were not the cause.

**Fix.** Shut every instance down, kill `netsimd`, and boot them again one at
a time with the loop above:

```bash
for S in $("$ADB" devices | awk '/^emulator-/{print $1}'); do "$ADB" -s "$S" emu kill; done
for i in $(seq 1 15); do pgrep -f qemu-system >/dev/null || break; timeout 2 tail -f /dev/null; done
pkill -x netsimd
```

This kills the surviving instance too, and being read-only it loses its
installs and logins — say so before doing it if the user has been using it.

## 3. Run the app on each

Use `flutter-android-run`'s `flutter-run.sh` once per serial, with the
session named per device so they don't collide (its exit codes and the hang
check are documented there):

```bash
~/.claude/skills/flutter-android-run/flutter-run.sh start emulator-$P "$(basename "$PWD")-$P"
```

Starting the runs one after another (the script returns once the first build is
up; start the next after that) avoids several Gradle builds racing on the same
`build/` directory; later runs reuse the built APK and start fast.

For a non-Flutter app, install the same APK on each:
`"$ADB" -s emulator-$P install -r <apk>`.

## 4. Drive each device

- Type into a field: tap it, then `"$ADB" -s emulator-$P shell input text <value>`.
- Screenshot one device:
  `"$ADB" -s emulator-$P exec-out screencap -p > /tmp/shot-$P.png`.
- Use a different account on each device when the app identifies people by
  user — the same account on two devices usually shows up as one person
  twice. A project's own test-account skill or `CLAUDE.md` lists which
  accounts to use.

## 5. Report and clean up

Tell the user each serial, its tmux session, and its log path. To shut one
down: `"$ADB" -s emulator-$P emu kill`; all of them:
`for P in $PORTS; do "$ADB" -s emulator-$P emu kill; done`.
