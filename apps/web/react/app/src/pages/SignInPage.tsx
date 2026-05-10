import { Navigate } from "react-router-dom";
import { SignInCard, type SignInParams } from "@kando/auth";
import { appRoutes } from "../routes";

type SignInPageProps = {
  hasSession: boolean;
  isBusy: boolean;
  onSignIn: (params: SignInParams) => Promise<void>;
  statusMessage: string;
  statusIsError: boolean;
};

export function SignInPage({
  hasSession,
  isBusy,
  onSignIn,
  statusMessage,
  statusIsError,
}: SignInPageProps) {
  if (hasSession) {
    return <Navigate to={appRoutes.boards} replace />;
  }

  return (
    <SignInCard
      isBusy={isBusy}
      onSubmit={onSignIn}
      statusMessage={statusMessage}
      statusIsError={statusIsError}
    />
  );
}
