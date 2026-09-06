---
name: work-summary
description: Screenshot the changes made in a given range (a time window, or since a version) by running the app, and build a summary document at summarize/<range>/index.html. Triggers on "summarize today's work", "summarize this week's work as html", "summarize since v1.2.0", "整理今天的工作", "work summary", "/work-summary".
user-invocable: true
---

# Work Summary Skill

Turns "what did I change in <range>?" into a self-contained document with real
screenshots of the app, taken by running it — Android in an emulator, web in
Playwright.

Output lands in the **project root**:

```
summarize/
  .gitignore          # a single "*", so the summary never reaches git
  <range-slug>/
    index.html        # or index.md
    manifest.json     # the data the document was built from
    screenshots/01-....png
```

Never write anywhere else in the repo — the repo's own `.gitignore` included —
and never commit; building the summary is read-only with respect to the
project's own source.

## Inputs

Both are required; ask only for what the prompt does not already give.

| Input | Accepted forms | Slug used for the directory |
| --- | --- | --- |
| Range (time) | `today`, `yesterday`, `this week`, `last 3 days`, `2026-08-25..2026-09-02` | `2026-09-02`, `2026-08-25_2026-09-02` |
| Range (version) | `since v1.2.0`, `v1.2.0..v1.3.0`, `since the last release` | `v1.2.0_v1.3.0`, `v1.2.0_HEAD` |
| Format | `html` (default), `md` | — |

"summarize today's work as html" is fully specified — do not ask anything, just
run. If the range is missing entirely, default to today and say so.

## Procedure

1. **Resolve the range to a git range.**
   - Time: `git log --since="2026-09-02 00:00" --until="..."`. Use the machine's
     local date; `this week` starts Monday.
   - Version: find the commits that bumped the version file (`pubspec.yaml`,
     `package.json`, `build.gradle`, `Cargo.toml`) with
     `git log --oneline -- <file>` and use `<from-bump>..<to-bump>`; prefer a
     real tag when one exists.
   - If the range has no commits, say so and stop — do not build an empty page.
2. **Collect the changes.** `git log --format='%h %s' <range>` plus
   `--stat` (or `git show`) for anything whose subject is unclear.
3. **Group into user-visible items.** One item per user-facing change, not per
   commit; several commits may fold into one item. Move pure refactors, chores,
   dependency and version bumps, CI and test-only commits into `other_changes`
   (text only, no screenshot). Write titles and descriptions in the language the
   user is writing in.
4. **Decide what each item needs to show.** For every item, name the screen or
   state that demonstrates it. An item with no visible surface (backend, build
   config) keeps its own section but gets no screenshot — do not fake one.
5. **Run the app and capture.** Detect the platform from the project root:
   - `android/`, `app/build.gradle`, or a Flutter `pubspec.yaml` with an
     `android/` dir → **`references/android.md`**
   - `package.json` with next/vite/react/vue, or any static `index.html` →
     **`references/web.md`**
   - Both (e.g. Flutter with web support) or neither → ask which target to run.
   Read the matching reference before touching the emulator or the browser.
   Save every shot as `summarize/<slug>/screenshots/<nn>-<short-name>.png`,
   numbered in the order the items appear.
6. **Write `manifest.json`** in `summarize/<slug>/` (schema below).
7. **Build.** `python3 ~/.claude/skills/work-summary/build_summary.py
   summarize/<slug>/manifest.json [--format md]`. It prints the output path.
8. **Report** the path and one line per item. Mention any item that ended up
   without a screenshot and why.

## manifest.json

```json
{
  "title": "今日工作摘要",
  "range_label": "2026-09-02",
  "range_slug": "2026-09-02",
  "project": "myapp",
  "platform": "android",
  "items": [
    {
      "title": "登入頁改版",
      "description": "一句話說明使用者看得到什麼變化。",
      "commits": ["abc1234 feat(auth): single page login"],
      "screenshots": [
        {"file": "screenshots/01-login.png", "caption": "新的單頁登入"}
      ]
    }
  ],
  "other_changes": ["def5678 chore: bump deps"]
}
```

`title`, `range_label` and `items` are required; `generated_at` is filled in by
the script. `screenshots[].file` is relative to `index.html`, so the document
stays portable when the folder is zipped or moved.

## Rules

- **Screenshots come from a running app.** Never draw a mock, reuse an old
  asset, or describe a screen you did not see. If the app will not build or
  boot, stop and report that instead — a summary with invented screenshots is
  worse than none.
- Re-running for the same range overwrites that range's directory; leave other
  ranges alone.
- Keep the summary out of git with a `summarize/.gitignore` holding `*`, written
  alongside the range directory. Git reads it while scanning the untracked
  folder, so it hides the summary and itself, and the repo's own `.gitignore`
  stays untouched — nothing to commit, and deleting `summarize/` leaves no
  dangling rule. Do not add an entry to the repo's `.gitignore`. Mention it
  once, do not nag.
- Keep descriptions to one line, from the user's point of view — the commit
  subject is already in the commits list.
- If a dev server or emulator was already running before you started, leave it
  running; only shut down what you launched.
