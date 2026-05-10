import { Navigate } from "react-router-dom";
import { WorkspaceCard } from "@kando/auth";
import { appRoutes } from "../routes";

type BoardsPageProps = {
  hasSession: boolean;
  signedInEmail: string;
  isBusy: boolean;
  onSignOut: () => Promise<void>;
  statusMessage: string;
  statusIsError: boolean;
};

export function BoardsPage({
  hasSession,
  signedInEmail,
  isBusy,
  onSignOut,
  statusMessage,
  statusIsError,
}: BoardsPageProps) {
  if (!hasSession) {
    return <Navigate to={appRoutes.signIn} replace />;
  }

  return (
    <WorkspaceCard
      signedInEmail={signedInEmail}
      isBusy={isBusy}
      onSignOut={onSignOut}
      statusMessage={statusMessage}
      statusIsError={statusIsError}
    />
  );
}
