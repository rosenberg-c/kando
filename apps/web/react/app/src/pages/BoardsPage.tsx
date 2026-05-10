import { Navigate } from "react-router-dom";
import type { ReactElement } from "react";
import { appRoutes } from "../routes";

type BoardsPageProps = {
  hasSession: boolean;
  card: ReactElement;
};

export function BoardsPage({ hasSession, card }: BoardsPageProps) {
  if (!hasSession) {
    return <Navigate to={appRoutes.signIn} replace />;
  }

  return card;
}
