import "./App.css";
import { useAuth } from "@kando/auth";
import { Navigate, Route, Routes } from "react-router-dom";
import { BoardsPage } from "./pages/BoardsPage";
import { SignInPage } from "./pages/SignInPage";
import type { AuthUiState } from "./pages/authUiState";
import { appRoutes } from "./routes";

export default function App() {
  const {
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

  return (
    <main className="app-shell" data-testid="web.app">
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
              signedInEmail={signedInEmail}
              authUiState={authUiState}
              onSignOut={signOut}
            />
          }
        />
        <Route
          path="*"
          element={<Navigate to={hasSession ? appRoutes.boards : appRoutes.signIn} replace />}
        />
      </Routes>
    </main>
  );
}
