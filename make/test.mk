test:
	@. ./scripts/test_summary.sh; run_with_test_summary sh -c '$(MAKE) test-core && if command -v xcodebuild >/dev/null 2>&1; then $(MAKE) test-macos-unit; else echo "skipping test-macos-unit (xcodebuild not available)"; fi'

test-core:
	@. ./scripts/test_summary.sh; run_with_test_summary sh -c 'go test ./... && $(MAKE) verify-generate && $(MAKE) verify-test-matrix'

test-appwrite-integration:
	@. ./scripts/test_summary.sh; run_with_test_summary sh -c 'if [ -f ./.env.server ]; then set -a; . ./.env.server; set +a; else echo "warning: .env.server not found; using existing environment"; fi; $(MAKE) verify-appwrite-schema && RUN_APPWRITE_INTEGRATION=1 go test ./server/internal/kanban -run Appwrite'

test-api-backends:
	@. ./scripts/test_summary.sh; run_with_test_summary sh -c 'API_TEST_BACKEND=sqlite go test ./server/internal/api/server -run BackendMatrix'
	@. ./scripts/test_summary.sh; run_with_test_summary sh -c 'if [ "$${RUN_APPWRITE_MATRIX:-0}" = "1" ]; then if [ -f ./.env.server ]; then set -a; . ./.env.server; set +a; else echo "missing .env.server for appwrite backend matrix"; exit 1; fi; $(MAKE) appwrite-bootstrap && $(MAKE) verify-appwrite-schema && API_TEST_BACKEND=appwrite go test ./server/internal/api/server -run BackendMatrix; else echo "skipping appwrite matrix (set RUN_APPWRITE_MATRIX=1 to enable)"; fi'
