import { type AuthTransport } from "@kando/auth";
import { AuthService, ApiError, PublicService } from "../generated/api";
import { configureOpenApiClient } from "../api/openApi";

function configureBaseURL(): void {
  configureOpenApiClient();
}

export const authTransport: AuthTransport = {
  async signIn(email: string, password: string) {
    configureBaseURL();
    try {
      await AuthService.login({
        requestBody: {
          email,
          password,
        },
      });
      return true;
    } catch (error) {
      if (error instanceof ApiError) {
        return false;
      }
      throw error;
    }
  },

  async refreshSession() {
    configureBaseURL();
    try {
      await AuthService.refreshAuth({
      });
      return true;
    } catch (error) {
      if (error instanceof ApiError) {
        return false;
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
