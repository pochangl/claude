---
name: add-feature
description: Add a new requirement to the appropriate spec doc. Updates the build checklist if one exists. Triggered via /add-feature command.
user-invocable: true
---

# Add Feature

1. Read the user's requirement.
2. Find the project's spec docs. Read them to determine which spec doc the requirement belongs to.
3. Append or update the relevant section in that spec doc.
4. If a build checklist exists in the project, add a corresponding unchecked `- [ ]` item to the appropriate section. If no checklist exists, skip this step.
5. Do NOT implement the requirement — only update docs (and checklist if present).
6. Run `/implement-checklist` to implement the new checklist items.
