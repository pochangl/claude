---
name: keep-screenshots
description: Keep every screenshot taken while working — Android emulator/phone or web (Playwright) — in summarize/screenshots/<date>/ under the project root, so a later work summary can reuse them. Use for every screenshot taken to check a change, not only when asked. Triggers on "截圖", "截個圖", "screenshot", "take a screenshot", "截圖留著", "保留截圖", "keep the screenshots", "/keep-screenshots".
user-invocable: true
---

# Keep Screenshots

Every screenshot taken while changing an app is kept, so the day's work can
later be summarized from real captures (`work-summary`) without re-running every
screen.

All shots go through `shot.py`, the one place that knows the folder and the
naming:

```
<project root>/summarize/
  .gitignore                        # "*" — never reaches git; written by shot.py
  screenshots/<YYYY-MM-DD>/         # Taipei date
    <HHMMSS>-<short-name>.png       # Taipei time; e.g. 152006-duel-online-avatars.png
```

## Taking a shot

```bash
S="$HOME/.claude/skills/keep-screenshots/shot.py"   # PowerShell: $S = "$HOME/.claude/skills/keep-screenshots/shot.py"

python3 "$S" duel-invite-dialog                  # Android, the only device
python3 "$S" duel-invite-dialog emulator-5556    # Android, a given device (multi-emulator)
python3 "$S" --path web-duel-room                # web: prints the path to save to
python3 "$S" --dir                               # today's folder (or: --dir 2026-10-13)
```

It runs the same on Linux, macOS and Windows (Python 3.10+; on Windows the
command is `python` or `py`, not `python3`). It finds `adb` under
`ANDROID_HOME` / `ANDROID_SDK_ROOT`, the platform's default SDK folder, or PATH.
On Windows never capture with `adb exec-out screencap -p > x.png` in PowerShell
— the redirect corrupts the PNG; that is why `shot.py` reads adb's output itself.

Run it from inside the project (it uses the git top level). It prints the
saved path; open that file with Read to check it shows what was meant before
relying on it.

For Playwright, pass the path from `--path` as the screenshot `filename`, so web
shots land in the same folder with the same naming.

## Rules

- **Every shot goes in the folder, never `/tmp` or the scratchpad.** That
  includes shots taken only to look at a screen, failed attempts and
  before/after pairs — the summary picks from them later.
- **Never delete, move or overwrite a kept shot.** `shot.py` adds `-2`, `-3`
  on a name clash. Copy (not move) when another document needs one.
- **Name it after what it shows**, in short kebab-case English
  (`duel-room-readonly-chips`), so the summary can match shots to changes by
  name.
- A bad capture (not a PNG, or under 10KB — usually a black frame while the app
  loads) makes `shot.py` exit 1 but stays on disk; take it again. When adb
  itself fails (no device) nothing is written.
- Pass the device explicitly whenever more than one is attached.
