---
name: optimize-adrf
description: Use this skill to audit and optimize ADRF API endpoint performance. Triggers on mentions of "optimize", "slow endpoint", "N+1", "query optimization", "prefetch", "select_related", "pagination", or "API performance".
---

## 1. Use ModelViewSet for CRUD

If the endpoint performs CRUD on a single database table, it must be implemented with `adrf.viewsets.ModelViewSet` (not a plain `APIView` or `ViewSet` with manual query logic). Convert any hand-rolled CRUD to a ModelViewSet with `queryset`, `serializer_class`, and the appropriate `get_queryset()` override. A ViewSet must not contain `@action` methods that perform CRUD on a different table — split those into their own ModelViewSet with a separate route.

## 2. Use Authentication and Permission Classes

Authentication must be handled by DRF authentication classes (`authentication_classes`), not manual token/session checks in view methods. Authorization must be handled by DRF permission classes (`permission_classes`), not inline `if not authorized: return 403` patterns. Extract any manual auth/authz logic into reusable classes and set them on the view or action.

## 3. Add select_related / prefetch_related Required by Serializer

Trace every field in the serializer. Any `source="fk.field"` or `SerializerMethodField` that traverses a relationship must have a matching `select_related` (for ForeignKey/OneToOne) or `prefetch_related` (for reverse FK/ManyToMany) in the view's `get_queryset()`. Missing these causes N+1 queries.

**Do not prefetch related objects that already have their own dedicated ViewSet/endpoint.** If a related model is managed by a separate ViewSet (e.g. `ProjectMembershipViewSet`), the client should fetch that data from its own endpoint rather than having it embedded via prefetch in the parent ViewSet. Only prefetch relationships that are not exposed as standalone endpoints.

## 4. Use FilterSet for Filtering

Query parameter filtering must be implemented with `django_filters.FilterSet` (`filterset_class`) — not manual `request.query_params.get()` logic in `get_queryset()`. Extract any inline filtering into a FilterSet class.

## 5. Ensure Async Implementation

All view methods must be `async def` using `adrf` base classes. ORM calls must use async variants (`aget`, `acreate`, `aexists`, `asave`, `aupdate`, `adelete`). ViewSet hooks must use `a`-prefixed versions (`perform_acreate`, `perform_aupdate`, `perform_adestroy`). Blocking I/O must be wrapped in `asyncio.to_thread()` and CPU-bound work in `ProcessPoolExecutor`.

The async stack must be wired end to end:

- **Routers** must be `adrf.routers.DefaultRouter` / `SimpleRouter`, **not** `rest_framework.routers.*`. The adrf router maps the default action names (`create`/`list`/`retrieve`/`update`/`partial_update`/`destroy`) to their async counterparts (`acreate`/`alist`/...). Using DRF's router with adrf viewsets dispatches to sync DRF mixin methods, which call sync ORM and crash with `SynchronousOnlyOperation` under ASGI.
- **ModelSerializers** must subclass `adrf.serializers.ModelSerializer`, **not** `rest_framework.serializers.ModelSerializer`. Only the adrf base exposes `acreate` / `aupdate` / `asave` (which adrf's `CreateModelMixin.perform_acreate` calls).

## 6. Push Mutation Logic into the Serializer

Custom creation/update logic must live in `serializer.acreate(validated_data)` / `serializer.aupdate(instance, validated_data)` — **not** in viewset action overrides. The ViewSet should declare only `queryset`, `serializer_class`, `filterset_class`, `permission_classes`, etc., with no `create()` / `list()` / `update()` overrides, so adrf's mixin defaults dispatch unchanged.

Side-effecty steps that belong inside `acreate`:

- Resolving or auto-creating parent FKs (e.g. `aget_or_create` for related models that the request implies should exist).
- Idempotency lookups (return the existing row if it already exists, skip the work).
- External service calls whose result is persisted on the model (e.g. an LLM/translation/transcription call that produces a derived field).

Pop non-model lookup keys (see Rule 7) from `validated_data` before calling `Model.objects.acreate(**validated_data)` so the kwargs match model fields.

## 7. Use Write-Only Fields for Resolution Params

When the API accepts fields that are **not** model fields but are needed to resolve or create a related FK (e.g. `oaid` + `uid` to look up / create a `Conversation`), declare them on the serializer as `serializers.CharField(write_only=True, ...)` and pop them from `validated_data` inside `acreate`. Never accept them via the URL path or out-of-band kwargs — keep them as serializer fields so DRF validation, error formatting, and OpenAPI docs all see them.

When the API field name differs from the model field name, use `source="model_field_name"` instead of renaming in the view (e.g. an API `text` field that maps to a model `original_text` column → `text = serializers.CharField(write_only=True, source="original_text")`). Mark fields the client should see in responses but never provide as input via `read_only_fields` in `Meta`.

## 8. One Serializer per ModelViewSet

Each ModelViewSet must use a single `serializer_class`. Do not override `get_serializer_class()` to return different serializers per action. Instead, merge list and detail fields into one serializer. For fields that rely on prefetched attributes (e.g. `to_attr`), use `getattr(obj, attr, default)` in `SerializerMethodField` so the field gracefully returns a default when the prefetch is absent (e.g. on create responses).

## 9. Singular API Paths

URL path segments must use singular nouns, not plural. DRF routers default to pluralizing — override with `basename` or explicit `path()` registration to keep paths singular.

- **Correct:** `/api/project/`, `/api/account/`, `/api/route/`
- **Incorrect:** `/api/projects/`, `/api/accounts/`, `/api/routes/`

## 10. Guard with Test Cases

Every API endpoint must have test coverage. After optimizing, verify existing tests still pass. If tests don't exist, add them covering success paths, permission/auth failures, and edge cases. Use the `optimize-django-test` skill for test conventions.
