import { Button, Text } from "@kando/components";
import { useEffect, useMemo, useRef, useState } from "react";
import { Navigate } from "react-router-dom";
import { keys, t } from "@kando/locale";
import { useTheme } from "../../theme/ThemeProvider";
import { SettingsPanel } from "../../layout/SettingsPanel";
import { appRoutes } from "../../routes";
import type { Column } from "../../generated/api";
import type { AuthUiState } from "../authUiState";
import {
  CreateBoardModal,
  CreateColumnModal,
  DeleteColumnModal,
  EditBoardModal,
  RenameBoardModal,
} from "./BoardsModals";
import styles from "./BoardsPage.module.css";

type BoardsPageProps = {
  hasSession: boolean;
  signedInEmail: string | null;
  authUiState: AuthUiState;
  boards: Array<{
    id: string;
    title: string;
  }>;
  onCreateBoard: (title: string) => Promise<boolean>;
  onRenameBoard: (boardId: string, title: string) => Promise<boolean>;
  onCreateColumn: (boardId: string, title: string) => Promise<boolean>;
  onDeleteColumn: (boardId: string, columnId: string) => Promise<boolean>;
  onLoadBoardColumns: (boardId: string) => Promise<Column[]>;
  onSignOut: () => Promise<void>;
};

export function BoardsPage({
  hasSession,
  signedInEmail,
  authUiState,
  boards,
  onCreateBoard,
  onRenameBoard,
  onCreateColumn,
  onDeleteColumn,
  onLoadBoardColumns,
  onSignOut,
}: BoardsPageProps) {
  const { theme, toggleTheme } = useTheme();
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const settingsRef = useRef<HTMLDivElement | null>(null);
  const settingsPanelID = "app.settings.panel";
  const [selectedBoardID, setSelectedBoardID] = useState<string | null>(null);
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [isRenameModalOpen, setIsRenameModalOpen] = useState(false);
  const [isCreateColumnModalOpen, setIsCreateColumnModalOpen] = useState(false);
  const [newBoardTitle, setNewBoardTitle] = useState("");
  const [renameBoardTitle, setRenameBoardTitle] = useState("");
  const [newColumnTitle, setNewColumnTitle] = useState("");
  const [isCreatingBoard, setIsCreatingBoard] = useState(false);
  const [isRenamingBoard, setIsRenamingBoard] = useState(false);
  const [isCreatingColumn, setIsCreatingColumn] = useState(false);
  const [isDeleteColumnModalOpen, setIsDeleteColumnModalOpen] = useState(false);
  const [columnPendingDelete, setColumnPendingDelete] = useState<Column | null>(null);
  const [isDeletingColumn, setIsDeletingColumn] = useState(false);
  const [columns, setColumns] = useState<Column[]>([]);
  const [actionStatusMessage, setActionStatusMessage] = useState<string | null>(null);
  const [actionStatusIsError, setActionStatusIsError] = useState(false);

  useEffect(() => {
    if (!isSettingsOpen) {
      return;
    }

    function onDocumentPointerDown(event: PointerEvent) {
      const targetNode = event.target;
      if (!(targetNode instanceof Node)) {
        return;
      }

      if (!settingsRef.current?.contains(targetNode)) {
        setIsSettingsOpen(false);
      }
    }

    function onDocumentKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setIsSettingsOpen(false);
      }
    }

    document.addEventListener("pointerdown", onDocumentPointerDown);
    document.addEventListener("keydown", onDocumentKeyDown);

    return () => {
      document.removeEventListener("pointerdown", onDocumentPointerDown);
      document.removeEventListener("keydown", onDocumentKeyDown);
    };
  }, [isSettingsOpen]);

  useEffect(() => {
    if (boards.length === 0) {
      setSelectedBoardID(null);
      return;
    }

    const hasSelectedBoard = boards.some((board) => board.id === selectedBoardID);
    if (!hasSelectedBoard) {
      setSelectedBoardID(boards[0].id);
    }
  }, [boards, selectedBoardID]);

  const selectedBoardTitle = useMemo(() => {
    const selectedBoard = boards.find((board) => board.id === selectedBoardID);
    return selectedBoard?.title ?? t(keys.boards.title);
  }, [boards, selectedBoardID]);

  useEffect(() => {
    if (!selectedBoardID) {
      setColumns([]);
      return;
    }

    let isCancelled = false;

    const loadColumns = async () => {
      const nextColumns = await onLoadBoardColumns(selectedBoardID);
      if (!isCancelled) {
        setColumns(nextColumns);
      }
    };

    void loadColumns();

    return () => {
      isCancelled = true;
    };
  }, [onLoadBoardColumns, selectedBoardID]);

  if (!hasSession) {
    return <Navigate to={appRoutes.signIn} replace />;
  }

  async function handleCreateBoard() {
    const trimmedTitle = newBoardTitle.trim();
    if (!trimmedTitle) {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.boards.create.validationError));
      return;
    }

    setIsCreatingBoard(true);
    setActionStatusMessage(null);
    setActionStatusIsError(false);

    try {
      const didCreate = await onCreateBoard(trimmedTitle);
      if (!didCreate) {
        setActionStatusIsError(true);
        setActionStatusMessage(t(keys.boards.create.failed));
        return;
      }

      setActionStatusMessage(t(keys.boards.create.success));
      setIsCreateModalOpen(false);
      setNewBoardTitle("");
    } catch {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.boards.create.failed));
    } finally {
      setIsCreatingBoard(false);
    }
  }

  async function handleRenameBoard() {
    const trimmedTitle = renameBoardTitle.trim();
    if (!selectedBoardID) {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.boards.rename.failed));
      return;
    }
    if (!trimmedTitle) {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.boards.rename.validationError));
      return;
    }

    setIsRenamingBoard(true);
    setActionStatusMessage(null);
    setActionStatusIsError(false);

    try {
      const didRename = await onRenameBoard(selectedBoardID, trimmedTitle);
      if (!didRename) {
        setActionStatusIsError(true);
        setActionStatusMessage(t(keys.boards.rename.failed));
        return;
      }

      setActionStatusMessage(t(keys.boards.rename.success));
      setIsRenameModalOpen(false);
      setRenameBoardTitle("");
    } catch {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.boards.rename.failed));
    } finally {
      setIsRenamingBoard(false);
    }
  }

  async function handleCreateColumn() {
    const trimmedTitle = newColumnTitle.trim();
    if (!selectedBoardID) {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.columns.create.failed));
      return;
    }
    if (!trimmedTitle) {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.columns.create.validationError));
      return;
    }

    setIsCreatingColumn(true);
    setActionStatusMessage(null);
    setActionStatusIsError(false);

    try {
      const didCreate = await onCreateColumn(selectedBoardID, trimmedTitle);
      if (!didCreate) {
        setActionStatusIsError(true);
        setActionStatusMessage(t(keys.columns.create.failed));
        return;
      }

      setActionStatusMessage(t(keys.columns.create.success));
      setIsCreateColumnModalOpen(false);
      setNewColumnTitle("");
      const nextColumns = await onLoadBoardColumns(selectedBoardID);
      setColumns(nextColumns);
    } catch {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.columns.create.failed));
    } finally {
      setIsCreatingColumn(false);
    }
  }

  async function handleDeleteColumn() {
    if (!selectedBoardID || !columnPendingDelete) {
      return;
    }

    setIsDeletingColumn(true);
    setActionStatusMessage(null);
    setActionStatusIsError(false);

    try {
      const didDelete = await onDeleteColumn(selectedBoardID, columnPendingDelete.id);
      if (!didDelete) {
        setActionStatusIsError(true);
        setActionStatusMessage(t(keys.columns.delete.failed));
        return;
      }

      setActionStatusMessage(t(keys.columns.delete.success));
      setIsDeleteColumnModalOpen(false);
      setColumnPendingDelete(null);
      const nextColumns = await onLoadBoardColumns(selectedBoardID);
      setColumns(nextColumns);
    } catch {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.columns.delete.failed));
    } finally {
      setIsDeletingColumn(false);
    }
  }

  return (
    <section className={styles.board}>
      <div className={styles.workspaceHeader}>
        <div className={styles.headerMain}>
          <h1 className={styles.title}>{selectedBoardTitle}</h1>
          <label className={styles.boardSelectWrap}>
            <span className={styles.boardSelectLabel}>{t(keys.boards.dropdownLabel)}</span>
            <select
              className={styles.boardSelect}
              data-testid="app.boards.select"
              value={selectedBoardID ?? ""}
              onChange={(event) => {
                setSelectedBoardID(event.target.value || null);
              }}
            >
              {boards.length > 0 ? (
                boards.map((board) => (
                  <option key={board.id} value={board.id}>
                    {board.title}
                  </option>
                ))
              ) : (
                <option value="">{t(keys.boards.empty)}</option>
              )}
            </select>
          </label>
        </div>
        <div className={styles.headerActions}>
          <Button
            type="button"
            variant="neutral"
            className={styles.newBoardButton}
            data-testid="app.boards.create.open"
            onClick={() => {
              setIsCreateModalOpen(true);
              setActionStatusMessage(null);
              setActionStatusIsError(false);
            }}
          >
            {t(keys.boards.create.button)}
          </Button>
          <Button
            type="button"
            variant="neutral"
            className={styles.editBoardButton}
            data-testid="app.boards.edit.open"
            disabled={!selectedBoardID}
            onClick={() => {
              setIsEditModalOpen(true);
              setActionStatusMessage(null);
              setActionStatusIsError(false);
            }}
          >
            {t(keys.boards.edit.button)}
          </Button>
          <div className={styles.settingsMenu} ref={settingsRef}>
            <Button
              type="button"
              variant="neutral"
              onClick={() => {
                setIsSettingsOpen((currentOpen) => !currentOpen);
              }}
              aria-controls={isSettingsOpen ? settingsPanelID : undefined}
              aria-expanded={isSettingsOpen}
              data-testid="app.settings.toggle"
            >
              {t(keys.app.settings.button)}
            </Button>
            {isSettingsOpen ? (
              <SettingsPanel
                className={styles.settingsPopover}
                hasSession={hasSession}
                signedInEmail={signedInEmail}
                isBusy={authUiState.isBusy}
                isDarkTheme={theme === "dark"}
                panelId={settingsPanelID}
                onToggleTheme={toggleTheme}
                onSignOut={onSignOut}
              />
            ) : null}
          </div>
        </div>
      </div>
      <div className={styles.workspaceBody}>
        <div className={styles.workspaceToolbar}>
          <Button
            type="button"
            variant="neutral"
            data-testid="app.columns.create.open"
            disabled={!selectedBoardID}
            onClick={() => {
              setIsCreateColumnModalOpen(true);
              setActionStatusMessage(null);
              setActionStatusIsError(false);
            }}
          >
            {t(keys.columns.create.button)}
          </Button>
        </div>
        {columns.length > 0 ? (
          <div className={styles.columnsList} data-testid="app.columns.list">
            {columns.map((column) => (
              <section key={column.id} className={styles.columnCard} data-testid={`app.column.${column.id}`}>
                <div className={styles.columnHeader}>
                  <h2 className={styles.columnTitle}>{column.title}</h2>
                  <Button
                    type="button"
                    variant="neutral"
                    data-testid={`app.column.delete.open.${column.id}`}
                    onClick={() => {
                      setColumnPendingDelete(column);
                      setIsDeleteColumnModalOpen(true);
                      setActionStatusMessage(null);
                      setActionStatusIsError(false);
                    }}
                  >
                    {t(keys.columns.delete.button)}
                  </Button>
                </div>
                <Text variant="muted" className={styles.columnMeta}>
                  {t(keys.columns.count.tasks, { count: "0" })}
                </Text>
              </section>
            ))}
          </div>
        ) : (
          <>
            <Text className={styles.hint} variant="muted">
              {t(keys.boards.placeholderTitle)}
            </Text>
            <Text>{t(keys.boards.placeholderMessage)}</Text>
          </>
        )}
      </div>
      <div className={styles.workspaceMessages}>
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
        {actionStatusMessage !== null ? (
          <Text className={actionStatusIsError ? `${styles.status} ${styles.statusError}` : `${styles.status} ${styles.statusOk}`}>
            {actionStatusMessage}
          </Text>
        ) : null}
      </div>
      {isCreateModalOpen ? (
        <CreateBoardModal
          isBusy={isCreatingBoard}
          value={newBoardTitle}
          onChange={setNewBoardTitle}
          onCancel={() => {
            setIsCreateModalOpen(false);
            setNewBoardTitle("");
          }}
          onSubmit={() => {
            void handleCreateBoard();
          }}
        />
      ) : null}
      {isEditModalOpen ? (
        <EditBoardModal
          onOpenRename={() => {
            setIsEditModalOpen(false);
            setRenameBoardTitle(selectedBoardTitle);
            setIsRenameModalOpen(true);
          }}
          onCancel={() => {
            setIsEditModalOpen(false);
          }}
        />
      ) : null}
      {isRenameModalOpen ? (
        <RenameBoardModal
          isBusy={isRenamingBoard}
          value={renameBoardTitle}
          onChange={setRenameBoardTitle}
          onCancel={() => {
            setIsRenameModalOpen(false);
            setRenameBoardTitle("");
          }}
          onSubmit={() => {
            void handleRenameBoard();
          }}
        />
      ) : null}
      {isCreateColumnModalOpen ? (
        <CreateColumnModal
          isBusy={isCreatingColumn}
          value={newColumnTitle}
          onChange={setNewColumnTitle}
          onCancel={() => {
            setIsCreateColumnModalOpen(false);
            setNewColumnTitle("");
          }}
          onSubmit={() => {
            void handleCreateColumn();
          }}
        />
      ) : null}
      {isDeleteColumnModalOpen && columnPendingDelete ? (
        <DeleteColumnModal
          isBusy={isDeletingColumn}
          columnTitle={columnPendingDelete.title}
          onCancel={() => {
            setIsDeleteColumnModalOpen(false);
            setColumnPendingDelete(null);
          }}
          onSubmit={() => {
            void handleDeleteColumn();
          }}
        />
      ) : null}
    </section>
  );
}
