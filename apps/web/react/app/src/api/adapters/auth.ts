import { type AuthTransport } from "@kando/auth";
import { AuthService, PublicService } from "../../generated/api";
import { ensureApiClientConfigured } from "../client";
import { mapApiError } from "../handleApiError";

export const authTransport: AuthTransport = {
  async signIn(email: string, password: string) {
    ensureApiClientConfigured();
    try {
      await AuthService.login({
        requestBody: {
          email,
          password,
        },
      });
      return true;
    } catch (error) {
      return mapApiError(error, () => false);
    }
  },

  async refreshSession() {
    ensureApiClientConfigured();
    try {
      await AuthService.refreshAuth({});
      return true;
    } catch (error) {
      return mapApiError(error, () => false);
    }
  },

  async revokeSession() {
    ensureApiClientConfigured();
    try {
      await AuthService.logout({});
      return null;
    } catch (error) {
      return mapApiError(error, (apiError) => apiError.status);
    }
  },

  async getIdentity() {
    ensureApiClientConfigured();
    try {
      const response = await PublicService.getMe({});
      if (!response || typeof response !== "object") {
        return null;
      }
      const candidate = response as Record<string, unknown>;
      return typeof candidate.email === "string" ? { email: candidate.email } : null;
    } catch (error) {
      return mapApiError(error, () => null);
    }
  },
};
