#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB_DIR="$ROOT_DIR/.tmp"
DB_PATH="$DB_DIR/web-e2e-$(date +%s)-$$.db"
E2E_ENV_FILE="$ROOT_DIR/.env.e2e.web"

if lsof -iTCP:8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "port 8080 is already in use; stop existing server first (for example: make server-stop)"
  exit 1
fi

if lsof -iTCP:5173 -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "port 5173 is already in use; stop existing web dev server before running real e2e"
  exit 1
fi

if [[ -f "$E2E_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$E2E_ENV_FILE"
  set +a
fi

if [[ -z "${KANDO_E2E_EMAIL:-}" || -z "${KANDO_E2E_PASSWORD:-}" ]]; then
  echo "missing KANDO_E2E_EMAIL or KANDO_E2E_PASSWORD (set them in .env.e2e.web or environment)"
  exit 1
fi

if [[ "${KANDO_E2E_PASSWORD}" == "replace-with-real-password" ]]; then
  echo "KANDO_E2E_PASSWORD is still the example placeholder; set real credentials in .env.e2e.web"
  exit 1
fi

mkdir -p "$DB_DIR"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -f "$DB_PATH"
}

trap cleanup EXIT INT TERM

(
  cd "$ROOT_DIR"
  CORS_ALLOWED_ORIGINS="https://127.0.0.1:5173,https://localhost:5173" \
  KANBAN_REPOSITORY=sqlite \
  SQLITE_PATH="$DB_PATH" \
  go run ./server
) &
SERVER_PID=$!

for _ in $(seq 1 50); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "backend exited before becoming ready"
    exit 1
  fi
  if curl -fsS "http://127.0.0.1:8080/hello" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

if ! curl -fsS "http://127.0.0.1:8080/hello" >/dev/null 2>&1; then
  echo "backend did not become ready on http://127.0.0.1:8080"
  exit 1
fi

cd "$ROOT_DIR"
make web-cert
pnpm --dir ./apps/web/react exec playwright test "$@"
