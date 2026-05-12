web-install:
	pnpm --dir $(WEB_APP_DIR) run install:react

web-cert:
	@command -v mkcert >/dev/null 2>&1 || (echo "mkcert is required. install from https://github.com/FiloSottile/mkcert" && exit 1)
	@mkdir -p $(WEB_CERT_DIR)
	@sh -c 'if [ -f ./.env.app.apple ]; then set -a; . ./.env.app.apple; set +a; elif [ -f ./.env.app ]; then set -a; . ./.env.app; set +a; fi; NAMES="localhost 127.0.0.1 ::1"; if [ -n "$${DEV_LAN_IP:-}" ]; then NAMES="$$NAMES $${DEV_LAN_IP}"; fi; mkcert -cert-file "$(WEB_CERT_FILE)" -key-file "$(WEB_KEY_FILE)" $$NAMES'

web-trust:
	@command -v mkcert >/dev/null 2>&1 || (echo "mkcert is required. install from https://github.com/FiloSottile/mkcert" && exit 1)
	mkcert -install

web-dev: web-cert
	pnpm --dir $(WEB_APP_DIR) dev

web-dev-local: web-cert
	@sh -c 'VITE_KANDO_API_BASE_URL="$${VITE_KANDO_API_BASE_URL:-http://127.0.0.1:8080}" pnpm --dir $(WEB_APP_DIR) dev'

web-open:
	@command -v xdg-open >/dev/null 2>&1 || (echo "xdg-open is required" && exit 1)
	@xdg-open "https://localhost:5173"

web-build:
	pnpm --dir $(WEB_APP_DIR) build

web-test:
	pnpm --dir $(WEB_APP_DIR) test

web-e2e-install:
	pnpm --dir $(WEB_APP_DIR) exec playwright install

web-e2e-deps:
	pnpm --dir $(WEB_APP_DIR) exec playwright install-deps chromium

web-e2e-deps-debian:
	sudo apt-get update
	sudo apt-get install -y libwoff1

web-test-e2e-headed:
	./scripts/web_e2e.sh --headed

web-test-e2e-ui:
	./scripts/web_e2e.sh --ui

web-test-e2e:
	./scripts/web_e2e.sh

web-storybook:
	@sh -c 'for ip in $$(hostname -I 2>/dev/null); do case "$$ip" in 192.*) echo "Storybook LAN (192): http://$$ip:6006/" ;; esac; done'
	pnpm --dir $(WEB_APP_DIR) storybook

web-storybook-build:
	pnpm --dir $(WEB_APP_DIR) build-storybook
