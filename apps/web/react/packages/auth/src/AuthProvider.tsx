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
import type { AuthTokens, AuthTransport, SignInParams } from "./types";

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
  children: ReactNode;
};

const AuthContext = createContext<AuthContextValue | null>(null);

function toStatusMessage(error: unknown): string {
  if (error instanceof Error) {
    return t(keys.auth.signin.networkError, { reason: error.message });
  }
  return t(keys.auth.signin.unknownError);
}

export function AuthProvider({ transport, children }: AuthProviderProps) {
  const [signedInEmail, setSignedInEmail] = useState("");
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [accessTokenExpiresAt, setAccessTokenExpiresAt] = useState("");
  const [status, setStatus] = useState<SessionStatus>(SessionStatus.Idle);
  const [statusMessage, setStatusMessage] = useState("");
  const [statusIsError, setStatusIsError] = useState(false);

  const isSignedIn = Boolean(accessToken);
  const isBusy = status === SessionStatus.Loading;

  const applySignedInState = useCallback((nextEmail: string, tokens: AuthTokens) => {
    setAccessToken(tokens.accessToken);
    setAccessTokenExpiresAt(tokens.accessTokenExpiresAt);
    setSignedInEmail(nextEmail);
  }, []);

  useEffect(() => {
    const restore = async () => {
      setStatus(SessionStatus.Loading);
      try {
        const refreshed = await transport.refreshTokens();
        if (!refreshed) {
          return;
        }

        const identity = await transport.getIdentity();
        applySignedInState(identity?.email ?? "", refreshed);
      } catch (error) {
        setSignedInEmail("");
        setStatusIsError(true);
        setStatusMessage(t(keys.auth.session.restoreFailed, { reason: String(error) }));
      } finally {
        setStatus(SessionStatus.Idle);
      }
    };

    void restore();
  }, [applySignedInState, transport]);

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
        void keepSignedIn;
        setStatusMessage(t(keys.auth.signin.success));
      } catch (error) {
        setStatusIsError(true);
        setStatusMessage(toStatusMessage(error));
      } finally {
        setStatus(SessionStatus.Idle);
      }
    },
    [applySignedInState, transport],
  );

  const signOut = useCallback(async () => {
    let hasError = false;
    setStatus(SessionStatus.Loading);
    setStatusMessage("");
    setStatusIsError(false);
    try {
      const statusCode = await transport.revokeSession();
      if (statusCode !== null) {
        hasError = true;
        setStatusIsError(true);
        setStatusMessage(t(keys.auth.signout.failed, { statusCode: String(statusCode) }));
      }
    } catch (error) {
      hasError = true;
      setStatusIsError(true);
      setStatusMessage(t(keys.auth.signout.networkError, { reason: String(error) }));
    } finally {
      setAccessToken(null);
      setAccessTokenExpiresAt("");
      setSignedInEmail("");
      if (!hasError) {
        setStatusMessage(t(keys.auth.signout.success));
      }
      setStatus(SessionStatus.Idle);
    }
  }, [transport]);

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
