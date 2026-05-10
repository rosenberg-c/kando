import { Navigate } from "react-router-dom";
import type { ReactElement } from "react";
import { appRoutes } from "../routes";

type SignInPageProps = {
  hasSession: boolean;
  card: ReactElement;
};

export function SignInPage({ hasSession, card }: SignInPageProps) {
  if (hasSession) {
    return <Navigate to={appRoutes.boards} replace />;
  }

  return card;
}
