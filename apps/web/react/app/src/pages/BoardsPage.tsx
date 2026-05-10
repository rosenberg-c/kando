import { Navigate } from "react-router-dom";
import { appRoutes } from "../routes";
import type { AuthUiState } from "./authUiState";
import { WorkspaceCard } from "../workspace/components/WorkspaceCard";

type BoardsPageProps = {
  hasSession: boolean;
  signedInEmail: string;
  authUiState: AuthUiState;
  onSignOut: () => Promise<void>;
};

export function BoardsPage({
  hasSession,
  signedInEmail,
  authUiState,
  onSignOut,
}: BoardsPageProps) {
  if (!hasSession) {
    return <Navigate to={appRoutes.signIn} replace />;
  }

  return (
    <WorkspaceCard
      signedInEmail={signedInEmail}
      isBusy={authUiState.isBusy}
      onSignOut={onSignOut}
      statusMessage={authUiState.statusMessage}
      statusIsError={authUiState.statusIsError}
    />
  );
}
