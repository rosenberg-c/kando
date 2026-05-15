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

API contract workflow:
- Backend route/schema code is the source of truth.
- `api/openapi.yaml` is generated from backend code (`make generate-backend`).

## Prerequisites

- Go
- Node.js + pnpm
- Make
- mkcert (required for HTTPS dev targets like `make server-run-tls` and `make web-dev`)

If `make web-install` fails with `ERR_PNPM_IGNORED_BUILDS` (for example `esbuild`):

```bash
pnpm --dir ./apps/web/react approve-builds
```

Approve the prompted build dependencies, then rerun `make web-install`.

## Quick start

1) Create local env files:

```bash
cp .env.server.example .env.server
cp .env.app.apple.example .env.app.apple
cp .env.app.web.example .env.app.web
```

2) Generate API artifacts and run backend:

```bash
make generate-backend
make server-run
```

Backend runs at `http://localhost:8080`.

For HTTPS backend (recommended for web auth dev):

```bash
make server-run-tls
```

This generates local certs in `certs/` (via `mkcert`) and starts backend at `https://localhost:8080`.

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
make macos-run
```

For the web version (not fully implemented yet):

```bash
make web-dev
```

`make web-dev` generates local HTTPS certs in `apps/web/react/app/.cert/` (via `mkcert`) and starts Vite at `https://localhost:5173`.

## HTTPS web auth dev (same machine)

Use this setup when testing cookie-based web auth:

1) Backend:

```bash
make server-run-tls
```

2) Web app env (`.env.app.web`):

```env
VITE_KANDO_API_BASE_URL=https://localhost:8080
```

3) Frontend:

```bash
make web-dev
```

Notes:
- In dev, frontend uses `/api` and Vite proxies to `VITE_KANDO_API_BASE_URL`.
- Set `AUTH_REFRESH_COOKIE_PATH=/api/auth` in `.env.server` when using the Vite `/api` proxy.
- Set `AUTH_ACCESS_COOKIE_PATH=/api` in `.env.server` so cookie-authenticated API calls (for example `/api/me`) receive the access cookie.
- This avoids browser mixed-content and cross-site fetch-metadata issues during login/refresh/logout.

## HTTPS web auth dev (frontend and backend on different machines)

Example:
- frontend machine: `192.168.56.2`
- backend machine: `192.168.56.3`

Backend machine:
- set `DEV_LAN_IP=192.168.56.3` in `.env.server` (used by `make server-cert`/`make server-run-tls`)
- set `CORS_ALLOWED_ORIGINS=https://192.168.56.2:5173`
- set `AUTH_REFRESH_COOKIE_PATH=/api/auth`
- set `AUTH_ACCESS_COOKIE_PATH=/api`
- run `make server-run-tls`

Frontend machine:
- set `DEV_LAN_IP=192.168.56.2` in `.env.app.apple` (used by `make web-cert`/`make web-dev`)
- set `VITE_KANDO_API_BASE_URL=https://192.168.56.3:8080` in `.env.app.web`
- run `make web-dev`

Open from browser:
- `https://192.168.56.2:5173`

## macOS client over HTTPS (backend on different machine)

Use this when running the macOS app against a LAN backend over TLS.

Backend machine:
- set `DEV_LAN_IP=<backend-lan-ip>` in `.env.server`
- run `make server-cert` (or `make server-run-tls`, which depends on it)
- run `make server-run-tls`

macOS machine (this repo):
1) Trust the backend machine's `mkcert` root CA (copied over SSH):

```bash
make trust-remote-ca REMOTE_SSH=<ssh-host-or-alias>
```

Example with SSH config alias:

```bash
make trust-remote-ca REMOTE_SSH=deb-dev3
```

2) Point the macOS app to backend HTTPS URL in `.env.app.apple`:

```env
KANDO_API_BASE_URL=https://<backend-lan-ip>:8080
```

3) Run app:

```bash
make macos-run
```

Notes:
- `make trust-remote-ca` fetches remote `rootCA.pem` via `ssh`/`scp` and imports it into your macOS login keychain.
- Trusting this CA on your Mac also applies to browsers that use the macOS trust store (for example Safari and Chrome).
- Firefox may use its own certificate store depending on settings.
- If cert trust or hostname does not match, macOS requests may fail with `NSURLErrorDomain Code=-1202`.

## Environment notes

- `KANDO_API_BASE_URL` configures CLI API endpoint.
- `VITE_KANDO_API_BASE_URL` configures Vite proxy target for web dev and direct base URL for production web builds.
- `AUTH_REFRESH_COOKIE_PATH` controls the refresh cookie path. Use `/auth` for direct backend routing and `/api/auth` behind the web proxy.
- `AUTH_ACCESS_COOKIE_PATH` controls the access cookie path used for browser API authentication. Use `/` for direct routing and `/api` behind the web proxy.
- `DEV_LAN_IP` is used only for cert generation (`make web-cert` and `make server-cert`). Use the LAN IP of the machine running that dev server.
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
