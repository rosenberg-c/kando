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
import type { AuthTransport, SignInParams } from "../types/auth";

const SessionStatus = {
  Idle: "idle",
  Loading: "loading",
} as const;

type SessionStatus = (typeof SessionStatus)[keyof typeof SessionStatus];

type AuthContextValue = {
  hasSession: boolean;
  isBusy: boolean;
  signedInEmail: string;
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
  const [hasSession, setHasSession] = useState(false);
  const [signedInEmail, setSignedInEmail] = useState("");
  const [status, setStatus] = useState<SessionStatus>(SessionStatus.Idle);
  const [statusMessage, setStatusMessage] = useState("");
  const [statusIsError, setStatusIsError] = useState(false);

  const isBusy = status === SessionStatus.Loading;

  const applySignedInState = useCallback((nextEmail: string) => {
    setHasSession(true);
    setSignedInEmail(nextEmail);
  }, []);

  useEffect(() => {
    const restore = async () => {
      setStatus(SessionStatus.Loading);
      try {
        const restored = await transport.refreshSession();
        if (!restored) {
          setHasSession(false);
          return;
        }

        const identity = await transport.getIdentity();
        applySignedInState(identity?.email ?? "");
      } catch (error) {
        setHasSession(false);
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
        const signedIn = await transport.signIn(nextEmail, password);
        if (!signedIn) {
          setStatusIsError(true);
          setStatusMessage(t(keys.auth.signin.failed));
          return;
        }

        applySignedInState(nextEmail);
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
      setHasSession(false);
      setSignedInEmail("");
      if (!hasError) {
        setStatusMessage(t(keys.auth.signout.success));
      }
      setStatus(SessionStatus.Idle);
    }
  }, [transport]);

  const value = useMemo<AuthContextValue>(
    () => ({
      hasSession,
      isBusy,
      signedInEmail,
      statusMessage,
      statusIsError,
      signIn,
      signOut,
    }),
    [
      isBusy,
      hasSession,
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
