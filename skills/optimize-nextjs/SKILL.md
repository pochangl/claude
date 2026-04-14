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
