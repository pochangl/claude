---
name: add-optimize-skill
description: Create a new optimize-* skill that enforces conventions for a specific technology or domain. Triggered via /add-optimize-skill command.
user-invocable: true
---

# Add Optimize Skill

Create a new `optimize-*` skill following the established format.

## Procedure

1. Ask the user for the **topic** (e.g. "tailwind", "celery", "graphql") and the **rules** they want enforced. If the user already provided these, skip asking.
2. Choose a skill name: `optimize-<topic>` in lowercase kebab-case.
3. Create the directory `~/.claude/skills/optimize-<topic>/`.
4. Write `SKILL.md` with the following structure:

```markdown
---
name: optimize-<topic>
description: Use this skill to enforce <topic> conventions. Triggers on mentions of "<trigger phrases>".
---

## 1. Rule Title

Brief explanation of the rule and why it matters.

- **Correct:** `example`
- **Incorrect:** `example`

## 2. Rule Title

...
```

### Format Rules

- Frontmatter: `name` and `description` only. No `user-invocable`.
- `description` must start with "Use this skill to enforce/audit/optimize" and include trigger phrases.
- Rules are numbered starting at 1, using `##` headings.
- Each rule: one paragraph explanation, then optional **Correct**/**Incorrect** examples.
- Keep rules concise — one concept per rule, no multi-paragraph essays.
- Use project-specific examples when possible (reference actual models, apps, patterns from the codebase).

## What NOT to Do

- Don't create the skill without rules — every optimize skill must have at least one rule.
- Don't duplicate rules already covered by an existing optimize skill. Check existing skills first.
- Don't add `user-invocable: true` — optimize skills are loaded automatically, not invoked directly.
- Don't generate or infer rules the user did not explicitly describe. Only include rules the user provided.
