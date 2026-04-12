---
name: optimize-python
description: Use this skill to enforce Python code conventions. Triggers on mentions of "optimize python", "python convention", "import style", or when writing Python code.
---

## 1. No Imports Inside Functions

All imports must be at the top of the module. Do not import inside functions, methods, or local scopes.

- **Correct:** `import` at the top of the file
- **Incorrect:** `import` inside a function body
