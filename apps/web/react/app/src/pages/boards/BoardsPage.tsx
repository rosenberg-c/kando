import { Navigate } from "react-router-dom";
import { Text } from "@kando/components";
import { keys, t } from "@kando/locale";
import { appRoutes } from "../../routes";
import type { AuthUiState } from "../authUiState";
import styles from "./BoardsPage.module.css";

type BoardsPageProps = {
  hasSession: boolean;
  signedInEmail: string | null;
  authUiState: AuthUiState;
};

export function BoardsPage({ hasSession, authUiState }: BoardsPageProps) {
  if (!hasSession) {
    return <Navigate to={appRoutes.signIn} replace />;
  }

  return (
    <section className={styles.board}>
      <h1 className={styles.title}>{t(keys.boards.title)}</h1>
      <Text className={styles.hint} variant="muted">
        {t(keys.boards.placeholderTitle)}
      </Text>
      <Text>{t(keys.boards.placeholderMessage)}</Text>
      {authUiState.statusMessage ? (
        <Text
          className={
            authUiState.statusIsError
              ? `${styles.status} ${styles.statusError}`
              : `${styles.status} ${styles.statusOk}`
          }
        >
          {authUiState.statusMessage}
        </Text>
      ) : null}
    </section>
  );
}
