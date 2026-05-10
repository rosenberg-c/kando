import { Button } from "@kando/components";
import { keys, t } from "@kando/locale";
import styles from "./SettingsPanel.module.css";

type SettingsPanelProps = {
  className?: string;
  hasSession: boolean;
  signedInEmail: string;
  isBusy: boolean;
  isDarkTheme: boolean;
  panelId: string;
  onToggleTheme: () => void;
  onSignOut: () => Promise<void>;
};

export function SettingsPanel({
  className,
  hasSession,
  signedInEmail,
  isBusy,
  isDarkTheme,
  panelId,
  onToggleTheme,
  onSignOut,
}: SettingsPanelProps) {
  const panelClassName = [styles.panel, className].filter(Boolean).join(" ");

  return (
    <div
      id={panelId}
      className={panelClassName}
      role="region"
      aria-label={t(keys.app.settings.panelLabel)}
      data-testid="app.settings.panel"
    >
      <p className={styles.identity}>
        {hasSession
          ? t(keys.app.settings.signedInAs, {
              email: signedInEmail || t(keys.app.settings.unknownUser),
            })
          : t(keys.app.settings.signedOut)}
      </p>
      <Button
        type="button"
        variant="neutral"
        onClick={onToggleTheme}
        data-testid="app.settings.theme.toggle"
      >
        {isDarkTheme ? t(keys.app.settings.switchToLight) : t(keys.app.settings.switchToDark)}
      </Button>
      {hasSession ? (
        <Button
          type="button"
          variant="danger"
          onClick={() => void onSignOut()}
          disabled={isBusy}
          data-testid="auth.signout.submit"
        >
          {t(keys.auth.signout.submit)}
        </Button>
      ) : null}
    </div>
  );
}
