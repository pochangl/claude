# Android capture (emulator)

## 1. Get a device

```bash
adb devices                 # already-running emulator or phone? use it, and do not kill it later
emulator -list-avds         # otherwise pick an AVD (prefer one matching the app's minSdk)
```

Launch in the background (Bash `run_in_background: true`), then wait for boot:

```bash
emulator -avd <avd> -no-snapshot-save -no-boot-anim
adb wait-for-device shell 'while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 2; done'
```

Cold boot takes a minute or two. Poll with `adb shell getprop sys.boot_completed`
rather than a blind sleep.

## 2. Install and launch the build under test

Build from the working tree so the screenshots show the changes in range.

```bash
# Flutter
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Gradle
./gradlew installDebug
```

Application id comes from `android/app/build.gradle` (`applicationId`). Launch:

```bash
adb shell monkey -p <applicationId> -c android.intent.category.LAUNCHER 1
```

Deep links jump straight to a screen and beat tapping through the whole app:

```bash
adb shell am start -a android.intent.action.VIEW -d "<scheme>://<host>/<path>" <applicationId>
```

## 3. Navigate

Never guess tap coordinates. Dump the view tree, find the node, tap its centre:

```bash
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml /tmp/ui.xml
python3 ~/.claude/skills/work-summary/ui_center.py /tmp/ui.xml --text "登入"      # -> "540 1180"
adb shell input tap 540 1180
```

`ui_center.py` also takes `--id <resource-id substring>` and `--desc
<content-desc>`, and exits non-zero when nothing matches — re-dump and look at
the XML instead of tapping a stale coordinate.

Other input:

```bash
adb shell input text "hello%sworld"   # %s is a space
adb shell input keyevent KEYCODE_BACK # 4=back, 66=enter, 61=tab
adb shell input swipe 540 1600 540 600 300   # scroll up
```

Wait for animations to settle (~1s) before capturing.

## 4. Capture

```bash
adb exec-out screencap -p > summarize/<slug>/screenshots/01-login.png
```

`exec-out` (not `shell`) — `shell` corrupts the PNG on some hosts. Check the
file is a non-trivial PNG (`file`, or size > 10KB) before moving on, and open it
with Read to confirm it shows the screen you expected — a black frame means the
app was still loading.

## 5. Clean up

Uninstall nothing. Kill the emulator (`adb emu kill`) only if you started it.
