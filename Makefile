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
TEST_MATRIX_REPO ?= ../test-matrix
WEB_APP_DIR := ./apps/web/react

.PHONY: generate verify-generate sync-test-matrix verify-test-matrix build build-macos run run-sqlite run-cli run-macos open-macos open ready test test-core test-macos-unit test-macos-ui test-appwrite-integration test-api-backends cli-install install-cli install-go appwrite-bootstrap appwrite-prune appwrite-prune-apply verify-appwrite-schema kill-server web-install web-dev web-build web-test

generate:
	go run ./server/cmd/gen_openapi
	go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.4.1 -config server/api/oapi-codegen-client.yaml -o generated/api/client/client.gen.go server/api/openapi.yaml
	pnpm --dir $(WEB_APP_DIR) run generate:api
	go run ./server/cmd/gen_appwrite_schema

verify-generate: generate
	git diff --exit-code -- server/api/openapi.yaml generated/api/client/client.gen.go server/api/appwrite-schema.json apps/web/react/app/src/generated/api

sync-test-matrix:
	@test -d $(TEST_MATRIX_REPO) || (echo "missing $(TEST_MATRIX_REPO) dependency; clone it beside this repo or set TEST_MATRIX_REPO" && exit 1)
	cd $(TEST_MATRIX_REPO) && go run ./cmd/sync_test_matrix -config $(CURDIR)/docs/test-matrix.config.json -apply

verify-test-matrix:
	@test -d $(TEST_MATRIX_REPO) || (echo "missing $(TEST_MATRIX_REPO) dependency; clone it beside this repo or set TEST_MATRIX_REPO" && exit 1)
	cd $(TEST_MATRIX_REPO) && go run ./cmd/sync_test_matrix -config $(CURDIR)/docs/test-matrix.config.json

build:
	mkdir -p $(BIN_DIR)
	go build -o $(BIN_SERVER) $(APP_SERVER)
	go build -o $(BIN_CLI) $(APP_CLI)

build-macos:
	xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) build

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
	@sh -c 'if [ -f ./.env.app ]; then set -a; . ./.env.app; set +a; fi; API_BASE_URL="$${KANDO_API_BASE_URL:-http://localhost:8080}"; xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) build && open "$(MACOS_DERIVED)/Build/Products/Debug/$(MACOS_SCHEME).app" --args --api-base-url "$$API_BASE_URL"'

open-macos:
	open "$(MACOS_DERIVED)/Build/Products/Debug/$(MACOS_SCHEME).app"

open: open-macos

ready:
	$(MAKE) generate && $(MAKE) sync-test-matrix && $(MAKE) test && $(MAKE) test-macos-unit && $(MAKE) test-macos-ui

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

web-dev:
	pnpm --dir $(WEB_APP_DIR) dev

web-build:
	pnpm --dir $(WEB_APP_DIR) build

web-test:
	pnpm --dir $(WEB_APP_DIR) test
