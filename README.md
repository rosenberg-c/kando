# go_macos_todo

Minimal Go backend scaffold for the todo app.

## API generation model

- Backend code is the source of truth.
- `make generate` performs:
  - Huma route definitions in backend code -> `api/openapi.yaml`
  - `api/openapi.yaml` -> generated Go client for CLI
- Backend OpenAPI is exported from the same registered operations used at runtime
- `make verify-generate` fails if generated artifacts are out of date

## Environment Setup

1. Copy env template:

```bash
cp .env.server.example .env.server
cp .env.app.example .env.app
```

2. Configure backend settings in `.env.server`:

```env
APPWRITE_ENDPOINT=https://<REGION>.cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=your_project_id
APPWRITE_AUTH_API_KEY=your_server_key_with_sessions_write
LOG_WARN_MB=5
LOG_MAX_MB=10
```

`LOG_WARN_MB` logs a startup warning when `logs/server.log` exceeds the threshold. `LOG_MAX_MB` fails startup when exceeded.

3. Configure CLI app settings in `.env.app`:

```env
TODO_API_BASE_URL=http://localhost:8080
```

For non-local environments, use `https://...` for `TODO_API_BASE_URL`.

`APPWRITE_AUTH_API_KEY` is backend-only. Do not use it in the CLI or ship it in binaries.

## Run

```bash
make generate
make run
```

Server starts on `http://localhost:8080` with `GET /hello`.

## CLI auth

```bash
make install-cli
todo login --email you@example.com
todo me
todo logout
```

The CLI stores auth state in user config and refreshes JWT on expiry or one-time `401` retry.
The CLI talks only to the Go backend (`TODO_API_BASE_URL`) and does not call Appwrite directly.
Use `--password-stdin` for non-interactive login in scripts.

## Auth docs

See `docs/AUTH.md`.

## UI text convention

All user-facing UI text should be defined in externalized resource files, grouped by feature/domain rather than hardcoded in views.

Example:

```txt
ui/strings/en/common.json
ui/strings/en/auth.json
ui/strings/en/todos.json
```
