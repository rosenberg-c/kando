import { configureOpenApiClient } from "./openApi";

export function ensureApiClientConfigured(): void {
  configureOpenApiClient();
}
