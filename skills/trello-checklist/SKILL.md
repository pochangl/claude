---
name: trello-checklist
description: Add work-log items (today's commits, a summary, or a given list) to a Trello card's checklist via the REST API. Triggers on "trello", "加到 checklist", "checklist", "/trello-checklist", or any request to push a day's changes onto a Trello card.
user-invocable: true
---

# Trello Checklist Skill

Pushes items onto a Trello card's checklist using `trello.sh` in this skill's
directory (`~/.claude/skills/trello-checklist/trello.sh`).

Credentials are **per repo**: `trello.sh` sources
`~/.config/trello/<repo>.env`, where `<repo>` is the basename of the git
toplevel of the current directory (e.g. `app.env`, `e4f.env`). Each project
has its own Trello workspace, so there is no shared fallback. The file
exports `TRELLO_KEY`, `TRELLO_TOKEN`, `TRELLO_BOARD` (the board this repo's
work lives on) and optionally `TRELLO_CARD` (default card short id).
`trello.sh env` prints which file applies. If it is missing, `trello.sh`
prints a template — tell the user to create it (chmod 600); never create or
edit it yourself unless the user asks you to.

Because the board lives in the env file, **never go hunting for a board id**.
`trello.sh board` with no argument reads the board. Do not open, source, or
grep the env file to find one — if something genuinely needs a board other
than `TRELLO_BOARD`, ask the user.

The same env file holds the **whitelists**: the lists on `TRELLO_BOARD` whose
cards may be read and written, as bash arrays of list names as shown on the
board (or list ids):

```bash
TRELLO_WRITE_LISTS=("進行中" "Done")
TRELLO_READ_LISTS=("待辦")
```

Every command looks up its target card's board and list and refuses unless
the card is on `TRELLO_BOARD` in a whitelisted list. Writing needs
`TRELLO_WRITE_LISTS`; reading takes both arrays together, since a list you may
post to is one you may look at — so `TRELLO_READ_LISTS` only needs the lists
that are read-only. Unset or empty refuses; with neither set, nothing can be
read or written. A legacy `"<board>/<list>"` entry still works and pins its own
board instead of `TRELLO_BOARD`.

**`trello.sh board` prints only the whitelisted lists**, not the whole board.
A list that is not whitelisted is invisible: its cards cannot be listed, read,
or reached by id. If the user asks about work that no visible list holds, say
the list is not in the whitelist and let them decide whether to add it — never
try another route to it.

## Hard rules

- **Never print, echo, `cat`, or grep the key/token.** Only ever run `trello.sh`;
  do not hand-write curl calls with the credentials.
- **Always show the drafted items and get explicit approval before `add`.**
  The item format is not settled yet (see below) — the user decides the
  wording every time until it is.
- Never delete or complete existing items. Adding is the only write.
- Only touch cards on `TRELLO_BOARD` in a whitelisted list — writes need
  `TRELLO_WRITE_LISTS`, reads need either array. If `trello.sh` refuses,
  report the board/list it printed and let the user decide whether to add that
  list — never work around the refusal.

## Procedure

1. **Resolve the card.** Use the card URL / short id the user gives
   (`https://trello.com/c/<id>/...` → `<id>`). If none is given, `trello.sh
   card` with no argument uses `TRELLO_CARD` from the env file; if that is
   unset either, ask. Always name the resolved card back to the user.
2. **Inspect it.** `trello.sh card [id]` → note the checklist ids and names.
   If the card has no checklist, ask which name to create it with, then
   `trello.sh create-checklist [id] <name>`. If it has several, ask which one.
3. **Read existing items.** `trello.sh items <checklist-id>` so the draft
   skips anything already present (compare by meaning, not exact string).
4. **Collect the source.** Default source is today's commits in the current
   repo: `git log --since="<today> 00:00" --format="%h %s"` (plus `--stat`
   when the subject alone is unclear). The user may instead point at a
   commit range, a summary already written in the conversation, or a plain
   list — use that verbatim as the source.
5. **Draft the items** following "Item format" below, one per line, in the
   language the user is writing in. Present the full list and the target
   checklist name, and ask the user to confirm or edit. Wait.
6. **Post.** Pipe the approved lines to
   `trello.sh add <checklist-id>` (heredoc, one item per line).
7. **Report** what was added and anything skipped as a duplicate.

## Item format (not settled — update this section as the user decides)

Current default until told otherwise:

- One item per commit, excluding pure `version bump` commits unless asked.
- By default, only write features a screenshot on the card actually shows. A
  feature no screenshot shows goes on the card only when the user explicitly
  asks for it.
- Prefix with the area touched, then a short user-facing description:
  `單字清單頁：拼字測驗可選題數（10 / 30 / 全部）`
- Keep commit hashes out of the item text.
- Write for non-technical readers: describe what a user notices in everyday
  words, never implementation terms (no CallKit, plugin, API, version tags).
  `通話中切到別的 App 再回來，電話不會斷`, not
  `App resume 不再 dispose CallManager`.
- Finished work goes on the checklist as items too (the user ticks them by
  hand), followed by the still-open items such as `iPhone 實機測試`.

When the user corrects the wording or structure of a draft, treat that as
the new convention: record it here (replace this section's bullets) so the
next run drafts it that way without asking.

## trello.sh reference

```
trello.sh env                             # which ~/.config/trello/<repo>.env applies
trello.sh me                              # verify credentials (prints username)
trello.sh card [card]                     # card name, board/list, writable?, checklists (id, name, item count)
trello.sh items <checklist-id>            # existing items: [x]/[ ] name
trello.sh add <checklist-id> < items.txt  # add one item per non-blank stdin line
trello.sh create-checklist [card] <name>  # create a checklist, prints its id
trello.sh board [board]                   # read-only: whitelisted lists, their cards, descriptions, checklists
trello.sh create-card <list> < cards.tsv  # one card per line: "name<TAB>description"
trello.sh attach <card> <file>...         # upload files as attachments to the card
trello.sh attachments <card>              # read-only: attachment name<TAB>url
trello.sh set-desc <card> < desc.md       # replace the card description with stdin
trello.sh comment <card> < comment.md     # post stdin as a new comment on the card
```
`create-card`, `attach`, `set-desc`, and `comment` check the target against
`TRELLO_WRITE_LISTS` before writing anything; show the drafted cards and get
approval first, as with `add`. `card`, `items`, `attachments` and `board`
check it against the read whitelist and refuse the same way.
`[card]` defaults to `TRELLO_CARD`; `[board]` and `create-card`'s board
default to `TRELLO_BOARD`.

Non-2xx responses print `trello API ... failed: HTTP <code>` and exit
non-zero. `HTTP 401 invalid key` with a valid key means the token does not
belong to that key (a Power-Up *secret* pasted instead of a token) — send the
user to `https://trello.com/1/authorize?expiration=never&scope=read,write&response_type=token&name=daily-checklist&key=<KEY>`
to mint a token.
