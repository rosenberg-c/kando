import { type AuthTransport } from "@kando/auth";
import { AuthService, ApiError, OpenAPI, type AuthTokens } from "../generated/api";
import { apiBaseUrl } from "../config/env";

function configureBaseURL(): void {
  OpenAPI.BASE = apiBaseUrl();
}

function isAuthTokens(value: unknown): value is AuthTokens {
  if (!value || typeof value !== "object") {
    return false;
  }
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.accessToken === "string" &&
    typeof candidate.refreshToken === "string" &&
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

  async refreshTokens(refreshToken: string) {
    configureBaseURL();
    try {
      const response = await AuthService.refreshAuth({
        requestBody: {
          refreshToken,
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

  async revokeSession(refreshToken: string) {
    configureBaseURL();
    try {
      await AuthService.logout({
        requestBody: {
          refreshToken,
        },
      });
      return null;
    } catch (error) {
      if (error instanceof ApiError) {
        return error.status;
      }
      throw error;
    }
  },
};
