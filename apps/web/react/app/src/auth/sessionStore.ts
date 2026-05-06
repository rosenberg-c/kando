import type { AuthSessionStore, StoredSession } from "@kando/auth";

const SESSION_KEY = "kando.web.auth.session";

function loadStoredSession(): StoredSession | null {
  const raw = localStorage.getItem(SESSION_KEY);
  if (!raw) {
    return null;
  }

  try {
    const parsed = JSON.parse(raw) as StoredSession;
    if (
      typeof parsed.email !== "string" ||
      typeof parsed.accessToken !== "string" ||
      typeof parsed.refreshToken !== "string" ||
      typeof parsed.accessTokenExpiresAt !== "string"
    ) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

function saveStoredSession(session: StoredSession): void {
  localStorage.setItem(SESSION_KEY, JSON.stringify(session));
}

function clearStoredSession(): void {
  localStorage.removeItem(SESSION_KEY);
}

export const authSessionStore: AuthSessionStore = {
  load: loadStoredSession,
  save: saveStoredSession,
  clear: clearStoredSession,
};
