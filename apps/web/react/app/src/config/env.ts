export function apiBaseUrl(): string {
  if (import.meta.env.VITE_KANDO_USE_TEST_API_BASE_URL === "1") {
    return import.meta.env.VITE_KANDO_API_BASE_URL_TEST ?? "http://127.0.0.1:8080";
  }

  const explicitBaseURL = import.meta.env.VITE_KANDO_API_BASE_URL?.trim();
  if (explicitBaseURL) {
    return explicitBaseURL;
  }

  if (import.meta.env.DEV) {
    return "/api";
  }

  return "http://localhost:8080";
}
