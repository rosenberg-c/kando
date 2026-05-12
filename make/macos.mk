build-macos:
	xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) build

clean-macos:
	rm -rf "$(MACOS_DERIVED)"
	rm -rf "$(APP_MACOS)/.build"
	@sh -c 'rm -rf "$${HOME}/Library/Developer/Xcode/DerivedData/TodoMacOS-"* "$${HOME}/Library/Developer/Xcode/DerivedData/TodoMacOSApp-"* 2>/dev/null || true'

run-macos:
	killall "$(MACOS_SCHEME)" >/dev/null 2>&1 || true
	@sh -c 'if [ -f ./.env.app.apple ]; then set -a; . ./.env.app.apple; set +a; elif [ -f ./.env.app ]; then set -a; . ./.env.app; set +a; fi; API_BASE_URL="$${KANDO_API_BASE_URL:-http://localhost:8080}"; APP_PATH="$(MACOS_DERIVED)/Build/Products/Debug/$(MACOS_SCHEME).app"; xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) build && "$(LSREGISTER)" -f -R "$$APP_PATH" && open -n "$$APP_PATH" --args --api-base-url "$$API_BASE_URL"'

open-macos:
	open "$(MACOS_DERIVED)/Build/Products/Debug/$(MACOS_SCHEME).app"

open: open-macos

test-macos-unit:
	@. ./scripts/test_summary.sh; run_with_test_summary xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_UNIT_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) test CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

test-macos-ui:
	@. ./scripts/test_summary.sh; run_with_test_summary xcodebuild -skipPackagePluginValidation -project $(MACOS_XCODEPROJ) -scheme $(MACOS_SCHEME) -configuration Debug -derivedDataPath $(MACOS_DERIVED) -only-testing:TodoMacOSUITests test
