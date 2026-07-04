---
name: optimize-nextjs
description: Use this skill to enforce Next.js conventions. Triggers on mentions of "Next.js", "hydration", "SSR", "server component", "client component", or when writing .tsx files in a Next.js app.
---

## 1. No Locale-Dependent Formatting in Server-Rendered Output

Do not use `Date.toLocaleString()`, `Date.toLocaleDateString()`, `Number.toLocaleString()`, or similar locale-dependent methods in JSX that is server-rendered. These produce different output on the server (Node.js) vs the client (browser), causing hydration mismatches.

Guard locale-dependent rendering behind a `mounted` state that is only set after the component mounts on the client:

- **Correct:**
```tsx
const [mounted, setMounted] = useState(false);
useEffect(() => setMounted(true), []);
// In JSX:
{mounted ? new Date(timestamp).toLocaleString() : ""}
```

- **Incorrect:**
```tsx
// Directly in JSX — causes hydration mismatch
{new Date(timestamp).toLocaleString()}
```

## 2. One Canonical Component — No Parallel Implementations

A UI unit is built once and reused. Two components rendering the same thing — often the same source ported twice under different names, or an inline copy living beside a shared one — must be collapsed to one. Before writing a component, grep for an existing one (a shared file in `components/`, or an inline helper stamped with the same origin). To consolidate: pick the canonical file, reconcile the prop interface, rewire every consumer, delete the duplicate, and rebuild to confirm dependents are unchanged. This is the SSOT concept from `optimize-general` applied to React components.

- **Correct:** one `CheckBoxChoice` in `components/problem/`; `ProblemAnswers` imports it instead of keeping an inline copy.
- **Incorrect:** `MatchingGame.tsx` and `MatchingMixed.tsx` both porting the same `matching/Mixed.vue`; or an inline `ChoiceLabel` defined beside a shared `ChoiceLabel.tsx`.
