APP_SERVER := ./apps/server
BIN_DIR := ./bin
BIN_SERVER := $(BIN_DIR)/server

.PHONY: build run test

build:
	mkdir -p $(BIN_DIR)
	go build -o $(BIN_SERVER) $(APP_SERVER)

run:
	go run $(APP_SERVER)

test:
	go test ./...
