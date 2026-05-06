export function apiBaseUrl(): string {
  return import.meta.env.VITE_KANDO_API_BASE_URL ?? "http://localhost:8080";
}
