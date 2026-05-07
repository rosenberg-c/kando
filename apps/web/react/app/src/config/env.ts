export function apiBaseUrl(): string {
  if (import.meta.env.DEV) {
    return "/api";
  }

  return import.meta.env.VITE_KANDO_API_BASE_URL ?? "http://localhost:8080";
}
