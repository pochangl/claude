---
name: optimize-python
description: Use this skill to enforce Python code conventions. Triggers on mentions of "optimize python", "python convention", "import style", or when writing Python code.
---

## 1. No Imports Inside Functions

All imports must be at the top of the module. Do not import inside functions, methods, or local scopes.

- **Correct:** `import` at the top of the file
- **Incorrect:** `import` inside a function body

## 2. Do Not Fail Silently

Functions must not swallow errors and return early without raising or logging at a level that makes the failure visible to the caller. If a function cannot complete its purpose, it must either raise an exception or return a value that the caller can distinguish from success.

- **Do not** use bare `return` or `return None` after catching/detecting an error — the caller has no way to know the operation failed.
- **Do** raise an exception, or return a distinguishable error value, so callers can handle the failure.
- Logging the error is acceptable **in addition to** raising/returning an error, but logging alone is not sufficient — the caller must be informed.

```python
# Bad — caller thinks it succeeded
if result['returncode'] != 0:
    logger.error('Command failed: %s', result['stderr'])
    return

# Good — caller can handle the failure
if result['returncode'] != 0:
    raise RuntimeError(f'Command failed: {result["stderr"]}')
```
