import "./App.css";
import { SignInCard, useAuth, WorkspaceCard } from "@kando/auth";

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
      {!isSignedIn ? (
        <SignInCard
          isBusy={isBusy}
          onSubmit={signIn}
          statusMessage={statusMessage}
          statusIsError={statusIsError}
        />
      ) : (
        <WorkspaceCard
          signedInEmail={signedInEmail}
          isBusy={isBusy}
          onSignOut={signOut}
          statusMessage={statusMessage}
          statusIsError={statusIsError}
        />
      )}
    </main>
  );
}
