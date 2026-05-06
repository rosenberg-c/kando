import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { AuthProvider, type AuthSessionStore, type AuthTransport } from "@kando/auth";
import App from "./App";

function inFutureIso(minutes: number): string {
  return new Date(Date.now() + minutes * 60_000).toISOString();
}

function inPastIso(minutes: number): string {
  return new Date(Date.now() - minutes * 60_000).toISOString();
}

function deferred<T>() {
  let resolve: (value: T) => void = () => {};
  const promise = new Promise<T>((res) => {
    resolve = res;
  });
  return { promise, resolve };
}

function renderApp(transport: AuthTransport, sessionStore: AuthSessionStore) {
  return render(
    <AuthProvider transport={transport} sessionStore={sessionStore}>
      <App />
    </AuthProvider>,
  );
}

const defaultTransport: AuthTransport = {
  signIn: async () => null,
  refreshTokens: async () => null,
  revokeSession: async () => null,
};

const sessionStore: AuthSessionStore = {
  load: () => null,
  save: () => {},
  clear: () => {},
};

describe("App", () => {
  afterEach(() => {
    cleanup();
  });

  // @req AUTH-004
  it("renders sign in view by default", () => {
    renderApp(defaultTransport, sessionStore);

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

    renderApp(transport, sessionStore);

    fireEvent.change(screen.getByTestId("auth.email"), { target: { value: "person@example.com" } });
    fireEvent.change(screen.getByTestId("auth.password"), { target: { value: "secret" } });
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
    });
  });

  // @req AUTH-002
  it("restores a valid stored session on app launch", async () => {
    const store: AuthSessionStore = {
      load: () => ({
        email: "restore@example.com",
        accessToken: "access-token",
        refreshToken: "refresh-token",
        accessTokenExpiresAt: inFutureIso(10),
      }),
      save: () => {},
      clear: () => {},
    };

    renderApp(defaultTransport, store);

    await waitFor(() => {
      expect(screen.getAllByTestId("auth.signout.submit").length).toBe(1);
    });
  });

  // @req AUTH-003
  it("refreshes expired stored session tokens on launch", async () => {
    let refreshCalls = 0;
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshTokens: async () => {
        refreshCalls += 1;
        return {
          accessToken: "new-access-token",
          refreshToken: "new-refresh-token",
          accessTokenExpiresAt: inFutureIso(15),
        };
      },
    };

    const store: AuthSessionStore = {
      load: () => ({
        email: "refresh@example.com",
        accessToken: "old-access-token",
        refreshToken: "old-refresh-token",
        accessTokenExpiresAt: inPastIso(10),
      }),
      save: () => {},
      clear: () => {},
    };

    renderApp(transport, store);

    await waitFor(() => {
      expect(refreshCalls).toBe(1);
      expect(screen.getAllByTestId("auth.signout.submit").length).toBe(1);
    });
  });

  // @req AUTH-003
  // @req AUTH-004
  it("shows signed-out view and expired status when refresh cannot restore session", async () => {
    let refreshCalls = 0;
    const clearCalls: Array<"clear"> = [];

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshTokens: async () => {
        refreshCalls += 1;
        return null;
      },
    };

    const store: AuthSessionStore = {
      load: () => ({
        email: "stale@example.com",
        accessToken: "old-access-token",
        refreshToken: "old-refresh-token",
        accessTokenExpiresAt: inPastIso(10),
      }),
      save: () => {},
      clear: () => {
        clearCalls.push("clear");
      },
    };

    renderApp(transport, store);

    await waitFor(() => {
      expect(refreshCalls).toBe(1);
      expect(clearCalls.length).toBe(1);
      expect(screen.getByTestId("auth.signin.submit")).toBeTruthy();
      expect(screen.getByText("Session expired. Please sign in again.")).toBeTruthy();
      expect(screen.queryByTestId("auth.signout.submit")).toBeNull();
    });
  });
});
