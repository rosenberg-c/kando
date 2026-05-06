import { Navigate } from "react-router-dom";
import type { ReactElement } from "react";

type SignInPageProps = {
  isSignedIn: boolean;
  card: ReactElement;
};

export function SignInPage({ isSignedIn, card }: SignInPageProps) {
  if (isSignedIn) {
    return <Navigate to="/boards" replace />;
  }

  return card;
}
