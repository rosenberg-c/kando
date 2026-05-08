export type SignInParams = {
  email: string;
  password: string;
  keepSignedIn: boolean;
};

export type AuthTransport = {
  signIn: (email: string, password: string) => Promise<boolean>;
  refreshSession: () => Promise<boolean>;
  revokeSession: () => Promise<number | null>;
  getIdentity: () => Promise<{ email: string } | null>;
};
