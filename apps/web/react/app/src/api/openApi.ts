import { OpenAPI } from "../generated/api";
import { apiBaseUrl } from "../config/env";

export function configureOpenApiClient(): void {
  OpenAPI.BASE = apiBaseUrl();
  OpenAPI.WITH_CREDENTIALS = true;
  OpenAPI.CREDENTIALS = "include";
}
