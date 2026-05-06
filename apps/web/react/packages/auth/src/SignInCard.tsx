import { useMemo, useState } from "react";
import { keys, t } from "@kando/locale";
import type { SignInParams } from "./types";

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
  const [keepSignedIn, setKeepSignedIn] = useState(true);

  const canSubmit = useMemo(() => {
    return email.trim().length > 0 && password.length > 0 && !isBusy;
  }, [email, password, isBusy]);

  return (
    <section className="auth-card" aria-busy={isBusy}>
      <h1>{t(keys.auth.signin.title)}</h1>
      <p className="muted">{t(keys.auth.signin.subtitle)}</p>
      <form
        className="auth-form"
        onSubmit={(event) => {
          event.preventDefault();
          if (!canSubmit) {
            return;
          }
          void onSubmit({ email, password, keepSignedIn });
        }}
      >
        <label>
          <span>{t(keys.auth.email.label)}</span>
          <input
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            placeholder={t(keys.auth.email.placeholder)}
            disabled={isBusy}
            data-testid="auth.email"
          />
        </label>
        <label>
          <span>{t(keys.auth.password.label)}</span>
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder={t(keys.auth.password.placeholder)}
            disabled={isBusy}
            data-testid="auth.password"
          />
        </label>
        <label className="checkbox-row">
          <input
            type="checkbox"
            checked={keepSignedIn}
            onChange={(event) => setKeepSignedIn(event.target.checked)}
            disabled={isBusy}
          />
          <span>{t(keys.auth.keepSignedIn)}</span>
        </label>
        <button type="submit" disabled={!canSubmit} data-testid="auth.signin.submit">
          {isBusy ? t(keys.auth.signin.submitting) : t(keys.auth.signin.submit)}
        </button>
      </form>
      {statusMessage && (
        <p className={statusIsError ? "status error" : "status ok"}>{statusMessage}</p>
      )}
    </section>
  );
}
