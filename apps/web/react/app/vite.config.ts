/// <reference types="vitest/config" />
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv } from "vite";

const certFile = path.resolve(__dirname, ".cert/localhost.pem");
const keyFile = path.resolve(__dirname, ".cert/localhost-key.pem");

if (!existsSync(certFile) || !existsSync(keyFile)) {
  throw new Error(
    "Missing HTTPS dev certs. Run `make web-cert` (or `make web-dev`) to generate .cert/localhost.pem and .cert/localhost-key.pem.",
  );
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const apiTarget = env.VITE_KANDO_API_BASE_URL || "https://localhost:8080";

  return {
    plugins: [react()],
    server: {
      host: "0.0.0.0",
      port: 5173,
      strictPort: true,
      https: {
        cert: readFileSync(certFile),
        key: readFileSync(keyFile),
      },
      proxy: {
        "/api": {
          target: apiTarget,
          changeOrigin: true,
          secure: false,
          rewrite: (incomingPath) => incomingPath.replace(/^\/api/, ""),
        },
      },
    },
    test: {
      environment: "jsdom",
    },
  };
});
