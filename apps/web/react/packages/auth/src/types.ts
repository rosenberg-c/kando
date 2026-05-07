export type AuthTokens = {
  accessToken: string;
  refreshToken?: string;
  accessTokenExpiresAt: string;
};

export type SignInParams = {
  email: string;
  password: string;
  keepSignedIn: boolean;
};

export type AuthTransport = {
  signIn: (email: string, password: string) => Promise<AuthTokens | null>;
  refreshTokens: () => Promise<AuthTokens | null>;
  revokeSession: () => Promise<number | null>;
  getIdentity: () => Promise<{ email: string } | null>;
};
