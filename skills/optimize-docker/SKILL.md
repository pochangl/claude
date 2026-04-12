---
name: optimize-docker
description: Use this skill to enforce Docker conventions. Triggers on mentions of "Dockerfile", "docker-compose", "entrypoint", "CMD", or when writing Docker configuration files.
---

## 1. Production commands in Dockerfile, dev overrides in docker-compose.yaml

`ENTRYPOINT` and `CMD` in the Dockerfile must contain the production command. Development commands (e.g. hot-reload, debug servers) belong in `docker-compose.yaml` via the `command:` override.

- **Correct:** Dockerfile `CMD ["gunicorn", "config.asgi:application", "-k", "uvicorn.workers.UvicornWorker"]`, docker-compose.yaml `command: python manage.py runserver 0.0.0.0:8000`
- **Incorrect:** Dockerfile `CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]`
