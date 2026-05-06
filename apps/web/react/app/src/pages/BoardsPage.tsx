import { Navigate } from "react-router-dom";
import type { ReactElement } from "react";

type BoardsPageProps = {
  isSignedIn: boolean;
  card: ReactElement;
};

export function BoardsPage({ isSignedIn, card }: BoardsPageProps) {
  if (!isSignedIn) {
    return <Navigate to="/signin" replace />;
  }

  return card;
}
