import { type AuthTransport } from "@kando/auth";
import { AuthService, ApiError, OpenAPI, PublicService, type AuthTokens } from "../generated/api";
import { apiBaseUrl } from "../config/env";

function configureBaseURL(): void {
  OpenAPI.BASE = apiBaseUrl();
  OpenAPI.WITH_CREDENTIALS = true;
  OpenAPI.CREDENTIALS = "include";
}

function isAuthTokens(value: unknown): value is AuthTokens {
  if (!value || typeof value !== "object") {
    return false;
  }
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.accessToken === "string" &&
    typeof candidate.accessTokenExpiresAt === "string"
  );
}

export const authTransport: AuthTransport = {
  async signIn(email: string, password: string) {
    configureBaseURL();
    try {
      const response = await AuthService.login({
        requestBody: {
          email,
          password,
        },
      });
      return isAuthTokens(response) ? response : null;
    } catch (error) {
      if (error instanceof ApiError) {
        return null;
      }
      throw error;
    }
  },

  async refreshTokens() {
    configureBaseURL();
    try {
      const response = await AuthService.refreshAuth({
      });
      return isAuthTokens(response) ? response : null;
    } catch (error) {
      if (error instanceof ApiError) {
        return null;
      }
      throw error;
    }
  },

  async revokeSession() {
    configureBaseURL();
    try {
      await AuthService.logout({
      });
      return null;
    } catch (error) {
      if (error instanceof ApiError) {
        return error.status;
      }
      throw error;
    }
  },

  async getIdentity() {
    configureBaseURL();
    try {
      const response = await PublicService.getMe({});
      if (!response || typeof response !== "object") {
        return null;
      }
      const candidate = response as Record<string, unknown>;
      return typeof candidate.email === "string" ? { email: candidate.email } : null;
    } catch (error) {
      if (error instanceof ApiError) {
        return null;
      }
      throw error;
    }
  },
};
