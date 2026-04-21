APP_SERVER := ./apps/server
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

.PHONY: generate verify-generate sync-test-matrix verify-test-matrix build run run-cli run-macos open-macos open test test-macos-unit test-appwrite-integration cli-install install-cli appwrite-bootstrap appwrite-prune appwrite-prune-apply

generate:
	go run ./cmd/gen_openapi
	go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.4.1 -config api/oapi-codegen-client.yaml -o internal/api/generated/client/client.gen.go api/openapi.yaml
	go run ./cmd/gen_appwrite_schema

verify-generate: generate
	git diff --exit-code -- api/openapi.yaml internal/api/generated/client/client.gen.go api/appwrite-schema.json

sync-test-matrix:
	go run ./cmd/sync_test_matrix -apply

verify-test-matrix:
	go run ./cmd/sync_test_matrix

build:
	mkdir -p $(BIN_DIR)
	go build -o $(BIN_SERVER) $(APP_SERVER)
	go build -o $(BIN_CLI) $(APP_CLI)

run:
	go run $(APP_SERVER)

appwrite-bootstrap:
	go run ./cmd/bootstrap_appwrite

appwrite-prune:
	go run ./cmd/prune_appwrite_schema

appwrite-prune-apply:
	go run ./cmd/prune_appwrite_schema --apply

run-cli:
	go run $(APP_CLI)

run-macos:
	killall "$(MACOS_SCHEME)" >/dev/null 2>&1 || true
	xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) build && open "$(MACOS_DERIVED)/Build/Products/Debug/$(MACOS_SCHEME).app"

open-macos:
	open "$(MACOS_DERIVED)/Build/Products/Debug/$(MACOS_SCHEME).app"

open: open-macos

cli-install:
	mkdir -p $(LOCAL_BIN_DIR)
	go build -o $(LOCAL_BIN_DIR)/todo $(APP_CLI)

install-cli: cli-install

test:
	go test ./...
	$(MAKE) verify-generate
	$(MAKE) verify-test-matrix
	$(MAKE) test-macos-unit

test-macos-unit:
	xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_UNIT_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) test CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

test-appwrite-integration:
	if [ -f ./.env.server ]; then set -a; . ./.env.server; set +a; else echo "warning: .env.server not found; using existing environment"; fi; RUN_APPWRITE_INTEGRATION=1 go test ./internal/kanban -run Appwrite
