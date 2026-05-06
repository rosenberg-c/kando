import { keys, t } from "@kando/locale";

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
    <section className="workspace-card">
      <h1>{t(keys.workspace.title)}</h1>
      <p className="muted">{t(keys.workspace.subtitle, { email: signedInEmail })}</p>
      <p className="token-meta">{t(keys.workspace.tokenExpiry, { at: accessTokenExpiresAt })}</p>
      <div className="workspace-actions">
        <button type="button" onClick={() => void onSignOut()} disabled={isBusy} data-testid="auth.signout.submit">
          {t(keys.auth.signout.submit)}
        </button>
      </div>
      {statusMessage && (
        <p className={statusIsError ? "status error" : "status ok"}>{statusMessage}</p>
      )}
    </section>
  );
}
