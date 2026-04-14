---
name: implement-checklist
description: Implement unchecked items from docs/BUILD_CHECKLIST.md one at a time, committing and pushing after each. Triggers on "implement checklist" or "/implement-checklist".
user-invocable: true
---

# Implement Checklist

Implement unchecked items from the build checklist, committing and pushing after each one.

## Procedure

1. Commit any uncommitted changes first using the `/commit` skill.
2. Read `docs/BUILD_CHECKLIST.md` and identify all unchecked `- [ ]` items.
3. Before writing any code, load the `optimize-*` skills relevant to the tech stack you are about to touch. Apply their rules throughout implementation.
4. For each unchecked item, in order:
   a. Implement the feature or fix.
   b. Mark it `[x]` in `docs/BUILD_CHECKLIST.md`.
   c. Commit and push using the `/commit` skill.
5. Repeat until all items are checked or you hit a blocker.

## Rules

- Work through items one at a time — do not batch multiple checklist items into a single commit.
- Follow existing project skills for the relevant domain (e.g., `django-channels`, `websocket-token-auth`).
- If an item is blocked or unclear, skip it and move on. Report skipped items at the end.
