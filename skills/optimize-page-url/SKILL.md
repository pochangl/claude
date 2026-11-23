---
name: optimize-page-url
description: Use this skill to enforce page URL conventions — one path per screen, and splitting a URL that released clients or shared links still use. Triggers on mentions of "page URL", "route", "query flag", "mode", "deep link", "universal link", "app link", "invite link", "share link", "QR", "split the page", "拆網址", "網址", or when a page reads a query parameter to decide which screen to show.
---

## 1. One Path per Screen; the Query Only Configures It

A page path names one screen. When a page shows different screens depending on query flags (`?open=1`, `?watch=1`, `?replay=42`), give each screen its own path, and use the query only for settings of the screen the path names. Otherwise one component handles every mode, and it loads, renders and debugs for all of them at once. For example, a lobby downloaded a word list that only the room screens need.

- **Correct:** `/games/duel` (the lobby), `/games/duel/new?game=matching`, `/games/duel/room/ABCDEF?join=1`, `/games/duel/room/ABCDEF/watch`, `/games/duel/replay/42`
- **Incorrect:** `/games/duel?room=ABCDEF&watch=1` and `/games/duel?replay=42` served by the lobby's page

## 2. Splitting a URL Released Clients Read: Readers First, Old Form Kept

A page URL that leaves the site is a contract, the same way an API is (see `optimize-api`). Such URLs include invite links, QR codes, push `open_url`s, and app or universal links that a released app claims and parses. When you move such a URL to new paths:

1. **Web: keep the old form as a redirect.** Map the old query form to the new path. Mark the redirect deprecated with dates (`optimize-comment` rule 4), and give it a removal date later than any generator still producing the old form.
2. **Every reader accepts both forms.** This includes the website and each app's link parser. Ship the readers in the same piece of work.
3. **Generators of links that cross clients keep the old form until the new readers are out.** These are invite or share URLs, QR codes and push links. Switching them now sends a link that an older app misreads. Mark each one deprecated with the date it may switch.
4. **Links that stay inside one client** use the new paths at once (`optimize-api` rule 6). One example is the website's own navigation.

- **Correct:**
  - The app and the web both read `/games/duel/room/<code>` and `/games/duel?room=<code>`.
  - The invite QR still encodes `/games/duel?room=<code>`, "deprecated since 2026-11-23, switch after 2027-02-23".
  - `/games/duel?room=` redirects to the new path.
- **Incorrect:** the web's invite QR switches to `/games/duel/room/<code>` on day one. An older app that claims the link finds no `?room=` and opens a room of its own instead of joining.
