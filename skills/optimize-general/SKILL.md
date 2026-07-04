---
name: optimize-general
description: Use this skill to enforce general, cross-cutting optimization concepts that apply to all code regardless of tech stack. Triggers on mentions of "optimize", "single source of truth", "SSOT", "duplicate", "duplicated literal", "reinvented helper", "DRY", or whenever adding a constant or helper function in any language.
---

General optimization concepts that are not tied to any one technology. Always applies, alongside the stack-specific `optimize-*` skills. Each concept below is a group of numbered rules; add new stack-agnostic concepts as new sections.

# Single Source of Truth (SSOT)

Every reusable definition — a named constant or a function/helper — must have exactly **one** canonical definition that all consumers import. Before writing one, search the codebase for an existing one and reuse it. Stack-specific applications of SSOT (canonical **types**, **components**, **API-fetch helpers**, etc.) are enforced by the matching `optimize-<stack>` skill.

## 1. Search before you define

Before introducing a constant or helper, grep for an existing definition (by value, by name, and by purpose). If one exists, import it; do not write a second. This is the check that prevents every violation below.

- **Correct:** `grep -rn "HIGH_SCHOOL_CATEGORIES\|10, ?1, ?2, ?3, ?4, ?11" src` → found in one module → import it.
- **Incorrect:** declaring `HIGH_SCHOOL_CATEGORIES = [10, 1, 2, 3, 4, 11]` locally because you didn't look.

## 2. One canonical constant — no duplicated literals

A literal that carries meaning (id set, URL base, magic number, config map) is defined once and exported; consumers import it. The same literal appearing in two files is a bug waiting to drift.

- **Correct:** `HIGH_SCHOOL_CATEGORIES = [10, 1, 2, 3, 4, 11]` in one module; every consumer imports it.
- **Incorrect:** the same array inlined in three files under three names (`HIGH_SCHOOL_CATEGORIES`, `READING_CATEGORIES`, a bare literal).

## 3. One canonical helper — no reinvented functions

A piece of logic (a formatter, a parser, a fetch-and-transform) lives in one function. Two functions computing the same thing — especially under different names, so a name-grep misses them — is the hardest duplication to catch; search by behavior, not just by name.

- **Correct:** one `fullName(u)` formatter imported everywhere it's needed.
- **Incorrect:** `buildFlattenedPrss` defined privately in one file AND exported from another; or `fullName` re-implemented inline in three places.

## 4. Consolidate divergences deliberately, not silently

When you find two definitions of the same thing that have drifted (different signatures, behavior, or edge cases), do not blindly delete one. Choose the canonical version, port any faithful behavior the other had, reconcile the interface, rewire all consumers, then verify (build/tests) that dependents are unchanged. If the drift encodes a real difference, surface it rather than forcing a merge.
