import "./App.css";
import { SignInCard, useAuth, WorkspaceCard } from "@kando/auth";
import { Navigate, Route, Routes } from "react-router-dom";
import { BoardsPage } from "./pages/BoardsPage";
import { SignInPage } from "./pages/SignInPage";
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

  return (
    <main className="app-shell" data-testid="web.app">
      <Routes>
        <Route
          path={appRoutes.signIn}
          element={
              <SignInPage
                hasSession={hasSession}
                card={
                <SignInCard
                  isBusy={isBusy}
                  onSubmit={signIn}
                  statusMessage={statusMessage}
                  statusIsError={statusIsError}
                />
              }
            />
          }
        />
        <Route
          path={appRoutes.boards}
          element={
              <BoardsPage
                hasSession={hasSession}
                card={
                <WorkspaceCard
                  signedInEmail={signedInEmail}
                  isBusy={isBusy}
                  onSignOut={signOut}
                  statusMessage={statusMessage}
                  statusIsError={statusIsError}
                />
              }
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
