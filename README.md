# go_macos_todo

Minimal Go backend scaffold for the task app.

## API generation model

- Backend code is the source of truth.
- `make generate` performs:
  - Huma route definitions in backend code -> `api/openapi.yaml`
  - `api/openapi.yaml` -> generated Go client for CLI
- Backend OpenAPI is exported from the same registered operations used at runtime
- `make verify-generate` fails if generated artifacts are out of date

## Requirement-driven development (RDD)

- Requirements are defined and versioned in `docs/requirements/*.md`.
- Automated tests map back to requirements using `Requirement:` / `Requirements:` tags in test files.
- `docs/TEST_MATRIX.md` is the traceability map from requirement IDs to test references.
- `make test` now includes `make verify-test-matrix` to fail when the matrix is stale.

Useful commands:

```bash
make sync-test-matrix     # regenerate docs/TEST_MATRIX.md from requirement/test tags
make verify-test-matrix   # fail if docs/TEST_MATRIX.md is out of date
make test                 # go tests + matrix verify + macOS unit tests
```

## Environment Setup

1. Copy env template:

```bash
cp .env.server.example .env.server
cp .env.app.example .env.app
```

2. Configure backend settings in `.env.server`:

```env
KANBAN_REPOSITORY=memory
SQLITE_PATH=./data/kanban.db

APPWRITE_ENDPOINT=https://<REGION>.cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=your_project_id
APPWRITE_AUTH_API_KEY=your_server_key_with_sessions_write
APPWRITE_DB_API_KEY=your_server_key_with_tablesdb/tables/columns/indexes read+write scopes
APPWRITE_DB_ID=task
APPWRITE_DB_NAME=Task
APPWRITE_BOARDS_COLLECTION_ID=boards
APPWRITE_COLUMNS_COLLECTION_ID=columns
APPWRITE_TASKS_COLLECTION_ID=tasks
LOG_WARN_MB=5
LOG_MAX_MB=10
```

Set `KANBAN_REPOSITORY` to one of:

- `memory` (default when Appwrite env is not set)
- `sqlite` (stores data in `SQLITE_PATH`)
- `appwrite` (default when Appwrite env is set)

`APPWRITE_*` values are required only when using Appwrite auth/repository.

`LOG_WARN_MB` logs a startup warning when `logs/server.log` exceeds the threshold. `LOG_MAX_MB` fails startup when exceeded.

3. Configure CLI app settings in `.env.app`:

```env
TODO_API_BASE_URL=http://localhost:8080
```

For non-local environments, use `https://...` for `TODO_API_BASE_URL`.

`APPWRITE_AUTH_API_KEY` and `APPWRITE_DB_API_KEY` are backend-only. Do not use them in the CLI or ship them in binaries.

### Bootstrap Appwrite schema

Provision the database/collections/attributes/indexes via API:

```bash
make appwrite-bootstrap
```

This command is idempotent and safe to re-run.

### Prune Appwrite schema

Preview removals for unused tables/columns/indexes:

```bash
make appwrite-prune
```

Apply deletions:

```bash
APPWRITE_PRUNE_CONFIRM=YES \
make appwrite-prune-apply
```

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
ui/strings/en/tasks.json
```
