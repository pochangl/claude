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

