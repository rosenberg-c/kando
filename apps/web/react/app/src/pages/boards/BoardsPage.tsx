import { Button, Text } from "@kando/components";
import { useEffect, useMemo, useRef, useState } from "react";
import { Navigate } from "react-router-dom";
import { keys, t } from "@kando/locale";
import { useTheme } from "../../theme/ThemeProvider";
import { SettingsPanel } from "../../layout/SettingsPanel";
import { appRoutes } from "../../routes";
import type { BoardWorkspace, WorkspaceColumn, WorkspaceTask } from "../../api/adapters/boards";
import type { AuthUiState } from "../authUiState";
import {
  CreateBoardModal,
  CreateColumnModal,
  CreateTaskModal,
  DeleteColumnModal,
  DeleteTaskModal,
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
  onCreateBoard: (title: string) => Promise<string | null>;
  onRenameBoard: (boardId: string, title: string) => Promise<boolean>;
  onCreateColumn: (boardId: string, title: string) => Promise<boolean>;
  onCreateTask: (boardId: string, columnId: string, title: string, description: string) => Promise<boolean>;
  onDeleteColumn: (boardId: string, columnId: string) => Promise<boolean>;
  onDeleteTask: (boardId: string, taskId: string) => Promise<boolean>;
  onLoadWorkspace: (boardId: string) => Promise<BoardWorkspace>;
  onSignOut: () => Promise<void>;
};

type TaskCardProps = {
  task: WorkspaceTask;
  isMutating: boolean;
  onDeleteTask: (task: WorkspaceTask) => void;
};

function TaskCard({ task, isMutating, onDeleteTask }: TaskCardProps) {
  return (
    <div key={task.id} className={styles.taskItem} data-testid={`app.task.${task.id}`}>
      <Text>{task.title}</Text>
      {task.description ? (
        <Text variant="muted" className={styles.taskDescription} data-testid={`app.task.description.${task.id}`}>
          {task.description}
        </Text>
      ) : null}
      <div className={styles.taskActions}>
        <Button
          type="button"
          variant="neutral"
          data-testid={`app.task.delete.open.${task.id}`}
          disabled={isMutating}
          onClick={() => {
            onDeleteTask(task);
          }}
        >
          {t(keys.tasks.delete.button)}
        </Button>
      </div>
    </div>
  );
}

