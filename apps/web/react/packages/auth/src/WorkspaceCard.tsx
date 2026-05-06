import { Button, Card, Text } from "@kando/components";
import { keys, t } from "@kando/locale";
import styles from "./WorkspaceCard.module.css";

type WorkspaceCardProps = {
  signedInEmail: string;
  accessTokenExpiresAt: string;
  isBusy: boolean;
  onSignOut: () => Promise<void>;
  statusMessage: string;
  statusIsError: boolean;
};

export function WorkspaceCard({
  signedInEmail,
  accessTokenExpiresAt,
  isBusy,
  onSignOut,
  statusMessage,
  statusIsError,
}: WorkspaceCardProps) {
  return (
    <Card>
      <h1 className={styles.title}>{t(keys.workspace.title)}</h1>
      <Text variant="muted">{t(keys.workspace.subtitle, { email: signedInEmail })}</Text>
      <Text className={styles.tokenMeta}>{t(keys.workspace.tokenExpiry, { at: accessTokenExpiresAt })}</Text>
      <div className={styles.actions}>
        <Button
          variant="danger"
          type="button"
          onClick={() => void onSignOut()}
          disabled={isBusy}
          data-testid="auth.signout.submit"
        >
          {t(keys.auth.signout.submit)}
        </Button>
      </div>
      {statusMessage && (
        <Text
          className={
            statusIsError
              ? `${styles.status} ${styles.statusError}`
              : `${styles.status} ${styles.statusOk}`
          }
        >
          {statusMessage}
        </Text>
      )}
    </Card>
  );
}
