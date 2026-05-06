# kando

Kanban-style todo app.

Backend is written in Go with:
- optional storage backend: Appwrite or SQLite
- authentication handled through Appwrite

Frontend availability:
- macOS app: available
- web app: work in progress
- CLI: work in progress

Workspace includes:
- Go backend API (`server/`)
- Web app (`apps/web/react`)
- CLI (`apps/cli`)

## Prerequisites

- Go
- Node.js + pnpm
- Make

## Quick start

1) Create local env files:

```bash
cp .env.server.example .env.server
cp .env.app.example .env.app
```

2) Generate API artifacts and run backend:

```bash
make generate
make run
```

Backend runs at `http://localhost:8080`.

3) Run tests:

```bash
make test-core
make test
pnpm --dir ./apps/web/react test
```

`make test` includes macOS unit tests when run on macOS with Xcode installed.

## Run clients

In another terminal:

```bash
make run-macos
```

For the web version (not fully implemented yet):

```bash
make web-dev
```

## Environment notes

- `KANDO_API_BASE_URL` configures CLI API endpoint.
- `APPWRITE_*` values are backend-only and must not be shipped to clients.
- Set Appwrite values only if you are using Appwrite-backed auth/storage.

## Appwrite setup

Required for auth:
- `APPWRITE_ENDPOINT`
- `APPWRITE_PROJECT_ID`
- `APPWRITE_AUTH_API_KEY` (server-side key with `sessions.write`)

Required for Appwrite storage backend:
- `APPWRITE_DB_API_KEY` (server-side key with TablesDB/table/column/index read+write)
- `APPWRITE_DB_ID`
- `APPWRITE_DB_NAME`
- `APPWRITE_BOARDS_COLLECTION_ID`
- `APPWRITE_COLUMNS_COLLECTION_ID`
- `APPWRITE_TASKS_COLLECTION_ID`

Initialize/verify Appwrite schema:

```bash
make appwrite-bootstrap
make verify-appwrite-schema
```

## Project docs

- Agent/process rules: `AGENT.md`
- Project constraints: `docs/PROJECT_RULES.md`
- Auth details: `docs/AUTH.md`
