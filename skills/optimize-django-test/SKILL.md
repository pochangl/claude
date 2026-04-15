---
name: optimize-django-test
description: Use this skill to enforce Django test conventions. Triggers on mentions of "write tests", "add test coverage", "test this endpoint", "create test cases", or when writing test files.
---

## 0. Top-Level Constraints Do Not Apply

Rules from `optimize-*` skills (e.g., `optimize-django`, `optimize-python`) do not apply to test code. Only the rules in this file govern test files.

## 1. Use TestCase with setUp

Every test class must extend `django.test.TestCase`. All fixtures must be created in `setUp` — never share state via class attributes. Group test classes by feature (e.g. `TestProviderCreate`, `TestProviderList`), not by HTTP method.

## 2. Async Tests for Async Code

If the code under test is async (ADRF views, consumers, async services), the test method must be `async def`. Use `create_async_api_client` (sync setUp) or `acreate_async_api_client` (async context) from `utils.test.auth`. Never wrap async code in `sync_to_async` or `asyncio.run` to force a sync test — auth will fail.

## 3. Assert Status Code with Response Content

Always pass `response.content` as the second argument to `assertEqual` on status codes. This makes failures self-explanatory. Expected codes: `201` for POST create, `200` for GET/PUT/PATCH, `204` for DELETE, `403` for permission denied.

- **Correct:** `self.assertEqual(response.status_code, 201, response.content)`
- **Incorrect:** `self.assertEqual(response.status_code, 201)`

## 4. Create Test Data with ORM Directly

Use `utils.test.auth.create_user()` for users and `.objects.create()` for all other models. No factory libraries.

## 5. Test Isolation Between Users

Verify that one user cannot see or modify another user's data. Create a second user/client and assert they get empty or forbidden responses for the first user's resources.

## 6. Mock External Services

Use `unittest.mock.patch` as a decorator or context manager for external calls (geocoding, push notifications, etc.). Always assert the mock was called with expected arguments.

## 7. WebSocket Test Cleanup

Always call `await communicator.disconnect()` at the end of WebSocket tests. For unauthorized WebSocket tests, assert close code `4401`.
