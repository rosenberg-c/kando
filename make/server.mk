build:
	mkdir -p $(BIN_DIR)
	go build -o $(BIN_SERVER) $(APP_SERVER)
	go build -o $(BIN_CLI) $(APP_CLI)

kill-server:
	@PID=""; \
	if [ -f "$(SERVER_PID_FILE)" ]; then \
		PID="$$(cat "$(SERVER_PID_FILE)" 2>/dev/null || true)"; \
		if [ -n "$$PID" ] && kill -0 "$$PID" 2>/dev/null; then \
			kill "$$PID"; \
		fi; \
		rm -f "$(SERVER_PID_FILE)"; \
	fi; \
	PIDS="$$(lsof -t -nP -iTCP:$(SERVER_PORT) -sTCP:LISTEN 2>/dev/null || true)"; \
	if [ -n "$$PIDS" ]; then \
		kill $$PIDS; \
	fi

run: kill-server
	@sh -c 'KANBAN_REPOSITORY=appwrite go run $(APP_SERVER) & pid=$$!; echo $$pid > $(SERVER_PID_FILE); wait $$pid; code=$$?; rm -f $(SERVER_PID_FILE); exit $$code'

server-cert:
	@command -v mkcert >/dev/null 2>&1 || (echo "mkcert is required. install from https://github.com/FiloSottile/mkcert" && exit 1)
	@mkdir -p $(SERVER_CERT_DIR)
	@sh -c 'if [ -f ./.env.server ]; then set -a; . ./.env.server; set +a; fi; NAMES="localhost 127.0.0.1 ::1"; if [ -n "$${DEV_LAN_IP:-}" ]; then NAMES="$$NAMES $${DEV_LAN_IP}"; fi; mkcert -cert-file "$(SERVER_CERT_FILE)" -key-file "$(SERVER_KEY_FILE)" $$NAMES'

run-tls: kill-server server-cert
	@sh -c 'TLS_CERT_FILE="$(SERVER_CERT_FILE)" TLS_KEY_FILE="$(SERVER_KEY_FILE)" KANBAN_REPOSITORY=appwrite go run $(APP_SERVER) & pid=$$!; echo $$pid > $(SERVER_PID_FILE); wait $$pid; code=$$?; rm -f $(SERVER_PID_FILE); exit $$code'

fetch-remote-ca:
	@test -n "$(REMOTE_SSH)" || (echo "usage: make fetch-remote-ca REMOTE_SSH=user@host" && exit 1)
	@mkdir -p $(SERVER_CERT_DIR)
	@sh -c 'CAROOT="$$(ssh "$(REMOTE_SSH)" "mkcert -CAROOT")"; scp "$(REMOTE_SSH):$$CAROOT/rootCA.pem" "$(REMOTE_CA_PEM)"'

trust-remote-ca: fetch-remote-ca
	@security add-trusted-cert -d -r trustRoot -k "$${HOME}/Library/Keychains/login.keychain-db" "$(REMOTE_CA_PEM)"

trust-remote-ca-debian: fetch-remote-ca
	@sudo cp "$(REMOTE_CA_PEM)" /usr/local/share/ca-certificates/remote-rootCA.crt
	@sudo update-ca-certificates

run-sqlite: kill-server
	@sh -c 'KANBAN_REPOSITORY=sqlite SQLITE_PATH="$${SQLITE_PATH:-$(CURDIR)/data/kanban.db}" go run $(APP_SERVER) & pid=$$!; echo $$pid > $(SERVER_PID_FILE); wait $$pid; code=$$?; rm -f $(SERVER_PID_FILE); exit $$code'

run-sqlite-local: kill-server
	@sh -c 'CORS_ALLOWED_ORIGINS="$${CORS_ALLOWED_ORIGINS:-https://localhost:5173,https://127.0.0.1:5173,https://$${DEV_LAN_IP:-192.168.56.2}:5173}" KANBAN_REPOSITORY=sqlite SQLITE_PATH="$${SQLITE_PATH:-$(CURDIR)/data/kanban-local.db}" go run $(APP_SERVER) & pid=$$!; echo $$pid > $(SERVER_PID_FILE); wait $$pid; code=$$?; rm -f $(SERVER_PID_FILE); exit $$code'

appwrite-bootstrap:
	go run ./server/cmd/bootstrap_appwrite

appwrite-prune:
	go run ./server/cmd/prune_appwrite_schema

appwrite-prune-apply:
	go run ./server/cmd/prune_appwrite_schema --apply

verify-appwrite-schema:
	go run ./server/cmd/verify_appwrite_schema
