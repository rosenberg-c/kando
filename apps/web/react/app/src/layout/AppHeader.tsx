import { Button } from "@kando/components";
import { keys, t } from "@kando/locale";
import { useEffect, useRef, useState } from "react";
import { useTheme } from "../theme/ThemeProvider";
import styles from "./AppHeader.module.css";

type AppHeaderProps = {
  hasSession: boolean;
  signedInEmail: string;
  isBusy: boolean;
  onSignOut: () => Promise<void>;
};

export function AppHeader({ hasSession, signedInEmail, isBusy, onSignOut }: AppHeaderProps) {
  const { theme, toggleTheme } = useTheme();
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement | null>(null);
  const panelId = "app.settings.panel";

  useEffect(() => {
    if (!isMenuOpen) {
      return;
    }

    function onDocumentPointerDown(event: PointerEvent) {
      const targetNode = event.target;
      if (!(targetNode instanceof Node)) {
        return;
      }

      if (!menuRef.current?.contains(targetNode)) {
        setIsMenuOpen(false);
      }
    }

    function onDocumentKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setIsMenuOpen(false);
      }
    }

    document.addEventListener("pointerdown", onDocumentPointerDown);
    document.addEventListener("keydown", onDocumentKeyDown);

    return () => {
      document.removeEventListener("pointerdown", onDocumentPointerDown);
      document.removeEventListener("keydown", onDocumentKeyDown);
    };
  }, [isMenuOpen]);

  return (
    <header className={styles.header}>
      <h1 className={styles.brand}>{t(keys.app.title)}</h1>
      <div className={styles.menu} ref={menuRef}>
        <Button
          type="button"
          variant="neutral"
          onClick={() => {
            setIsMenuOpen((currentOpen) => !currentOpen);
          }}
          aria-controls={isMenuOpen ? panelId : undefined}
          aria-expanded={isMenuOpen}
          data-testid="app.settings.toggle"
        >
          {t(keys.app.settings.button)}
        </Button>
        {isMenuOpen ? (
          <div
            id={panelId}
            className={styles.panel}
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
              onClick={toggleTheme}
              data-testid="app.settings.theme.toggle"
            >
              {theme === "dark"
                ? t(keys.app.settings.switchToLight)
                : t(keys.app.settings.switchToDark)}
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
        ) : null}
      </div>
    </header>
  );
}
