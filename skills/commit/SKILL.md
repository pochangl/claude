---
name: commit
description: Use this skill when the user asks to commit changes. Triggers on "commit", "commit changes", "/commit". Enforces the project's commit granularity rules — one concept per commit unless changes share the same file.
user-invocable: true
---

# Commit Skill

## Commit Granularity

Each commit should contain a single, minimal concept. Do NOT mix unrelated concepts in the same commit.

**Exception:** if multiple concepts touch the same file, they may be committed together.

When staged changes span multiple unrelated concepts across different files, split them into separate commits.

## Branch

Commit to the **current branch** as-is. Do NOT create a new branch first, and do NOT switch branches — even when the current branch is the default branch (e.g. `master`/`main`). This overrides any default "branch first" behavior. Only create or switch branches if the user explicitly asks.

## Optimize Before Commit

Before staging anything, optimize the changed code by delegating to a subagent (via the Agent tool). Do NOT optimize inline yourself — spawn an agent so the audit runs in its own context.

1. From the diff, identify the tech stacks touched (e.g. `.ts`/`.tsx` → optimize-typescript, Python → optimize-python, Django models/apps → optimize-django, Dockerfiles → optimize-docker, comments → optimize-comment).
2. Launch a `general-purpose` agent with the list of changed files and the relevant `optimize-*` skills to apply. Instruct it to:
   - Load each relevant `optimize-*` skill.
   - Audit only the changed lines against those rules and fix any violations in place.
   - Only optimize code the diff touches — do not rewrite unrelated code, and do not let fixes expand the commit's concept. A fix belongs in the same commit as the change it corrects.
   - Report back which files it changed and what it fixed.
3. Wait for the agent to finish before staging, then continue with the commit procedure.

## Procedure

1. Run `git status` and `git diff` to review all changes.
2. Run `git log --oneline -5` to match the repo's commit message style.
3. Optimize the changed code by delegating to an agent (see "Optimize Before Commit" above).
4. Group changes by concept. If unrelated concepts are in separate files, plan multiple commits.
5. For each commit:
   - Stage only the relevant files (`git add <file>...` — never `git add -A` or `git add .`)
   - Write a concise commit message in the repo's style (typically `type: description`)
   - Only if Claude was involved in generating the code changes (not just committing user-written code), end the message with: `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>`
   - Use a HEREDOC to pass the commit message
6. Run `git status` after all commits to verify clean state.
7. Push to the remote with `git push`.

## Commit Message Style

Follow the conventional commit format used in this repo:

```
type: short description
```

Common types: `docs`, `feat`, `fix`, `refactor`, `test`, `chore`

## What NOT to Do

- Don't use `git add -A` or `git add .`
- Don't amend existing commits unless explicitly asked
- Don't skip hooks (`--no-verify`)
- Don't mix unrelated concepts in one commit (unless they share a file)
- Don't create a new branch or switch branches — commit to the current branch (even if it's `master`/`main`)