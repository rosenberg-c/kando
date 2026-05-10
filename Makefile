APP_SERVER := ./server
APP_CLI := ./apps/cli
APP_MACOS := ./apps/apple
MACOS_XCODEPROJ := $(APP_MACOS)/Sources/Todo/TodoMacOS.xcodeproj
MACOS_SCHEME := TodoMacOS
MACOS_UNIT_SCHEME := TodoMacOSUnit
MACOS_DERIVED := $(APP_MACOS)/.derived
BIN_DIR := ./bin
BIN_SERVER := $(BIN_DIR)/server
BIN_CLI := $(BIN_DIR)/cli
LOCAL_BIN_DIR := $(HOME)/.local/bin
SERVER_PORT := 8080
SERVER_PID_FILE := .server.pid
SPECSYNC ?= specsync
WEB_APP_DIR := ./apps/web/react
WEB_VITE_APP_DIR := $(WEB_APP_DIR)/app
WEB_CERT_DIR := $(WEB_VITE_APP_DIR)/.cert
WEB_CERT_FILE := $(WEB_CERT_DIR)/localhost.pem
WEB_KEY_FILE := $(WEB_CERT_DIR)/localhost-key.pem
SERVER_CERT_DIR := ./certs
SERVER_CERT_FILE := $(SERVER_CERT_DIR)/server.pem
SERVER_KEY_FILE := $(SERVER_CERT_DIR)/server-key.pem
REMOTE_CA_PEM := $(SERVER_CERT_DIR)/remote-rootCA.pem
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister

.PHONY: generate-backend generate-web-api generate-apple-api generate-macos-iconset generate-all verify-generate sync-test-matrix verify-test-matrix build build-macos clean-macos run run-tls run-sqlite run-cli run-macos open-macos open ready test test-core test-macos-unit test-macos-ui test-appwrite-integration test-api-backends cli-install install-cli install-go appwrite-bootstrap appwrite-prune appwrite-prune-apply verify-appwrite-schema kill-server web-install web-cert web-trust web-dev web-build web-test web-storybook web-storybook-build server-cert fetch-remote-ca trust-remote-ca

generate-backend:
	go run ./server/cmd/gen_openapi
	go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.4.1 -config server/api/oapi-codegen-client.yaml -o generated/api/client/client.gen.go api/openapi.yaml
	go run ./server/cmd/gen_appwrite_schema

generate-web-api:
	pnpm --dir $(WEB_APP_DIR) run generate:api

generate-apple-api:
	swift package --package-path $(APP_MACOS) plugin --allow-writing-to-package-directory generate-code-from-openapi

generate-macos-iconset:
	export_image --source ./art/svg/icon.svg --layer-name "main-1" --target ./art/export/main.png
	generate_iconset --source ./art/export/main.png --target ./apps/apple/Sources/Todo/TodoMacOS/Assets.xcassets --name AppIcon.appiconset

generate-all: generate-backend generate-web-api generate-apple-api

verify-generate: generate-backend
	git diff --exit-code -- api/openapi.yaml generated/api/client/client.gen.go server/api/appwrite-schema.json apps/web/react/app/src/generated/api

sync-test-matrix:
	@command -v $(SPECSYNC) >/dev/null 2>&1 || (echo "$(SPECSYNC) is required but was not found in PATH" && exit 1)
	$(SPECSYNC) -config $(CURDIR)/docs/test-matrix.config.json -apply

verify-test-matrix:
	@command -v $(SPECSYNC) >/dev/null 2>&1 || (echo "$(SPECSYNC) is required but was not found in PATH" && exit 1)
	$(SPECSYNC) -config $(CURDIR)/docs/test-matrix.config.json

build:
	mkdir -p $(BIN_DIR)
	go build -o $(BIN_SERVER) $(APP_SERVER)
	go build -o $(BIN_CLI) $(APP_CLI)

build-macos:
	xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) build

clean-macos:
	rm -rf "$(MACOS_DERIVED)"
	rm -rf "$(APP_MACOS)/.build"
	@sh -c 'rm -rf "$${HOME}/Library/Developer/Xcode/DerivedData/TodoMacOS-"* "$${HOME}/Library/Developer/Xcode/DerivedData/TodoMacOSApp-"* 2>/dev/null || true'

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

run-sqlite: kill-server
	@sh -c 'KANBAN_REPOSITORY=sqlite SQLITE_PATH="$${SQLITE_PATH:-$(CURDIR)/data/kanban.db}" go run $(APP_SERVER) & pid=$$!; echo $$pid > $(SERVER_PID_FILE); wait $$pid; code=$$?; rm -f $(SERVER_PID_FILE); exit $$code'

appwrite-bootstrap:
	go run ./server/cmd/bootstrap_appwrite

appwrite-prune:
	go run ./server/cmd/prune_appwrite_schema

appwrite-prune-apply:
	go run ./server/cmd/prune_appwrite_schema --apply

verify-appwrite-schema:
	go run ./server/cmd/verify_appwrite_schema

run-cli:
	go run $(APP_CLI)

