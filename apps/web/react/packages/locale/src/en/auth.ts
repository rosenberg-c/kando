export const authEn = {
  auth: {
    signin: {
      title: "Sign in",
      subtitle: "Use your account credentials to continue.",
      submit: "Sign in",
      submitting: "Signing in...",
      success: "Signed in successfully.",
      failed: "Sign in failed. Check your credentials and try again.",
      networkError: "Network error while signing in: {{reason}}",
      unknownError: "Unexpected error while signing in.",
    },
    signout: {
      submit: "Sign out",
      success: "Signed out.",
      failed: "Sign out failed (status {{statusCode}}).",
      networkError: "Network error while signing out: {{reason}}",
    },
    session: {
      expired: "Session expired. Please sign in again.",
      restoreFailed: "Could not restore session: {{reason}}",
    },
    email: {
      label: "Email",
      placeholder: "you@example.com",
    },
    password: {
      label: "Password",
      placeholder: "Enter your password",
    },
  },
} as const;
