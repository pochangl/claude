---
name: init-permissions
description: Use this skill to set up project permissions so file edits and safe git commands run without prompts. Allows editing files within the project and the git commands commit, push, rebase, merge, status, log, show. Triggers on "init permissions", "setup permissions", "/init-permissions".
user-invocable: true
---

# Init Permissions Skill

Set up a project's `.claude/settings.local.json` so that editing files within the project and a curated set of git commands run without permission prompts.

## What it allows

- **File edits within the project** — `Edit` and `Write` scoped to the project root.
- **Git commands** — `commit`, `push`, `rebase`, `merge`, `status`, `log`, `show`.

Nothing else. Destructive or outward-reaching commands not in this list still prompt.

## Procedure

1. Determine the project root: `git rev-parse --show-toplevel`. If not in a git repo, use the current working directory.
2. Read `<root>/.claude/settings.local.json` if it exists; otherwise start from `{ "permissions": { "allow": [] } }`. Never overwrite an existing file — merge into its `allow` list.
3. Ensure the `allow` list contains each of these entries (add only the ones missing, preserve existing entries and any other keys):

   ```json
   {
     "permissions": {
       "allow": [
         "Edit(//ABSOLUTE_PROJECT_ROOT/**)",
         "Write(//ABSOLUTE_PROJECT_ROOT/**)",
         "Bash(git commit:*)",
         "Bash(git push:*)",
         "Bash(git rebase:*)",
         "Bash(git merge:*)",
         "Bash(git status:*)",
         "Bash(git log:*)",
         "Bash(git show:*)"
       ]
     }
   }
   ```

   Replace `ABSOLUTE_PROJECT_ROOT` with the absolute path from step 1 (the leading `//` makes it an absolute-path match).
4. Write the merged JSON back to `<root>/.claude/settings.local.json` with 2-space indentation.
5. Report which entries were added and which were already present.

## Rules

- This is project-scoped: always write to the project's `.claude/settings.local.json`, never the global `~/.claude/settings.json`.
- Be idempotent — running it twice must not create duplicate entries.
- Do not add any git command beyond the seven listed (no `reset`, `clean`, `checkout`, `branch -D`, etc.).
- `settings.local.json` is typically git-ignored; do not commit it unless the user asks.
