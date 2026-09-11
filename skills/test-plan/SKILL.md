---
name: test-plan
description: Write the manual (human, on-device) test plan for one or more app versions and publish it to the project's fixed test-plan artifact. Triggers on "測試計畫", "test plan", "測試項目", "要測什麼", "what to test in <version>", "/test-plan".
user-invocable: true
---

# Test Plan Skill

Turns "give me a test plan for 1.1.49 and 1.1.50" into one page a tester works
through on real devices: where to tap, what they should see, and a Pass / Fail
mark per check. The page is always published to the project's **fixed** artifact
below — never to a new URL.

## Where the plan lives

| Repo | Artifact (update in place) |
| --- | --- |
| `~/workspace/app` (PRS, English) | https://claude.ai/code/artifact/e1734aba-0a07-4000-9772-bc9371f1d347 |
| `~/workspace/sealchat` (SealTalk, 繁中；test accounts and seed data in the repo's `manual-test` skill; version file is `app/pubspec.yaml`) | https://claude.ai/code/artifact/4e058775-2ba7-42e6-9203-a4bc311e6ac4 |

For a repo not in this table, ask the user where the plan should go, and add a
row here only after they confirm.

The plan is for **people**, not automation. Do not write unit or widget tests,
and do not turn the page into a test report. The unit test result is at most
one line in the footer.

## Procedure

1. **Resolve the versions to commit ranges.** Walk the version file:
   `git log --format='%h %ad %s' --date=short -- pubspec.yaml`, then
   `git show <sha>:pubspec.yaml | grep '^version'` for each bump. A version's
   range is `<previous bump>..<its bump>`. Call out versions that are a bare bump
   (no code) or only touch lockfiles — they still get checks, aimed at what the
   lockfile change can break (native pods, plugin versions).
2. **Read the diffs, not just the subjects.** `git show <sha> -- lib` for every
   feature commit. Take from the code, not from memory:
   - the exact on-screen strings (button labels, dialog titles, empty states),
   - when a thing appears or stays hidden (`if (...isNotEmpty)`),
   - limits and defaults (max 3 shown, 20 rows, default on),
   - the path from a top-level screen to the feature (grep the route,
     `gotoPage`, or the button that opens it).
3. **Pick test data that actually exercises each feature, and prove it.**
   Before recommending a word, account, or affix, query the real source:
   - tw.wordbranch.com through the `twClient` token in `lib/api/api.dart`
     (`curl -H "Authorization: Token <token>" https://tw.wordbranch.com/api/...`),
   - the offline DB: `sqlite3 assets/en.db "select id, word from word where word='...'"`.
   An empty API answer means the word cannot demonstrate the feature: pick
   another (for example, `greenhouse` has no analogy pairs and `authority` has 50+).
   The porting-log artifacts ("WordBranch EN 移植日誌 <date>") record test
   accounts and data in their 備註 notes; `Artifact` `list` + `read` them.
4. **Verify doubtful expectations on the emulator.** Follow
   `~/.claude/skills/work-summary/references/android.md` for booting, input and
   capture. PRS specifics:
   - AVD `Medium_Phone_API_36.1`; `adb` is at `~/Android/Sdk/platform-tools/adb`
     (not on PATH).
   - `flutter run -d emulator-5554 > <scratchpad>/flutter_run.log 2>&1` in the
     background; the Gradle / AGP / Kotlin "support will soon be dropped" lines
     are warnings. The app is up when the log has `DevTools debugger`.
   - The log prints every request as `get https://...`. Use it to confirm that a
     feature actually fetched.
   - On the search page, typing may not trigger a search (known SearchBar
     issue); send Enter (`input keyevent 66`).
   - Look at every screenshot before relying on it.
5. **When verification finds a bug**, never write the broken behaviour as the
   expected result. On that version's check, add a `已知錯誤` note saying what
   the tester will see, so they don't file it again. If a fix is made in the
   working tree, put the full check in the **下一版** section (the ledger row
   says `下一版` / `未 commit`). Do not commit or bump the version unless asked.
6. **Write the page** (structure below), in the user's language: Traditional
   Chinese for this user. Keep the app's on-screen labels in the app's own
   language, since that is what the tester sees.
7. **Publish to the fixed URL.** See "Publishing".
8. **Report** in the chat: the link, what to expect per version in a few lines,
   and the items under "上架前要先決定". Do not repeat every check.

## Page structure

Start from the live page and keep its design (CSS tokens, both themes, fonts).
Change the content, not the look.

- `<title>` and `h1`: `PRS <from>–<to> 測試計畫` / `<from> 與 <to> 測試計畫`.
- Lede: one paragraph on what each version is, ending with "每一項都在實機上用手操作".
- **Version ledger**: version+build, commit, date, what changed. Rows under
  test get `class="focus"`; unreleased fixes get a `class="next"` row `下一版`.
- **預期結果**: one column per version under test. Say plainly when a version
  should look identical to the previous one.
- **上架前要先決定**: behaviour changes that work as coded but need a product
  decision (a new default, data that isn't per account, a link to a page that
  doesn't exist). Build-only concerns go in a check's note instead.
- **Sticky tally**: 通過 / 失敗 / 剩 N 項 plus 清除結果. Marks live in
  `localStorage` under `prs-testplan-<newest version>`. Change the key when the
  versions change, so old marks don't carry over.
- **開始前準備**: devices, accounts, network, and a table of test words with
  why each one works.
- **Sections by area** (`1.1.50 · 字典頁`, …). Each check is an
  `<article class="check" data-id="C3">`: a letter per section plus a number,
  an `h3`, `<p class="where">` with the path, and bullets of what should (and
  should not) appear. Wrap the app's buttons in `<span class="ui">`. Notes:
  `注意` (risk), `行為改變`, `已知錯誤`, `已知問題，非本版`, `給建置的人`.
- **下一版** section for fixes not in a release yet.
- `<details class="prior">` for earlier features that testers may be seeing
  for the first time.
- Footer: the git range, where the test data came from, and one line on unit tests.

One behaviour per check. Every expectation must trace to code you read or a
screen you saw.

## Publishing

- **Same conversation as the last publish**: edit the scratchpad file and call
  `Artifact` with the same `file_path`.
- **New conversation**: `Artifact` `action: "read"` with the URL. The full
  HTML is saved to a file. Copy it to the scratchpad as `prs-test-plan.html`,
  edit, then publish with `url` set to the fixed URL. Without `url`, a new
  artifact is created. Don't do that.
- On a redeploy, omit `favicon` and `icon`, and pass a short `label` (e.g.
  `1.1.51 測試項目`).
- Keep the plan out of the repo. The artifact is the single copy.
- If the user says to hold off on updating the page, stop editing it and say
  whether a version already went out.

## What NOT to do

- Don't list commits as checks; group by what the tester does on screen.
- Don't recommend test data you haven't checked against the real source.
- Don't describe the expected result from the commit message alone.
- Don't publish anywhere but the fixed URL, and don't create a second plan page.
- Don't commit, bump versions, or write memory as part of this skill.
