import { keys, t } from "@kando/locale";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import type { AuthSessionStore, AuthTokens, AuthTransport, SignInParams } from "./types";

const SessionStatus = {
  Idle: "idle",
  Loading: "loading",
} as const;

type SessionStatus = (typeof SessionStatus)[keyof typeof SessionStatus];

type AuthContextValue = {
  isSignedIn: boolean;
  isBusy: boolean;
  signedInEmail: string;
  accessTokenExpiresAt: string;
  statusMessage: string;
  statusIsError: boolean;
  signIn: (params: SignInParams) => Promise<void>;
  signOut: () => Promise<void>;
};

type AuthProviderProps = {
  transport: AuthTransport;
  sessionStore: AuthSessionStore;
  children: ReactNode;
};

const AuthContext = createContext<AuthContextValue | null>(null);

function parseExpiry(value: string): number {
  const epoch = Date.parse(value);
  return Number.isNaN(epoch) ? 0 : epoch;
}

function needsRefresh(expiresAtIso: string): boolean {
  return parseExpiry(expiresAtIso) <= Date.now() + 30_000;
}

function toStatusMessage(error: unknown): string {
  if (error instanceof Error) {
    return t(keys.auth.signin.networkError, { reason: error.message });
  }
  return t(keys.auth.signin.unknownError);
}

export function AuthProvider({ transport, sessionStore, children }: AuthProviderProps) {
  const [signedInEmail, setSignedInEmail] = useState("");
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [refreshToken, setRefreshToken] = useState<string | null>(null);
  const [accessTokenExpiresAt, setAccessTokenExpiresAt] = useState("");
  const [status, setStatus] = useState<SessionStatus>(SessionStatus.Idle);
  const [statusMessage, setStatusMessage] = useState("");
  const [statusIsError, setStatusIsError] = useState(false);

  const isSignedIn = Boolean(accessToken);
  const isBusy = status === SessionStatus.Loading;

  useEffect(() => {
    const restore = async () => {
      const session = sessionStore.load();
      if (!session) {
        return;
      }

      if (needsRefresh(session.accessTokenExpiresAt)) {
        setStatus(SessionStatus.Loading);
        try {
          const refreshed = await transport.refreshTokens(session.refreshToken);
          if (!refreshed) {
            sessionStore.clear();
            setSignedInEmail("");
            setStatusIsError(true);
            setStatusMessage(t(keys.auth.session.expired));
            return;
          }

          const restored = {
            email: session.email,
            ...refreshed,
          };
          sessionStore.save(restored);
          setAccessToken(restored.accessToken);
          setRefreshToken(restored.refreshToken);
          setAccessTokenExpiresAt(restored.accessTokenExpiresAt);
          setSignedInEmail(restored.email);
        } catch (error) {
          setSignedInEmail("");
          setStatusIsError(true);
          setStatusMessage(t(keys.auth.session.restoreFailed, { reason: String(error) }));
        } finally {
          setStatus(SessionStatus.Idle);
        }
        return;
      }

      setAccessToken(session.accessToken);
      setRefreshToken(session.refreshToken);
      setAccessTokenExpiresAt(session.accessTokenExpiresAt);
      setSignedInEmail(session.email);
    };

    void restore();
  }, [sessionStore, transport]);

  const applySignedInState = useCallback((nextEmail: string, tokens: AuthTokens) => {
    setAccessToken(tokens.accessToken);
    setRefreshToken(tokens.refreshToken);
    setAccessTokenExpiresAt(tokens.accessTokenExpiresAt);
    setSignedInEmail(nextEmail);
  }, []);

  const signIn = useCallback(
    async ({ email, password, keepSignedIn }: SignInParams) => {
      const nextEmail = email.trim();
      if (!nextEmail || !password) {
        return;
      }

      setStatus(SessionStatus.Loading);
      setStatusMessage("");
      setStatusIsError(false);

      try {
        const tokens = await transport.signIn(nextEmail, password);
        if (!tokens) {
          setStatusIsError(true);
          setStatusMessage(t(keys.auth.signin.failed));
          return;
        }

        applySignedInState(nextEmail, tokens);
        if (keepSignedIn) {
          sessionStore.save({ email: nextEmail, ...tokens });
        } else {
          sessionStore.clear();
        }
        setStatusMessage(t(keys.auth.signin.success));
      } catch (error) {
        setStatusIsError(true);
        setStatusMessage(toStatusMessage(error));
      } finally {
        setStatus(SessionStatus.Idle);
      }
    },
    [applySignedInState, sessionStore, transport],
  );

  const signOut = useCallback(async () => {
    const currentRefreshToken = refreshToken;
    let hasError = false;
    setStatus(SessionStatus.Loading);
    setStatusMessage("");
    setStatusIsError(false);
    try {
      if (currentRefreshToken) {
        const statusCode = await transport.revokeSession(currentRefreshToken);
        if (statusCode !== null) {
          hasError = true;
          setStatusIsError(true);
          setStatusMessage(t(keys.auth.signout.failed, { statusCode: String(statusCode) }));
        }
      }
    } catch (error) {
      hasError = true;
      setStatusIsError(true);
      setStatusMessage(t(keys.auth.signout.networkError, { reason: String(error) }));
    } finally {
      sessionStore.clear();
      setAccessToken(null);
      setRefreshToken(null);
      setAccessTokenExpiresAt("");
      setSignedInEmail("");
      if (!hasError) {
        setStatusMessage(t(keys.auth.signout.success));
      }
      setStatus(SessionStatus.Idle);
    }
  }, [refreshToken, sessionStore, transport]);

  const value = useMemo<AuthContextValue>(
    () => ({
      isSignedIn,
      isBusy,
      signedInEmail,
      accessTokenExpiresAt,
      statusMessage,
      statusIsError,
      signIn,
      signOut,
    }),
    [
      accessTokenExpiresAt,
      isBusy,
      isSignedIn,
      signIn,
      signOut,
      signedInEmail,
      statusIsError,
      statusMessage,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return context;
}
