import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  timeout: 30_000,
  expect: {
    timeout: 5_000,
  },
  use: {
    baseURL: "https://127.0.0.1:5173",
    ignoreHTTPSErrors: true,
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command: "pnpm --dir ./app dev --host 127.0.0.1 --port 5173 --strictPort",
    env: {
      VITE_KANDO_USE_TEST_API_BASE_URL: "1",
      VITE_KANDO_API_BASE_URL_TEST: "/api",
      VITE_KANDO_API_BASE_URL: "http://127.0.0.1:8080",
    },
    port: 5173,
    reuseExistingServer: false,
    timeout: 120_000,
  },
});
