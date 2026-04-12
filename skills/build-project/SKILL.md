---
name: build-project
description: Use this skill when the user asks to build the project, implement the checklist, or continue building. Triggers on "build", "build project", "implement checklist", or "/build-project".
user-invocable: true
---

# Build Project

Before starting, commit any uncommitted changes using the `/commit` skill.

Follow these three steps in order.

## Step 1 — Review docs/checklist.md

Read `docs/checklist.md` and the other docs files (`docs/user-workflow.md`, `docs/database-structure.md`, etc.) to ensure the checklist is consistent with the docs.

**Rules:**
- Add checklist items for any requirement in the docs that is not yet represented.
- Remove or update items that no longer match the docs.
- Preserve existing checked/unchecked state — never uncheck a completed item.
- Keep the existing section structure; add new sections only when a requirement doesn't fit an existing one.

## Step 2 — Load Optimization Rules

Before writing any code, read the `optimize-*` skills relevant to the tech stack you are about to touch. Apply their rules as you implement.

## Step 3 — Implement the Checklist

Work through every unchecked `[ ]` item in `docs/checklist.md`:

1. Implement the feature or fix, following the optimization rules loaded in Step 2.
2. Mark it `[x]` in `docs/checklist.md` when done.
3. Follow existing project skills for the relevant domain.

## Step 4 — Commit

After all steps are complete, commit all changes using the `/commit` skill.
