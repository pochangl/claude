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
