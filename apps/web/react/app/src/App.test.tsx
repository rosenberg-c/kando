import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { AuthProvider, type AuthTransport } from "@kando/auth";
import { keys, t } from "@kando/locale";
import App from "./App";

function inFutureIso(minutes: number): string {
  return new Date(Date.now() + minutes * 60_000).toISOString();
}

function deferred<T>() {
  let resolve: (value: T) => void = () => {};
  const promise = new Promise<T>((res) => {
    resolve = res;
  });
  return { promise, resolve };
}

function renderApp(transport: AuthTransport) {
  return render(
    <AuthProvider transport={transport}>
      <App />
    </AuthProvider>,
  );
}

const defaultTransport: AuthTransport = {
  signIn: async () => null,
  refreshTokens: async () => null,
  revokeSession: async () => null,
  getIdentity: async () => null,
};

describe("App", () => {
  afterEach(() => {
    cleanup();
  });

  // @req AUTH-004
  it("renders sign in view by default", () => {
    renderApp(defaultTransport);

    expect(screen.getByTestId("web.app")).toBeTruthy();
    expect(screen.getByTestId("auth.email")).toBeTruthy();
    expect(screen.getByTestId("auth.password")).toBeTruthy();
    expect(screen.getByTestId("auth.signin.submit")).toBeTruthy();
  });

  // @req AUTH-001
  it("signs in with email/password and disables submit while request is in flight", async () => {
    const pending = deferred<{
      accessToken: string;
      refreshToken: string;
      accessTokenExpiresAt: string;
    } | null>();
    let signInCalls = 0;

    const transport: AuthTransport = {
      ...defaultTransport,
      signIn: async () => {
        signInCalls += 1;
        return pending.promise;
      },
    };

    renderApp(transport);

    fireEvent.change(screen.getByTestId("auth.email"), { target: { value: "person@example.com" } });
    fireEvent.change(screen.getByTestId("auth.password"), { target: { value: "secret" } });

    await waitFor(() => {
      expect(screen.getByTestId("auth.signin.submit").hasAttribute("disabled")).toBe(false);
    });

    fireEvent.click(screen.getByTestId("auth.signin.submit"));

    expect(signInCalls).toBe(1);
    expect(screen.getByTestId("auth.signin.submit").hasAttribute("disabled")).toBe(true);

    pending.resolve({
      accessToken: "access-token",
      refreshToken: "refresh-token",
      accessTokenExpiresAt: inFutureIso(10),
    });

    await waitFor(() => {
      expect(screen.getByTestId("auth.signout.submit")).toBeTruthy();
      expect(screen.getByText(t(keys.workspace.subtitle, { email: "person@example.com" }))).toBeTruthy();
      expect(
        screen.getByText((content) => content.startsWith(t(keys.workspace.tokenExpiry, { at: "" }))),
      ).toBeTruthy();
      expect(screen.queryByText("Signed in as {email}.")).toBeNull();
      expect(screen.queryByText("Access token expires at: {at}")).toBeNull();
    });
  });

  // @req AUTH-002
  it("restores a valid session on app launch via refresh cookie", async () => {
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshTokens: async () => ({
        accessToken: "access-token",
        accessTokenExpiresAt: inFutureIso(10),
      }),
      getIdentity: async () => ({ email: "restore@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getAllByTestId("auth.signout.submit").length).toBe(1);
    });
  });

  // @req AUTH-003
  it("attempts refresh once on launch", async () => {
    let refreshCalls = 0;
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshTokens: async () => {
        refreshCalls += 1;
        return {
          accessToken: "new-access-token",
          accessTokenExpiresAt: inFutureIso(15),
        };
      },
      getIdentity: async () => ({ email: "refresh@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(refreshCalls).toBe(1);
      expect(screen.getAllByTestId("auth.signout.submit").length).toBe(1);
    });
  });

  // @req AUTH-003
  // @req AUTH-004
  it("shows signed-out view and expired status when refresh cannot restore session", async () => {
    let refreshCalls = 0;

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshTokens: async () => {
        refreshCalls += 1;
        return null;
      },
    };

    renderApp(transport);

    await waitFor(() => {
      expect(refreshCalls).toBe(1);
      expect(screen.getByTestId("auth.signin.submit")).toBeTruthy();
      expect(screen.queryByTestId("auth.signout.submit")).toBeNull();
    });
  });
});
