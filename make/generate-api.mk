generate-backend:
	go run ./server/cmd/gen_openapi
	go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.4.1 -config server/api/oapi-codegen-client.yaml -o generated/api/client/client.gen.go api/openapi.yaml
	go run ./server/cmd/gen_appwrite_schema

generate-web-api:
	pnpm --dir $(WEB_APP_DIR) run generate:api

generate-apple-api:
	swift package --package-path $(APP_MACOS) plugin --allow-writing-to-package-directory generate-code-from-openapi

generate-all: generate-backend generate-web-api generate-apple-api

verify-generate: generate-backend
	git diff --exit-code -- api/openapi.yaml generated/api/client/client.gen.go server/api/appwrite-schema.json apps/web/react/app/src/generated/api

sync-test-matrix:
	@command -v $(SPECSYNC) >/dev/null 2>&1 || (echo "$(SPECSYNC) is required but was not found in PATH" && exit 1)
	$(SPECSYNC) -config $(CURDIR)/docs/test-matrix.config.json -apply

verify-test-matrix:
	@command -v $(SPECSYNC) >/dev/null 2>&1 || (echo "$(SPECSYNC) is required but was not found in PATH" && exit 1)
	$(SPECSYNC) -config $(CURDIR)/docs/test-matrix.config.json
