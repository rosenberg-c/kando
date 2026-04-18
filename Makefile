APP_SERVER := ./apps/server
APP_CLI := ./apps/cli
BIN_DIR := ./bin
BIN_SERVER := $(BIN_DIR)/server
BIN_CLI := $(BIN_DIR)/cli
LOCAL_BIN_DIR := $(HOME)/.local/bin

.PHONY: generate verify-generate build run run-cli test cli-install install-cli

generate:
	go run ./cmd/gen_openapi
	go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.4.1 -config api/oapi-codegen-client.yaml -o internal/api/generated/client/client.gen.go api/openapi.yaml

verify-generate: generate
	git diff --exit-code -- api/openapi.yaml internal/api/generated/client/client.gen.go

build:
	mkdir -p $(BIN_DIR)
	go build -o $(BIN_SERVER) $(APP_SERVER)
	go build -o $(BIN_CLI) $(APP_CLI)

run:
	go run $(APP_SERVER)

run-cli:
	go run $(APP_CLI)

cli-install:
	mkdir -p $(LOCAL_BIN_DIR)
	go build -o $(LOCAL_BIN_DIR)/todo $(APP_CLI)

install-cli: cli-install

test:
	go test ./...