export function BoardsPage({
  hasSession,
  signedInEmail,
  authUiState,
  boards,
  onCreateBoard,
  onRenameBoard,
  onCreateColumn,
  onCreateTask,
  onDeleteColumn,
  onDeleteTask,
  onLoadWorkspace,
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
  const [isCreateTaskModalOpen, setIsCreateTaskModalOpen] = useState(false);
  const [columnPendingTaskCreate, setColumnPendingTaskCreate] = useState<WorkspaceColumn | null>(null);
  const [newBoardTitle, setNewBoardTitle] = useState("");
  const [renameBoardTitle, setRenameBoardTitle] = useState("");
  const [newColumnTitle, setNewColumnTitle] = useState("");
  const [newTaskTitle, setNewTaskTitle] = useState("");
  const [newTaskDescription, setNewTaskDescription] = useState("");
  const [isCreatingBoard, setIsCreatingBoard] = useState(false);
  const [isRenamingBoard, setIsRenamingBoard] = useState(false);
  const [isCreatingColumn, setIsCreatingColumn] = useState(false);
  const [isCreatingTask, setIsCreatingTask] = useState(false);
  const [isDeleteColumnModalOpen, setIsDeleteColumnModalOpen] = useState(false);
  const [columnPendingDelete, setColumnPendingDelete] = useState<WorkspaceColumn | null>(null);
  const [isDeletingColumn, setIsDeletingColumn] = useState(false);
  const [isDeleteTaskModalOpen, setIsDeleteTaskModalOpen] = useState(false);
  const [taskPendingDelete, setTaskPendingDelete] = useState<WorkspaceTask | null>(null);
  const [isDeletingTask, setIsDeletingTask] = useState(false);
  const [columns, setColumns] = useState<WorkspaceColumn[]>([]);
  const [tasks, setTasks] = useState<WorkspaceTask[]>([]);
  const [actionStatusMessage, setActionStatusMessage] = useState<string | null>(null);
  const [actionStatusIsError, setActionStatusIsError] = useState(false);
  // Keep both protections: selector disable avoids extra requests while loading,
  // request IDs prevent stale async responses from overwriting current board state.
  const columnsLoadRequestID = useRef(0);
  const [isLoadingColumns, setIsLoadingColumns] = useState(false);

  const isMutating = isCreatingBoard || isRenamingBoard || isCreatingColumn || isCreatingTask || isDeletingColumn || isDeletingTask;

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

  const tasksByColumnID = useMemo(() => {
    const grouped = new Map<string, WorkspaceTask[]>();
    for (const task of tasks) {
      const columnTasks = grouped.get(task.columnId);
      if (columnTasks) {
        columnTasks.push(task);
      } else {
        grouped.set(task.columnId, [task]);
      }
    }
    return grouped;
  }, [tasks]);

  useEffect(() => {
    if (!selectedBoardID) {
      setColumns([]);
      setTasks([]);
      setIsLoadingColumns(false);
      return;
    }

    let isCancelled = false;
    const requestID = columnsLoadRequestID.current + 1;
    columnsLoadRequestID.current = requestID;

    const loadColumns = async () => {
      setIsLoadingColumns(true);
      try {
        const workspace = await onLoadWorkspace(selectedBoardID);
        if (!isCancelled && columnsLoadRequestID.current === requestID) {
          setColumns(workspace.columns);
          setTasks(workspace.tasks);
        }
      } finally {
        if (!isCancelled && columnsLoadRequestID.current === requestID) {
          setIsLoadingColumns(false);
        }
      }
    };

    void loadColumns();

    return () => {
      isCancelled = true;
    };
  }, [onLoadWorkspace, selectedBoardID]);

  async function refreshWorkspace(boardId: string) {
    const workspace = await onLoadWorkspace(boardId);
    setColumns(workspace.columns);
    setTasks(workspace.tasks);
  }

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
      const createdBoardID = await onCreateBoard(trimmedTitle);
      if (!createdBoardID) {
        setActionStatusIsError(true);
        setActionStatusMessage(t(keys.boards.create.failed));
        return;
      }

      setSelectedBoardID(createdBoardID);
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
      await refreshWorkspace(selectedBoardID);
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
      await refreshWorkspace(selectedBoardID);
    } catch {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.columns.delete.failed));
    } finally {
      setIsDeletingColumn(false);
    }
  }

  async function handleCreateTask() {
    const trimmedTitle = newTaskTitle.trim();
    if (!selectedBoardID || !columnPendingTaskCreate) {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.tasks.create.failed));
      return;
    }
    if (!trimmedTitle) {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.tasks.create.validationError));
      return;
    }

    setIsCreatingTask(true);
    setActionStatusMessage(null);
    setActionStatusIsError(false);

    try {
      const didCreate = await onCreateTask(selectedBoardID, columnPendingTaskCreate.id, trimmedTitle, newTaskDescription);
      if (!didCreate) {
        setActionStatusIsError(true);
        setActionStatusMessage(t(keys.tasks.create.failed));
        return;
      }

      await refreshWorkspace(selectedBoardID);
      setActionStatusMessage(t(keys.tasks.create.success));
      setIsCreateTaskModalOpen(false);
      setColumnPendingTaskCreate(null);
      setNewTaskTitle("");
      setNewTaskDescription("");
    } catch {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.tasks.create.failed));
    } finally {
      setIsCreatingTask(false);
    }
  }

  async function handleDeleteTask() {
    if (!selectedBoardID || !taskPendingDelete) {
      return;
    }

    setIsDeletingTask(true);
    setActionStatusMessage(null);
    setActionStatusIsError(false);

    try {
      const didDelete = await onDeleteTask(selectedBoardID, taskPendingDelete.id);
      if (!didDelete) {
        setActionStatusIsError(true);
        setActionStatusMessage(t(keys.tasks.delete.failed));
        return;
      }

      await refreshWorkspace(selectedBoardID);
      setActionStatusMessage(t(keys.tasks.delete.success));
      setIsDeleteTaskModalOpen(false);
      setTaskPendingDelete(null);
    } catch {
      setActionStatusIsError(true);
      setActionStatusMessage(t(keys.tasks.delete.failed));
    } finally {
      setIsDeletingTask(false);
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
              disabled={isMutating || isLoadingColumns}
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
            data-testid="app.boards.create.open"
            disabled={isMutating}
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
            data-testid="app.boards.edit.open"
            disabled={!selectedBoardID || isMutating}
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
              disabled={isMutating}
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
            disabled={!selectedBoardID || isMutating}
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
            {columns.map((column) => {
              const columnTasks = tasksByColumnID.get(column.id) ?? [];
              return (
              <section key={column.id} className={styles.columnCard} data-testid={`app.column.${column.id}`}>
                <div className={styles.columnHeader}>
                  <h2 className={styles.columnTitle}>{column.title}</h2>
                  <Button
                    type="button"
                    variant="neutral"
                    data-testid={`app.column.delete.open.${column.id}`}
                    disabled={isMutating}
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
                  {t(keys.columns.count.tasks, {
                    count: String(columnTasks.length),
                  })}
                </Text>
                <div className={styles.taskList}>
                  {columnTasks.map((task) => (
                    <TaskCard
                      key={task.id}
                      task={task}
                      isMutating={isMutating}
                      onDeleteTask={(nextTask) => {
                        setTaskPendingDelete(nextTask);
                        setIsDeleteTaskModalOpen(true);
                        setActionStatusMessage(null);
                        setActionStatusIsError(false);
                      }}
                    />
                  ))}
                </div>
                <div className={styles.columnFooter}>
                  <Button
                    type="button"
                    variant="neutral"
                    data-testid={`app.tasks.create.open.${column.id}`}
                    disabled={isMutating}
                    onClick={() => {
                      setColumnPendingTaskCreate(column);
                      setIsCreateTaskModalOpen(true);
                      setActionStatusMessage(null);
                      setActionStatusIsError(false);
                    }}
                  >
                    {t(keys.tasks.create.button)}
                  </Button>
                </div>
              </section>
              );
            })}
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
      {isCreateTaskModalOpen && columnPendingTaskCreate ? (
        <CreateTaskModal
          isBusy={isCreatingTask}
          title={newTaskTitle}
          description={newTaskDescription}
          onChangeTitle={setNewTaskTitle}
          onChangeDescription={setNewTaskDescription}
          onCancel={() => {
            setIsCreateTaskModalOpen(false);
            setColumnPendingTaskCreate(null);
            setNewTaskTitle("");
            setNewTaskDescription("");
          }}
          onSubmit={() => {
            void handleCreateTask();
          }}
        />
      ) : null}
      {isDeleteTaskModalOpen && taskPendingDelete ? (
        <DeleteTaskModal
          isBusy={isDeletingTask}
          taskTitle={taskPendingDelete.title}
          onCancel={() => {
            setIsDeleteTaskModalOpen(false);
            setTaskPendingDelete(null);
          }}
          onSubmit={() => {
            void handleDeleteTask();
          }}
        />
      ) : null}
    </section>
  );
}
