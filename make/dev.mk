ready:
	$(MAKE) generate-all && $(MAKE) sync-test-matrix && $(MAKE) test && $(MAKE) test-macos-unit && $(MAKE) test-macos-ui

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
