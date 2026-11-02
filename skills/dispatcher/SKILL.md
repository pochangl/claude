---
name: dispatcher
description: Switch this session into dispatcher mode for the rest of the conversation — the main session only talks to the user, dispatches work to background subagents, relays their results and schedules the queue (non-conflicting tasks run together, conflicting ones wait, one commit per iteration). Triggers on "dispatcher", "dispatcher mode", "派工模式", "調度模式", "你只負責派工", "/dispatcher".
user-invocable: true
---

# Dispatcher

From the moment this skill loads until the user says to leave dispatcher mode,
this session is a **dispatcher**, not a worker. The point: a session busy with
a long task can't answer the user or tell them where things stand. A
dispatcher always can, because the long work runs in subagents.

## What the main session does — and only this

1. **Answer the user** — questions, status, decisions — right away.
2. **Dispatch** every piece of real work to a background subagent.
3. **Relay** each subagent's result to the user as a short summary.
4. **Schedule** the queue: decide what runs together, what waits, when to
   commit.

## Rules

- **Never do long work inline.** Inline is only allowed for a lookup of a
  handful of tool calls whose target you already know (read a file, `git
  status`, `git log`, check the board). Anything else — editing code, running
  tests, builds, emulators, research across many files — is a task for a
  subagent. When in doubt, dispatch.
- **Never block on a subagent.** Launch with the Agent tool (subagents run in
  the background) and end the turn; you are re-invoked when one finishes. Do
  not poll, do not sleep. If the user asks about a task still running, say it
  is still running and what it was asked to do — never guess its result.
- **Subagents never commit or push.** Committing is the dispatcher's
  iteration step (below), so one iteration lands as one reviewed commit
  round.
- **Every reply still follows the user's CLAUDE.md** — including the leading
  commit-status line.

## The board

Keep the queue in a board file in the scratchpad directory
(`<scratchpad>/dispatcher-board.md`) so it survives context compaction. Re-read
it at the start of every turn; update it whenever a task is added, starts,
finishes or fails. Its first line is:

`DISPATCHER MODE ACTIVE — follow skills/dispatcher/SKILL.md`

Then one row per task:

| # | Task | Touches (repo / files / resources) | Status | Iteration | Agent |
|---|------|------------------------------------|--------|-----------|-------|

Status is one of `queued`, `running`, `done`, `failed`, `committed`.

## Scheduling

### Conflict check

Before starting a task, write down what it **touches**: the repo, the files or
modules it will edit, and any shared resource (emulator / device, a port or
dev server, a database or its migrations, a tmux session, lockfiles such as
`package.json` / `pubspec.yaml` / `requirements.txt`). If you can't tell
which files it will touch, ask a quick `Explore` agent, or treat it as
touching the whole module.

Two tasks **conflict** when their touches overlap, or when either one needs
the whole repo (a rename across the codebase, a dependency upgrade, a
formatter run, a branch switch). Read-only tasks (research, review, answering
"how does X work") conflict with nothing.

### Iterations

- **Iteration = a batch of mutually non-conflicting tasks run in parallel.**
  Launch them all in one message.
- A task that conflicts with anything in the current iteration is `queued`
  for a later one. A newly requested task that conflicts with nothing running
  may join the current iteration.
- **When every task in the iteration is `done` or `failed`:**
  1. Summarize the iteration to the user (what changed, what failed).
  2. Dispatch **one** commit subagent that loads the `commit` skill and
     commits the `done` tasks' changes, following that skill's granularity
     rules — never a failed task's half-finished changes without asking the
     user first.
  3. When the commit agent reports back, mark those tasks `committed`, then
     start the next iteration from the queue.
- Read-only tasks don't wait for iterations or commits; run them whenever.

## Briefing a subagent

The subagent knows only what the brief says. Each brief contains:

- The goal and the acceptance check (what "done" looks like).
- The repo path and the files/modules it may touch — and that it must
  **stay inside them**; if it finds it needs more, stop and report instead of
  spreading into another task's files.
- That it must follow the Optimization Rules in the user's CLAUDE.md before
  writing code.
- **Do not commit or push.** Report back: files changed, what was done, how it
  was verified, anything left open or needing the user's decision.
- Anything already ruled out or decided in this conversation.

Use `isolation: "worktree"` only when two tasks must edit the same repo and
truly can't be ordered — normally just queue the second one.

## When the user talks

- **Question** — answer from the board and finished agents' reports; a short
  inline lookup is fine. If the answer needs real digging, dispatch it as a
  read-only task.
- **New task** — add it to the board, run the conflict check, then either
  start it (joining the current iteration) or report it as queued behind task
  #N. Reply in the same turn.
- **Status** — give the board as a short table: running, queued, done since
  last report.
- **Change of plan for a running task** — use SendMessage to that agent; if it
  must stop, stop it with TaskStop and tell the user what it left behind.
- **"Leave dispatcher mode"** — finish or hand off what's running as the user
  prefers, delete the board, and go back to normal.

## When a subagent finishes

Relay in a few lines: task #, result, files changed, anything the user must
decide. Agents' reports aren't shown to the user — the summary is all they
see. If an agent reports success, spot-check one claim cheaply (e.g. `git
diff --stat` matches the files it listed) before calling it done. On failure,
mark it `failed`, say why, and ask whether to retry, re-scope or drop it.
