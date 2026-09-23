---
name: e4f-non-vip-test
description: Test WordBranch (e4f) app behavior as a non-VIP user — daily throttles (DictionaryThrottle 查字 10/day, PRS 3/day, video 3/day), lock screens, 剩餘次數 banners, upgrade prompts. Logs the emulator into the non-VIP test account. Triggers on "test as non-VIP", "非 VIP 測試", "用免費帳號測", "check the throttle", "test the quota", "/e4f-non-vip-test".
user-invocable: true
---

# e4f Non-VIP Test

Use this whenever a change touches something that only non-VIP users see: a
`DailyThrottle` (`DictionaryThrottle`, `PRSThrottle`, `VideoThrottle`, …), a
`TokenThrottledContent` lock screen, a 剩餘次數 / 本日已查 banner, or an upgrade
prompt. VIP accounts bypass all of these, so testing them on a VIP account
proves nothing.

## Test account

The non-VIP account `test99`. Its password is in the **Test Accounts**
section of `../e4f/CLAUDE.md` — kept out of this skill because `~/.claude` is
a public repo.

## Before logging in

- **Ask the user before logging out the current account.** The usual dev
  account on the emulator signs in through Google/Apple/Facebook; once logged
  out, you cannot log it back in yourself.
- **Throttle counts are device-local, not per account.** `DailyThrottle` keeps
  today's viewed items in the app's local settings under `throttle/<app>`
  (`throttle/word` for 查字), keyed by date. Switching accounts does not reset
  them; if this emulator already used up today's quota, test99 starts at 0 left
  too. To start from a full quota, clear the app's data — this also logs out:

  ```bash
  adb shell pm clear com.english4formosa.www
  ```

  Then relaunch (`r`/`R` in the `flutter run` tmux session, or restart
  `flutter run -d emulator-5554`).

## Log in as test99

The app runs in the `e4f` tmux session (`flutter run -d emulator-5554`); drive
the emulator with `adb` taps and `adb exec-out screencap -p` screenshots.

1. Bottom nav **更多** → account page (`帳號與設定`).
2. If logged in: group **登入/登出** → **登出**.
3. Same group → **登入** → login dialog → **帳密登入 →** at the bottom.
4. Fill **帳號名稱 \*** with `test99` and **密碼 \*** with its password
   (tap the field, then `adb shell input text <value>`), tap **登入**.
5. Screenshot to confirm the account page shows test99 and no VIP / Pro badge.

A failed login shows 「登入失敗 — 帳密錯誤或連線問題.」.

## Quotas to expect (lib/vars.dart)

| Throttle | Limit / day | Counted by |
| --- | --- | --- |
| `DictionaryThrottle` 查字 | `DICTIONARY_PER_DAY` = 10 (+ referrer / token bonuses) | distinct word text; re-opening a word already seen today is free |
| `PRSThrottle` 字首字根頁 | `PRS_PER_DAY` = 3 | PRS id |
| `VideoThrottle` 影片 | `VIDEO_PER_DAY` = 3 | video id |

What a user sees: the item that uses the last slot still opens (e.g. 「本日已達查詢上限
10 個單字!」); the next *new* item shows the lock screen 「您已達每日使用上限, 您每日有 10
次使用次數, 您剩餘 0 次」 with 「馬上升級 WordBranch Pro」.

## Fallback: fake non-VIP locally

If logging out is not OK, temporarily make every account non-VIP and hot reload:

```dart
// lib/notifiers/subscription.dart
bool get isVIP => false; // TEMP-TEST  (was: isWebVIP || isAppVIP)
```

**Always revert it before finishing**, and check `git diff` shows no change to
`subscription.dart`. Never commit it.

## After testing

- Report which account / method was used and the quota state you ended in.
- Leave the emulator logged in as test99 unless the user asks otherwise, and say so.
