import "./App.css";
import { useAuth } from "@kando/auth";
import { Spinner } from "@kando/components";
import { keys, t } from "@kando/locale";
import { useCallback, useEffect, useState } from "react";
import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import type { Board } from "./generated/api";
import {
  createTaskInBoard,
  createColumnInBoard,
  createOwnedBoard,
  deleteColumnInBoard,
  deleteTaskInBoard,
  loadBoardWorkspace,
  listOwnedBoards,
  renameOwnedBoard,
} from "./boards/transport";
import type { BoardWorkspace } from "./boards/transport";
import { BoardsPage } from "./pages/boards/BoardsPage";
import type { AuthUiState } from "./pages/authUiState";
import { SignInPage } from "./pages/sign-in/SignInPage";
import { appRoutes } from "./routes";

type BoardOption = {
  id: string;
  title: string;
};

function mapBoardsToOptions(boards: Board[]): BoardOption[] {
  return boards.map((board) => ({
    id: board.id,
    title: board.title,
  }));
}

export default function App() {
  const location = useLocation();
  const {
    hasInitialized,
    hasSession,
    isBusy,
    signedInEmail,
    statusMessage,
    statusIsError,
    signIn,
    signOut,
  } = useAuth();
  const [boards, setBoards] = useState<BoardOption[]>([]);

  const loadBoards = useCallback(async (shouldApply: () => boolean = () => true) => {
    const fetchedBoards = await listOwnedBoards();
    if (!shouldApply()) {
      return;
    }
    setBoards(mapBoardsToOptions(fetchedBoards));
  }, []);

  const createBoard = useCallback(async (title: string) => {
    const didCreate = await createOwnedBoard(title);
    if (didCreate) {
      await loadBoards();
    }
    return didCreate;
  }, [loadBoards]);

  const renameBoard = useCallback(async (boardId: string, title: string) => {
    const didRename = await renameOwnedBoard(boardId, title);
    if (didRename) {
      await loadBoards();
    }
    return didRename;
  }, [loadBoards]);

  const createColumn = useCallback(async (boardId: string, title: string) => {
    return createColumnInBoard(boardId, title);
  }, []);

  const deleteColumn = useCallback(async (boardId: string, columnId: string) => {
    return deleteColumnInBoard(boardId, columnId);
  }, []);

  const deleteTask = useCallback(async (boardId: string, taskId: string) => {
    return deleteTaskInBoard(boardId, taskId);
  }, []);

  const loadWorkspace = useCallback(async (boardId: string): Promise<BoardWorkspace> => {
    return loadBoardWorkspace(boardId);
  }, []);

  const createTask = useCallback(async (boardId: string, columnId: string, title: string, description: string) => {
    return createTaskInBoard(boardId, columnId, title, description);
  }, []);

  useEffect(() => {
    if (!hasSession) {
      setBoards([]);
      return;
    }

    let isCancelled = false;

    const loadBoardsForSession = async () => {
      try {
        await loadBoards(() => !isCancelled);
      } catch {
        if (!isCancelled) {
          setBoards([]);
        }
      }
    };

    void loadBoardsForSession();

    return () => {
      isCancelled = true;
    };
  }, [hasSession, loadBoards]);

  const authUiState: AuthUiState = {
    isBusy,
    statusMessage,
    statusIsError,
  };

  const shellClassName = location.pathname.startsWith(appRoutes.boards)
    ? "app-shell app-shellBoards"
    : "app-shell";

  if (!hasInitialized) {
    return (
      <div className="app-root" data-testid="web.app">
        <main className="app-shell" data-testid="app.session.loading">
          <Spinner label={t(keys.app.loading)} data-testid="app.session.spinner" />
        </main>
      </div>
    );
  }

  return (
    <div className="app-root" data-testid="web.app">
      <main className={shellClassName}>
        <Routes>
          <Route
            path={appRoutes.signIn}
            element={
              <SignInPage
                hasSession={hasSession}
                authUiState={authUiState}
                onSignIn={signIn}
              />
            }
          />
          <Route
            path={appRoutes.boards}
            element={
              <BoardsPage
                hasSession={hasSession}
                signedInEmail={signedInEmail}
                authUiState={authUiState}
                boards={boards}
                onCreateBoard={createBoard}
                onRenameBoard={renameBoard}
                onCreateColumn={createColumn}
                onCreateTask={createTask}
                onDeleteColumn={deleteColumn}
                onDeleteTask={deleteTask}
                onLoadWorkspace={loadWorkspace}
                onSignOut={signOut}
              />
            }
          />
          <Route
            path="*"
            element={<Navigate to={hasSession ? appRoutes.boards : appRoutes.signIn} replace />}
          />
        </Routes>
      </main>
    </div>
  );
}
