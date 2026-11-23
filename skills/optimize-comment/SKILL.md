---
name: optimize-comment
description: Use this skill to write or optimize code comments. Triggers on mentions of "write a comment", "optimize comment", "add a comment", "comment this", "deprecate", "deprecated", or whenever adding comments or deprecation notes to code.
---

A comment must explain something the reader cannot get from reading the code itself. If it does not, delete it.

**Out of scope — never delete or rewrite these:** `TODO`, `FIXME`, `HACK`, `XXX`, `NOTE`, deprecation notes, potentially-deprecated notes (rule 6), license/copyright headers, and doc comments (`///`, docstrings, JSDoc). These are intentional markers about future work, known issues, or public API — not descriptions of current behavior. Rules 1–3 apply only to ordinary explanatory comments; rule 4 governs how a deprecation note is written, rule 6 how a potentially-deprecated note is. Rule 5 applies to every comment, doc comments included.

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

A field, parameter or route that is still there but no longer used *is* in the code: comment it under rule 6, and do not delete that comment under this rule.

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

## 5. No References a Reader Cannot Follow

A comment may point only at things a future developer of this repo can open:

- its own files and docs;
- **related projects** — the other parts of the same product, which that developer works with too: its backend, a sibling client, a browser extension, its web version (e.g. the backend view an app's client code calls). A sign a repo is related: this repo's `CLAUDE.md` names it, the code already cites it, or the two share an API or data;
- public resources (a published issue, the framework's docs).

Never name an **unrelated** project — another product that merely shares an idea or that the code was ported from — nor its files, specs or paths, nor anything on your machine. Whoever reads this repo later has no access to it, so the reference is a dead end. Explain the idea on its own terms instead. When unsure whether a repo is related, ask.

```dart
// Bad — points at an unrelated project's spec the reader can't open
/// Ported from other-app (its `docs/specs/refresh-hold.md`): while held,
/// a request schedules nothing.

// Good — says what it does here
/// While held (the owner is off screen) a request schedules nothing.
```

Before finishing, grep the changed comments for the name of any unrelated project the work drew on, and for paths that exist neither in this repo nor in a related one.

## 6. Mark What Is Kept On Purpose

A field, parameter or route that is still in the code but no longer does anything is technical debt kept for a reason — usually released clients that still read it. Without a comment, the next cleanup deletes it for being unused. Say what it was for, which commit took away its use, why it stays, and mark it **potentially deprecated**. When it is to stay indefinitely, give no removal date: that is what separates it from a rule 4 deprecation.

```python
# Good — what it was for, what took its use away, why it stays
# whether the caller has yet to use the one free trial: a client showed
# the offer while this was true and started the trial by POSTing
# product/subscription_trial/. That route was removed in a47fb9782, so nothing
# starts a trial any more and no client acts on this.
#
# Potentially deprecated, and kept indefinitely: released clients parse
# my_subscription_status/, and a field is not taken out of a response
# they read. Do not remove it for being unused.
can_trial = fields.BooleanField()

# Bad — nothing says why an unused field is still here
can_trial = fields.BooleanField()
```

Dropping the original purpose because the route it served is gone is the same mistake: the purpose is exactly what the reader cannot recover from the code.
