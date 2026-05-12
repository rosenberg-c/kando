run-cli:
	go run $(APP_CLI)

cli-install:
	mkdir -p $(LOCAL_BIN_DIR)
	go build -o $(LOCAL_BIN_DIR)/todo $(APP_CLI)

install-cli: cli-install
