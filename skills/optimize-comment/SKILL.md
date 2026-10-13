---
name: optimize-comment
description: Use this skill to write or optimize code comments. Triggers on mentions of "write a comment", "optimize comment", "add a comment", "comment this", "deprecate", "deprecated", or whenever adding comments or deprecation notes to code.
---

A comment must explain something the reader cannot get from reading the code itself. If it does not, delete it.

**Out of scope — never delete or rewrite these:** `TODO`, `FIXME`, `HACK`, `XXX`, `NOTE`, deprecation notes, license/copyright headers, and doc comments (`///`, docstrings, JSDoc). These are intentional markers about future work, known issues, or public API — not descriptions of current behavior. Rules 1–3 apply only to ordinary explanatory comments; rule 4 governs how a deprecation note is written.

## 1. Do Not Comment What Is Not In the Code

Only comment on code that is present. Do not write comments about:

- **Things that are absent** — why a parameter, key, branch, or call was *omitted*. The code shows what exists, not what was deliberately left out; a comment about an absent construct describes nothing the reader can point to.
- **Behavior not implemented here** — what some other layer does, or what *would* happen in a hypothetical case the code does not handle.

```dart
// Bad — comments on a key that isn't there
// no key here so the controller isn't recreated
TabController(length: n)

// Good — no comment; the code is the code
TabController(length: n)
```

If omitting something is genuinely subtle and regression-prone, that belongs in a commit message or a test name, not an inline comment on absent code.

## 2. Do Not Comment Default / Framework Behavior

Do not document behavior that comes from the language, the framework, or a library's defaults. The reader learns that from the framework's docs, not from this codebase, and the comment rots when the framework changes.

```dart
// Bad — describes the framework's built-in behavior
// setState schedules a rebuild on the next frame
setState(() => x = 1);

// Bad — describes a default
// defaults to 0 when not provided
final index = config.index ?? 0;

// Good — comment the project-specific reason, or nothing
final index = config.index ?? 0;
```

## 3. What Is Worth Commenting

Keep a comment only when it adds a *why* that the code cannot show:

- A non-obvious business rule or domain constraint.
- A workaround tied to an external bug/quirk (link it).
- A deliberate, surprising tradeoff a maintainer would otherwise "fix".

Prefer one tight line. Never paraphrase the adjacent code.

## 4. Date Every Deprecation

A deprecation note — a `deprecated` comment, Go's `// Deprecated:`, Dart's `@Deprecated(...)`, JSDoc `@deprecated` — must say:

- **Since when**: the date it was deprecated, `YYYY-MM-DD`.
- **Removal date**: when it may be removed. Default to **3 months after** the deprecation date unless the user names another.
- **The replacement**: what callers should use instead.

Without dates nobody can tell later whether the thing is safe to delete.

```python
# Bad — no dates; nobody knows when it can go
# deprecated: clients read pictures from public_user_profile/set/

# Good
# deprecated since 2026-10-13, remove after 2027-01-13: clients read
# pictures from public_user_profile/set/
```

When the codebase has a structured way to declare it (e.g. a `deprecated_since` / `sunset` pair on a view), set those instead of, or in addition to, the comment, using the same dates.