run-macos:
	killall "$(MACOS_SCHEME)" >/dev/null 2>&1 || true
	@sh -c 'if [ -f ./.env.app.apple ]; then set -a; . ./.env.app.apple; set +a; elif [ -f ./.env.app ]; then set -a; . ./.env.app; set +a; fi; API_BASE_URL="$${KANDO_API_BASE_URL:-http://localhost:8080}"; APP_PATH="$(MACOS_DERIVED)/Build/Products/Debug/$(MACOS_SCHEME).app"; xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) build && "$(LSREGISTER)" -f -R "$$APP_PATH" && open -n "$$APP_PATH" --args --api-base-url "$$API_BASE_URL"'

open-macos:
	open "$(MACOS_DERIVED)/Build/Products/Debug/$(MACOS_SCHEME).app"

open: open-macos

ready:
	$(MAKE) generate-all && $(MAKE) sync-test-matrix && $(MAKE) test && $(MAKE) test-macos-unit && $(MAKE) test-macos-ui

cli-install:
	mkdir -p $(LOCAL_BIN_DIR)
	go build -o $(LOCAL_BIN_DIR)/todo $(APP_CLI)

install-cli: cli-install

install-go:
	@if command -v go >/dev/null 2>&1; then \
		echo "Go is already installed: $$(go version)"; \
	elif command -v brew >/dev/null 2>&1; then \
		brew install go; \
		echo "Installed Go: $$(go version)"; \
	else \
		echo "Go is not installed and Homebrew was not found."; \
		echo "Install Homebrew from https://brew.sh and run 'make install-go' again."; \
		exit 1; \
	fi

test:
	@. ./scripts/test_summary.sh; run_with_test_summary sh -c '$(MAKE) test-core && if command -v xcodebuild >/dev/null 2>&1; then $(MAKE) test-macos-unit; else echo "skipping test-macos-unit (xcodebuild not available)"; fi'

test-core:
	@. ./scripts/test_summary.sh; run_with_test_summary sh -c 'go test ./... && $(MAKE) verify-generate && $(MAKE) verify-test-matrix'

test-macos-unit:
	@. ./scripts/test_summary.sh; run_with_test_summary xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_UNIT_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) test CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

test-macos-ui:
	@. ./scripts/test_summary.sh; run_with_test_summary xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) -only-testing:TodoMacOSUITests test

test-appwrite-integration:
	@. ./scripts/test_summary.sh; run_with_test_summary sh -c 'if [ -f ./.env.server ]; then set -a; . ./.env.server; set +a; else echo "warning: .env.server not found; using existing environment"; fi; $(MAKE) verify-appwrite-schema && RUN_APPWRITE_INTEGRATION=1 go test ./server/internal/kanban -run Appwrite'

test-api-backends:
	@. ./scripts/test_summary.sh; run_with_test_summary sh -c 'API_TEST_BACKEND=sqlite go test ./server/internal/api/server -run BackendMatrix'
	@. ./scripts/test_summary.sh; run_with_test_summary sh -c 'if [ "$${RUN_APPWRITE_MATRIX:-0}" = "1" ]; then if [ -f ./.env.server ]; then set -a; . ./.env.server; set +a; else echo "missing .env.server for appwrite backend matrix"; exit 1; fi; $(MAKE) appwrite-bootstrap && $(MAKE) verify-appwrite-schema && API_TEST_BACKEND=appwrite go test ./server/internal/api/server -run BackendMatrix; else echo "skipping appwrite matrix (set RUN_APPWRITE_MATRIX=1 to enable)"; fi'

web-install:
	pnpm --dir $(WEB_APP_DIR) run install:react

web-cert:
	@command -v mkcert >/dev/null 2>&1 || (echo "mkcert is required. install from https://github.com/FiloSottile/mkcert" && exit 1)
	@mkdir -p $(WEB_CERT_DIR)
	@sh -c 'if [ -f ./.env.app.apple ]; then set -a; . ./.env.app.apple; set +a; elif [ -f ./.env.app ]; then set -a; . ./.env.app; set +a; fi; NAMES="localhost 127.0.0.1 ::1"; if [ -n "$${DEV_LAN_IP:-}" ]; then NAMES="$$NAMES $${DEV_LAN_IP}"; fi; mkcert -cert-file "$(WEB_CERT_FILE)" -key-file "$(WEB_KEY_FILE)" $$NAMES'

web-trust:
	@command -v mkcert >/dev/null 2>&1 || (echo "mkcert is required. install from https://github.com/FiloSottile/mkcert" && exit 1)
	mkcert -install

web-dev: web-cert
	pnpm --dir $(WEB_APP_DIR) dev

web-build:
	pnpm --dir $(WEB_APP_DIR) build

web-test:
	pnpm --dir $(WEB_APP_DIR) test

web-storybook:
	@sh -c 'for ip in $$(hostname -I 2>/dev/null); do case "$$ip" in 192.*) echo "Storybook LAN (192): http://$$ip:6006/" ;; esac; done'
	pnpm --dir $(WEB_APP_DIR) storybook

web-storybook-build:
	pnpm --dir $(WEB_APP_DIR) build-storybook
