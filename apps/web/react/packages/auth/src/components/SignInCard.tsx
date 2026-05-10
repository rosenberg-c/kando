import { useMemo, useState } from "react";
import { Button, Card, Text } from "@kando/components";
import { keys, t } from "@kando/locale";
import type { SignInParams } from "../types/auth";
import styles from "./SignInCard.module.css";

type SignInCardProps = {
  isBusy: boolean;
  onSubmit: (input: SignInParams) => Promise<void>;
  statusMessage: string;
  statusIsError: boolean;
};

export function SignInCard({
  isBusy,
  onSubmit,
  statusMessage,
  statusIsError,
}: SignInCardProps) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const canSubmit = useMemo(() => {
    return email.trim().length > 0 && password.length > 0 && !isBusy;
  }, [email, password, isBusy]);

  return (
    <Card aria-busy={isBusy}>
      <h1 className={styles.title}>{t(keys.auth.signin.title)}</h1>
      <Text variant="muted">{t(keys.auth.signin.subtitle)}</Text>
      <form
        className={styles.form}
        onSubmit={(event) => {
          event.preventDefault();
          if (!canSubmit) {
            return;
          }
          void onSubmit({ email, password });
        }}
      >
        <label>
          <span className={styles.label}>{t(keys.auth.email.label)}</span>
          <input
            type="email"
            className={styles.input}
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            placeholder={t(keys.auth.email.placeholder)}
            disabled={isBusy}
            data-testid="auth.email"
          />
        </label>
        <label>
          <span className={styles.label}>{t(keys.auth.password.label)}</span>
          <input
            type="password"
            className={styles.input}
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder={t(keys.auth.password.placeholder)}
            disabled={isBusy}
            data-testid="auth.password"
          />
        </label>
        <Button type="submit" disabled={!canSubmit} data-testid="auth.signin.submit">
          {isBusy ? t(keys.auth.signin.submitting) : t(keys.auth.signin.submit)}
        </Button>
      </form>
      {statusMessage && (
        <Text
          className={statusIsError ? `${styles.status} ${styles.statusError}` : `${styles.status} ${styles.statusOk}`}
        >
          {statusMessage}
        </Text>
      )}
    </Card>
  );
}
