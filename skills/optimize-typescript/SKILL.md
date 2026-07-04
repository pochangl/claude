---
name: optimize-typescript
description: Use this skill to enforce TypeScript conventions. Triggers on mentions of "async", "await", "promise", "then", "catch", "error handling", "fetch", or when writing .ts/.tsx files.
---

## 1. Use async/await Instead of Promise Chaining

Write asynchronous flows with `async`/`await` rather than `.then()`/`.catch()` chains. Await reads top-to-bottom, keeps error handling in ordinary `try`/`catch`, and avoids nested callbacks. To cache a promise (e.g. a fetch-once store initializer), assign the result of an async function instead of chaining on the fetch.

- **Correct:**
```ts
async function init(): Promise<void> {
  try {
    const res = await fetch(PREFERENCE_URL, { credentials: "include" });
    if (!res.ok) throw new Error(String(res.status));
    emit({ ...settings, ...(await res.json()).settings });
  } catch {
    initPromise = null;
  }
}
const initialize = () => (initPromise ??= init());
```

- **Incorrect:**
```ts
function initialize() {
  initPromise ??= fetch(PREFERENCE_URL, { credentials: "include" })
    .then(async (res) => {
      if (!res.ok) throw new Error(String(res.status));
      emit({ ...settings, ...(await res.json()).settings });
    })
    .catch(() => {
      initPromise = null;
    });
  return initPromise;
}
```

In contexts that cannot `await` (a `useEffect` body, an event handler), call an `async` function — e.g. an async IIFE with a `cancelled` flag — instead of chaining `.then()`. A single `.catch(() => {})` guard on a fire-and-forget call (e.g. `audio.play()`) is fine.

## 2. No Do-Nothing catch Handling

Every `catch` must do real work: drive UI state (an error message, a not-found view), enable a retry (e.g. the `initPromise = null` reset above), or restore state. Never write an empty `catch {}` or a catch whose only effect is silencing the error — let the exception propagate instead, so the failure surfaces as an unhandled rejection in the browser console, where it is easier to debug. This applies even when porting old code that "ignored failures".

- **Correct:**
```ts
export async function setPreference(obj: Settings) {
  emit({ ...settings, ...obj });
  await apiPut(PREFERENCE_URL, { settings: obj }); // a failed save surfaces in the console
}
```

- **Incorrect:**
```ts
export async function setPreference(obj: Settings) {
  emit({ ...settings, ...obj });
  try {
    await apiPut(PREFERENCE_URL, { settings: obj });
  } catch {} // swallows the failure — nothing to debug
}
```

Two carve-outs: suppressing an *expected* rejection is fine (e.g. `audio.play().catch(() => {})` for autoplay-policy denials), and `try`/`finally` without a `catch` is fine when cleanup must run either way — the error still propagates.

## 3. One Canonical Type — No Duplicated Shapes

A domain shape (a model, a DTO, an API payload) has exactly one `interface`/`type`. Do not redeclare an identical shape locally; import the canonical one. When a consumer needs only a looser view, widen structurally (accept `{ first_name: string; last_name: string }`) rather than cloning the full type. This is the SSOT concept from `optimize-general` applied to TypeScript types.

- **Correct:**
```ts
import { PublicUser } from "@/lib/publicUser";
// a formatter over the minimal shape every profile satisfies:
export const fullName = (u: { first_name: string; last_name: string }) =>
  `${u.last_name} ${u.first_name}`.trim();
```

- **Incorrect:**
```ts
// re-declared in a component, identical to the canonical PublicUser
interface PublicProfile { id: number; first_name: string; last_name: string; avatar_url: string }
```

## 4. One Canonical Fetch Per Endpoint

Each API endpoint is reached through exactly one helper that owns its URL, query params, and response shape — routed through the shared client (`@/lib/api`'s `apiGet`/`apiPost`/`listData`), never a hand-rolled `fetch` or an inline duplicate URL. If a caller needs a variation, extend the existing helper (or add a sibling in the same module) rather than re-deriving the URL elsewhere. SSOT applied to data access.

- **Correct:**
```ts
// one module owns the endpoint; every caller imports this
export async function fetchPublicUser(id: number): Promise<PublicUser> {
  return apiGet<PublicUser>(`/api/account/public_user_profile/${id}/?${URL_PARAMS}`);
}
```

- **Incorrect:**
```tsx
// a page rebuilding the same URL inline while fetchPublicUser already exists
const profile = await apiGet(`/api/account/public_user_profile/${id}/?format=json`);
```
