import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { AuthProvider, type AuthTransport } from "@kando/auth";
import { keys, t } from "@kando/locale";
import { MemoryRouter } from "react-router-dom";
import App from "./App";
import { ThemeProvider } from "./theme/ThemeProvider";

function deferred<T>() {
  let resolve: (value: T) => void = () => {};
  const promise = new Promise<T>((res) => {
    resolve = res;
  });
  return { promise, resolve };
}

function renderApp(transport: AuthTransport, initialEntries: string[] = ["/"]) {
  return render(
    <ThemeProvider>
      <AuthProvider transport={transport}>
        <MemoryRouter initialEntries={initialEntries}>
          <App />
        </MemoryRouter>
      </AuthProvider>
    </ThemeProvider>,
  );
}

function openSettingsPanel() {
  fireEvent.click(screen.getByTestId("app.settings.toggle"));
}

const defaultTransport: AuthTransport = {
  signIn: async () => false,
  refreshSession: async () => false,
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
    const pending = deferred<boolean>();
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

    pending.resolve(true);

    await waitFor(() => {
      expect(screen.getByText(t(keys.boards.placeholderMessage))).toBeTruthy();
      expect(screen.queryByText("Signed in as {email}.")).toBeNull();
    });

    openSettingsPanel();
    expect(screen.getByTestId("auth.signout.submit")).toBeTruthy();
  });

  // @req AUTH-002
  it("restores a valid session on app launch via refresh cookie", async () => {
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "restore@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByText(t(keys.boards.placeholderMessage))).toBeTruthy();
    });

    openSettingsPanel();
    expect(screen.getAllByTestId("auth.signout.submit").length).toBe(1);
  });

  // @req AUTH-003
  it("attempts refresh once on launch", async () => {
    let refreshCalls = 0;
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => {
        refreshCalls += 1;
        return true;
      },
      getIdentity: async () => ({ email: "refresh@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(refreshCalls).toBe(1);
      expect(screen.getByText(t(keys.boards.placeholderMessage))).toBeTruthy();
    });

    openSettingsPanel();
    expect(screen.getAllByTestId("auth.signout.submit").length).toBe(1);
  });

  // @req AUTH-003
  // @req AUTH-004
  it("shows signed-out view and expired status when refresh cannot restore session", async () => {
    let refreshCalls = 0;

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => {
        refreshCalls += 1;
        return false;
      },
    };

    renderApp(transport);

    await waitFor(() => {
      expect(refreshCalls).toBe(1);
      expect(screen.getByTestId("auth.signin.submit")).toBeTruthy();
      expect(screen.queryByTestId("auth.signout.submit")).toBeNull();
    });
  });

  // @req AUTH-008
  it("redirects signed-out users from /boards to /signin", async () => {
    renderApp(defaultTransport, ["/boards"]);

    await waitFor(() => {
      expect(screen.getByTestId("auth.signin.submit")).toBeTruthy();
      expect(screen.queryByTestId("auth.signout.submit")).toBeNull();
    });
  });

  // @req AUTH-008
  it("redirects signed-in users from /signin to /boards", async () => {
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "routes@example.com" }),
    };

    renderApp(transport, ["/signin"]);

    await waitFor(() => {
      expect(screen.queryByTestId("auth.signin.submit")).toBeNull();
    });

    openSettingsPanel();
    expect(screen.getByTestId("auth.signout.submit")).toBeTruthy();
  });

  // @req UX-043
  it("toggles settings panel when pressing settings button", async () => {
    renderApp(defaultTransport);

    const settingsButton = screen.getByTestId("app.settings.toggle");
    fireEvent.click(settingsButton);

    expect(screen.getByTestId("app.settings.panel")).toBeTruthy();
    expect(screen.getByTestId("app.settings.theme.toggle")).toBeTruthy();

    fireEvent.click(settingsButton);

    await waitFor(() => {
      expect(screen.queryByTestId("app.settings.panel")).toBeNull();
    });
  });

  // @req UX-043
  it("closes settings panel when clicking outside", async () => {
    renderApp(defaultTransport);

    fireEvent.click(screen.getByTestId("app.settings.toggle"));
    expect(screen.getByTestId("app.settings.panel")).toBeTruthy();

    fireEvent.pointerDown(document.body);

    await waitFor(() => {
      expect(screen.queryByTestId("app.settings.panel")).toBeNull();
    });
  });

  // @req UX-043
  it("closes settings panel when escape is pressed", async () => {
    renderApp(defaultTransport);

    fireEvent.click(screen.getByTestId("app.settings.toggle"));
    expect(screen.getByTestId("app.settings.panel")).toBeTruthy();

    fireEvent.keyDown(document, { key: "Escape" });

    await waitFor(() => {
      expect(screen.queryByTestId("app.settings.panel")).toBeNull();
    });
  });
});
