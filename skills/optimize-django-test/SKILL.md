---
name: optimize-django-test
description: Use this skill to enforce Django test conventions. Triggers on mentions of "write tests", "add test coverage", "test this endpoint", "create test cases", or when writing test files.
---

## 0. Top-Level Constraints Do Not Apply

Rules from `optimize-*` skills (e.g., `optimize-django`, `optimize-python`) do not apply to test code. Only the rules in this file govern test files.

## 1. Test Behavior the Code Explicitly Defines; Don't Pin Framework Defaults

Anchor each test to an **explicit construct in the code under test** — a `return Response(..., status=...)`, a `raise ValidationError` / `validate_*` method, an explicit branch, or an explicit queryset/filter (`.filter(...)`, `.none()`). Assert the behavior *that construct* produces.

Do **not** write a test whose purpose is to pin an emergent framework default that no line of the code sets — list/create status codes, the empty-result representation (`[]` vs `{}`), or the pagination envelope — for a path the code does not explicitly handle. Assert the logic-level effect instead, not the HTTP envelope.

- **Example:** for an unscoped list whose only relevant code is `return qs.none()`, assert that *no rows outside the requested scope appear* — never that the response is `200 []`. The status is the framework's, not the endpoint's, and pinning it invents a contract that forecloses a legitimate `400 require-scope` choice.

**Exception:** pin an emergent default only when an explicit external spec requires it (e.g. "the client consumes a bare array, never a paginated envelope"). Cite the source in the test name or a comment.

Never invent a behavioral contract — and never write a test asserting one — for behavior no existing test, code construct, or written spec already defines.

## 2. Use TestCase with setUp

Every test class must extend `django.test.TestCase`. All fixtures must be created in `setUp` — never share state via class attributes. Group test classes by feature (e.g. `TestProviderCreate`, `TestProviderList`), not by HTTP method.

## 3. Async Tests for Async Code

If the code under test is async (ADRF views, consumers, async services), the test method must be `async def`. Use `create_async_api_client` (sync setUp) or `acreate_async_api_client` (async context) from `utils.test.auth`. Never wrap async code in `sync_to_async` or `asyncio.run` to force a sync test — auth will fail.

## 4. Assert Status Code with Response Content

Assert a status code only when the endpoint's own code produces it — an explicit `Response(status=...)`, a `raise`, or a create/retrieve/update/destroy you are exercising. For a path whose status is a pure framework default, assert the logic-level effect per Rule 1 instead of pinning the code.

When you do assert a status code, always pass `response.content` as the second argument to `assertEqual`. This makes failures self-explanatory. Expected codes: `201` for POST create, `200` for GET/PUT/PATCH, `204` for DELETE, `403` for permission denied.

- **Correct:** `self.assertEqual(response.status_code, 201, response.content)`
- **Incorrect:** `self.assertEqual(response.status_code, 201)`

## 5. Create Test Data with ORM Directly

Use `utils.test.auth.create_user()` for users and `.objects.create()` for all other models. No factory libraries.

## 6. Test Isolation Between Users

Verify that one user cannot see or modify another user's data. Create a second user/client and assert they get empty or forbidden responses for the first user's resources.

## 7. Mock External Services

Use `unittest.mock.patch` as a decorator or context manager for external calls (geocoding, push notifications, etc.). Always assert the mock was called with expected arguments.

## 8. WebSocket Test Cleanup

Always call `await communicator.disconnect()` at the end of WebSocket tests. For unauthorized WebSocket tests, assert close code `4401`.
