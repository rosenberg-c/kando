export function apiBaseUrl(): string {
  if (import.meta.env.VITE_KANDO_USE_TEST_API_BASE_URL === "1") {
    return import.meta.env.VITE_KANDO_API_BASE_URL_TEST ?? "http://127.0.0.1:8080";
  }

  if (import.meta.env.DEV) {
    return "/api";
  }

  return import.meta.env.VITE_KANDO_API_BASE_URL ?? "http://localhost:8080";
}
