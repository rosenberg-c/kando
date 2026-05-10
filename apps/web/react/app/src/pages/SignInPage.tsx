import { Navigate } from "react-router-dom";
import { SignInCard, type SignInParams } from "@kando/auth";
import { appRoutes } from "../routes";
import type { AuthUiState } from "./authUiState";

type SignInPageProps = {
  hasSession: boolean;
  authUiState: AuthUiState;
  onSignIn: (params: SignInParams) => Promise<void>;
};

export function SignInPage({
  hasSession,
  authUiState,
  onSignIn,
}: SignInPageProps) {
  if (hasSession) {
    return <Navigate to={appRoutes.boards} replace />;
  }

  return (
    <SignInCard
      isBusy={authUiState.isBusy}
      onSubmit={onSignIn}
      statusMessage={authUiState.statusMessage}
      statusIsError={authUiState.statusIsError}
    />
  );
}
