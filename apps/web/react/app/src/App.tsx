import "./App.css";
import { SignInCard, useAuth, WorkspaceCard } from "@kando/auth";
import { Navigate, Route, Routes } from "react-router-dom";
import { BoardsPage } from "./pages/BoardsPage";
import { SignInPage } from "./pages/SignInPage";

export default function App() {
  const {
    isSignedIn,
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
          path="/signin"
          element={
            <SignInPage
              isSignedIn={isSignedIn}
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
          path="/boards"
          element={
            <BoardsPage
              isSignedIn={isSignedIn}
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
        <Route path="*" element={<Navigate to={isSignedIn ? "/boards" : "/signin"} replace />} />
      </Routes>
    </main>
  );
}
