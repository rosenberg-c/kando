import "./App.css";
import { useAuth } from "@kando/auth";
import { Spinner } from "@kando/components";
import { keys, t } from "@kando/locale";
import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import { AppHeader } from "./layout/AppHeader";
import { BoardsPage } from "./pages/boards/BoardsPage";
import type { AuthUiState } from "./pages/authUiState";
import { SignInPage } from "./pages/sign-in/SignInPage";
import { appRoutes } from "./routes";

export default function App() {
  const location = useLocation();
  const {
    hasInitialized,
    hasSession,
    isBusy,
    signedInEmail,
    statusMessage,
    statusIsError,
    signIn,
    signOut,
  } = useAuth();

  const authUiState: AuthUiState = {
    isBusy,
    statusMessage,
    statusIsError,
  };

  const shellClassName = location.pathname.startsWith(appRoutes.boards)
    ? "app-shell app-shellBoards"
    : "app-shell";

  if (!hasInitialized) {
    return (
      <div className="app-root" data-testid="web.app">
        <main className="app-shell" data-testid="app.session.loading">
          <Spinner label={t(keys.app.loading)} data-testid="app.session.spinner" />
        </main>
      </div>
    );
  }

  return (
    <div className="app-root" data-testid="web.app">
      <AppHeader
        hasSession={hasSession}
        signedInEmail={signedInEmail}
        isBusy={isBusy}
        onSignOut={signOut}
      />
      <main className={shellClassName}>
        <Routes>
          <Route
            path={appRoutes.signIn}
            element={
              <SignInPage
                hasSession={hasSession}
                authUiState={authUiState}
                onSignIn={signIn}
              />
            }
          />
          <Route
            path={appRoutes.boards}
            element={
              <BoardsPage
                hasSession={hasSession}
                authUiState={authUiState}
              />
            }
          />
          <Route
            path="*"
            element={<Navigate to={hasSession ? appRoutes.boards : appRoutes.signIn} replace />}
          />
        </Routes>
      </main>
    </div>
  );
}
