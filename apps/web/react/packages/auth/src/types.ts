export type AuthTokens = {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: string;
};

export type StoredSession = AuthTokens & {
  email: string;
};

export type SignInParams = {
  email: string;
  password: string;
  keepSignedIn: boolean;
};

export type AuthTransport = {
  signIn: (email: string, password: string) => Promise<AuthTokens | null>;
  refreshTokens: (refreshToken: string) => Promise<AuthTokens | null>;
  revokeSession: (refreshToken: string) => Promise<number | null>;
};

export type AuthSessionStore = {
  load: () => StoredSession | null;
  save: (session: StoredSession) => void;
  clear: () => void;
};
