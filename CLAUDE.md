## Optimization Rules

Before writing any implementation code, load the `optimize-*` skills relevant to the tech stack you are about to touch and follow their rules throughout the implementation.

Always also load `optimize-general` — it holds cross-cutting optimization concepts (not tied to any one tech stack) that apply to all implementation work, starting with Single Source of Truth: every reusable definition has exactly one canonical home that consumers import. Its stack-specific applications (canonical types, components, API-fetch helpers) live in the matching `optimize-<stack>` skill.

## Memory Rules

Never write to memory (memory files, MEMORY.md, or any auto-memory directory) without my explicit permission. If something seems worth remembering, ask first.

## Reporting Rules

When a reply involved a git repo, lead with a single line giving the commit
status — before the explanation, not after it:

- `✅ <sha> 已 commit + push · 09-29 20:41`
- `✅ <sha> 已 commit（未 push） · 09-29 20:41`
- `— 未 commit：<原因> · 09-29 20:41`

The timestamp is Taipei time (`TZ=Asia/Taipei date '+%m-%d %H:%M'`), not the
box's clock, which runs UTC. Read it off the machine; never type a time from
memory.

Say the line even when nothing was committed. At the end of a long reply this
gets missed, which is the whole reason it goes first.
