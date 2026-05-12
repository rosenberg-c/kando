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
WEB_PUBLIC_DIR := $(WEB_VITE_APP_DIR)/public
WEB_FAVICON_SVG := $(WEB_PUBLIC_DIR)/favicon.svg
WEB_CERT_DIR := $(WEB_VITE_APP_DIR)/.cert
WEB_CERT_FILE := $(WEB_CERT_DIR)/localhost.pem
WEB_KEY_FILE := $(WEB_CERT_DIR)/localhost-key.pem
SERVER_CERT_DIR := ./certs
SERVER_CERT_FILE := $(SERVER_CERT_DIR)/server.pem
SERVER_KEY_FILE := $(SERVER_CERT_DIR)/server-key.pem
REMOTE_CA_PEM := $(SERVER_CERT_DIR)/remote-rootCA.pem
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister

.PHONY: iconset generate-backend generate-web-api generate-apple-api generate-macos-iconset generate-web-iconset generate-all verify-generate sync-test-matrix verify-test-matrix build build-macos clean-macos run run-tls run-sqlite run-cli run-macos open-macos open ready test test-core test-macos-unit test-macos-ui test-appwrite-integration test-api-backends \
	cli-install install-cli install-go appwrite-bootstrap appwrite-prune appwrite-prune-apply verify-appwrite-schema kill-server web-install web-cert web-trust web-dev web-dev-local web-open web-build web-test web-test-e2e web-test-e2e-headed web-test-e2e-ui web-e2e-install web-e2e-deps web-e2e-deps-debian run-sqlite-local web-storybook web-storybook-build server-cert fetch-remote-ca trust-remote-ca trust-remote-ca-debian

include make/generate-api.mk
include make/generate-icons.mk
include make/server.mk
include make/macos.mk
include make/dev.mk
include make/tui.mk
include make/test.mk
include make/web.mk
