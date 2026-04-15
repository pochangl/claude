---
name: optimize-django
description: Use this skill to enforce Django naming conventions. Triggers on mentions of "optimize django", "naming convention", "singular model", "app name", or when creating new Django apps or models.
---

## 1. Singular Model Names

Django model class names must be singular. Django automatically pluralizes the model name for the database table and admin display via `verbose_name_plural`.

- **Correct:** `Project`, `Account`, `Collector`, `Route`
- **Incorrect:** `Projects`, `Accounts`, `Collectors`, `Routes`

## 2. Singular App Names

Django app directory names and `AppConfig.name` values must be singular when naming the core domain concept. If the app manages one primary model, the app name should match that model in singular, lowercase form.

- **Correct:** `project`, `account`, `route`
- **Incorrect:** `projects`, `accounts`, `routes`

## 3. Import Settings at Module Level

Always import `django.conf.settings` at the top of the module, not inline inside functions or methods. This ensures missing or misconfigured settings fail at import time rather than at runtime deep in a call stack.

- **Correct:**
  ```python
  from django.conf import settings

  CLAUDE_CLI_PATH = settings.CLAUDE_CLI_PATH
  ```
- **Incorrect:**
  ```python
  def run():
      from django.conf import settings
      cmd = [settings.CLAUDE_CLI_PATH, ...]
  ```

