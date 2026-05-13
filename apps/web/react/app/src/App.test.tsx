import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AuthProvider, type AuthTransport } from "@kando/auth";
import { keys, t } from "@kando/locale";
import { MemoryRouter } from "react-router-dom";
import App from "./App";
import { ThemeProvider } from "./theme/ThemeProvider";
import type { Board } from "./generated/api";
import type { BoardWorkspace, WorkspaceColumn, WorkspaceTask } from "./api/adapters/boards";

const {
  listOwnedBoardsMock,
  createOwnedBoardMock,
  renameOwnedBoardMock,
  createColumnInBoardMock,
  loadBoardWorkspaceMock,
  createTaskInBoardMock,
  deleteTaskInBoardMock,
  deleteColumnInBoardMock,
} = vi.hoisted(() => ({
  listOwnedBoardsMock: vi.fn<() => Promise<Board[]>>(async () => []),
  createOwnedBoardMock: vi.fn(async () => true),
  renameOwnedBoardMock: vi.fn(async () => true),
  createColumnInBoardMock: vi.fn(async () => true),
  loadBoardWorkspaceMock: vi.fn<() => Promise<BoardWorkspace>>(async () => ({ columns: [], tasks: [] })),
  createTaskInBoardMock: vi.fn(async () => true),
  deleteTaskInBoardMock: vi.fn(async () => true),
  deleteColumnInBoardMock: vi.fn(async () => true),
}));

vi.mock("./api/adapters/boards", () => ({
  listOwnedBoards: listOwnedBoardsMock,
  createOwnedBoard: createOwnedBoardMock,
  renameOwnedBoard: renameOwnedBoardMock,
  createColumnInBoard: createColumnInBoardMock,
  createTaskInBoard: createTaskInBoardMock,
  deleteTaskInBoard: deleteTaskInBoardMock,
  loadBoardWorkspace: loadBoardWorkspaceMock,
  deleteColumnInBoard: deleteColumnInBoardMock,
}));

function workspace(columns: WorkspaceColumn[], tasks: WorkspaceTask[] = []): BoardWorkspace {
  return { columns, tasks };
}

function makeBoard(overrides: Partial<Board> = {}): Board {
  return {
    id: "board-1",
    title: "Inbox",
    boardVersion: 1,
    createdAt: "2026-01-01T00:00:00Z",
    ownerUserId: "user-1",
    updatedAt: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

function makeColumn(overrides: Partial<WorkspaceColumn> = {}): WorkspaceColumn {
  return {
    id: "column-1",
    boardId: "board-1",
    title: "Backlog",
    position: 1,
    createdAt: "2026-01-01T00:00:00Z",
    updatedAt: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

function makeTask(overrides: Partial<WorkspaceTask> = {}): WorkspaceTask {
  return {
    id: "task-1",
    boardId: "board-1",
    columnId: "column-1",
    title: "First task",
    description: "",
    position: 1,
    createdAt: "2026-01-01T00:00:00Z",
    updatedAt: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

function deferred<T>() {
  let resolve: (value: T) => void = () => {};
  const promise = new Promise<T>((res) => {
    resolve = res;
  });
  return { promise, resolve };
}

function renderApp(transport: AuthTransport, initialEntries: string[] = ["/"]) {
  return render(
    <ThemeProvider>
      <AuthProvider transport={transport}>
        <MemoryRouter initialEntries={initialEntries}>
          <App />
        </MemoryRouter>
      </AuthProvider>
    </ThemeProvider>,
  );
}

async function waitForInitialSessionCheck() {
  await waitFor(() => {
    expect(screen.queryByTestId("app.session.loading")).toBeNull();
  });
}

async function openSettingsPanel() {
  await waitForInitialSessionCheck();
  await waitFor(() => {
    expect(screen.getByTestId("app.settings.toggle")).toBeTruthy();
  });
  fireEvent.click(screen.getByTestId("app.settings.toggle"));
}

const defaultTransport: AuthTransport = {
  signIn: async () => false,
  refreshSession: async () => false,
  revokeSession: async () => null,
  getIdentity: async () => null,
};

describe("App", () => {
  beforeEach(() => {
    listOwnedBoardsMock.mockReset();
    listOwnedBoardsMock.mockResolvedValue([]);
    createOwnedBoardMock.mockReset();
    createOwnedBoardMock.mockResolvedValue(true);
    renameOwnedBoardMock.mockReset();
    renameOwnedBoardMock.mockResolvedValue(true);
    createColumnInBoardMock.mockReset();
    createColumnInBoardMock.mockResolvedValue(true);
    loadBoardWorkspaceMock.mockReset();
    loadBoardWorkspaceMock.mockResolvedValue({ columns: [], tasks: [] });
    createTaskInBoardMock.mockReset();
    createTaskInBoardMock.mockResolvedValue(true);
    deleteTaskInBoardMock.mockReset();
    deleteTaskInBoardMock.mockResolvedValue(true);
    deleteColumnInBoardMock.mockReset();
    deleteColumnInBoardMock.mockResolvedValue(true);
  });

  afterEach(() => {
    cleanup();
  });

  // @req AUTH-004
  // @req UX-044
  it("renders sign in view by default", async () => {
    renderApp(defaultTransport);

    expect(screen.getByTestId("web.app")).toBeTruthy();

    await waitFor(() => {
      expect(screen.getByTestId("auth.email")).toBeTruthy();
      expect(screen.getByTestId("auth.password")).toBeTruthy();
      expect(screen.getByTestId("auth.signin.submit")).toBeTruthy();
    });
  });

  // @req UX-044
  it("shows a loading state before initial refresh resolves", async () => {
    const pendingRefresh = deferred<boolean>();
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => pendingRefresh.promise,
    };

    renderApp(transport);

    expect(screen.getByTestId("app.session.loading")).toBeTruthy();
    expect(screen.queryByTestId("auth.signin.submit")).toBeNull();

    pendingRefresh.resolve(false);

    await waitFor(() => {
      expect(screen.getByTestId("auth.signin.submit")).toBeTruthy();
      expect(screen.queryByTestId("app.session.loading")).toBeNull();
    });
  });

  // @req AUTH-001
  it("signs in with email/password and disables submit while request is in flight", async () => {
    const pending = deferred<boolean>();
    let signInCalls = 0;

    const transport: AuthTransport = {
      ...defaultTransport,
      signIn: async () => {
        signInCalls += 1;
        return pending.promise;
      },
    };

    renderApp(transport);

    await waitForInitialSessionCheck();

    await waitFor(() => {
      expect(screen.getByTestId("auth.email")).toBeTruthy();
    });

    fireEvent.change(screen.getByTestId("auth.email"), { target: { value: "person@example.com" } });
    fireEvent.change(screen.getByTestId("auth.password"), { target: { value: "secret" } });

    await waitFor(() => {
      expect(screen.getByTestId("auth.signin.submit").hasAttribute("disabled")).toBe(false);
    });

    fireEvent.click(screen.getByTestId("auth.signin.submit"));

    expect(signInCalls).toBe(1);
    expect(screen.getByTestId("auth.signin.submit").hasAttribute("disabled")).toBe(true);

    pending.resolve(true);

    await waitFor(() => {
      expect(screen.getByText(t(keys.boards.placeholderMessage))).toBeTruthy();
      expect(screen.queryByText("Signed in as {email}.")).toBeNull();
    });

    await openSettingsPanel();
    expect(screen.getByTestId("auth.signout.submit")).toBeTruthy();
  });

  // @req AUTH-002
  it("restores a valid session on app launch via refresh cookie", async () => {
    listOwnedBoardsMock.mockResolvedValue([
      {
        id: "board-1",
        title: "Inbox",
        boardVersion: 1,
        createdAt: "2026-01-01T00:00:00Z",
        ownerUserId: "user-1",
        updatedAt: "2026-01-01T00:00:00Z",
      },
      {
        id: "board-2",
        title: "Roadmap",
        boardVersion: 1,
        createdAt: "2026-01-01T00:00:00Z",
        ownerUserId: "user-1",
        updatedAt: "2026-01-01T00:00:00Z",
      },
    ]);

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "restore@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByText(t(keys.boards.placeholderMessage))).toBeTruthy();
      expect(screen.getByTestId("app.boards.select")).toBeTruthy();
      expect(screen.getByRole("option", { name: "Inbox" })).toBeTruthy();
      expect(screen.getByRole("option", { name: "Roadmap" })).toBeTruthy();
      expect(listOwnedBoardsMock).toHaveBeenCalledTimes(1);
    });

    await openSettingsPanel();
    expect(screen.getAllByTestId("auth.signout.submit").length).toBe(1);
  });

  // @req AUTH-003
  it("attempts refresh once on launch", async () => {
    let refreshCalls = 0;
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => {
        refreshCalls += 1;
        return true;
      },
      getIdentity: async () => ({ email: "refresh@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(refreshCalls).toBe(1);
      expect(screen.getByText(t(keys.boards.placeholderMessage))).toBeTruthy();
    });

    await openSettingsPanel();
    expect(screen.getAllByTestId("auth.signout.submit").length).toBe(1);
  });

  // @req UX-014
  it("shows an empty board option when signed in user has no boards", async () => {
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "empty@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByTestId("app.boards.select")).toBeTruthy();
      expect(screen.getByRole("option", { name: t(keys.boards.empty) })).toBeTruthy();
    });
  });

  // @req UX-016
  it("creates a board from modal and refreshes board dropdown", async () => {
    listOwnedBoardsMock
      .mockResolvedValueOnce([
        {
          id: "board-1",
          title: "Inbox",
          boardVersion: 1,
          createdAt: "2026-01-01T00:00:00Z",
          ownerUserId: "user-1",
          updatedAt: "2026-01-01T00:00:00Z",
        },
      ])
      .mockResolvedValueOnce([
        {
          id: "board-1",
          title: "Inbox",
          boardVersion: 1,
          createdAt: "2026-01-01T00:00:00Z",
          ownerUserId: "user-1",
          updatedAt: "2026-01-01T00:00:00Z",
        },
        {
          id: "board-2",
          title: "Roadmap",
          boardVersion: 1,
          createdAt: "2026-01-01T00:00:00Z",
          ownerUserId: "user-1",
          updatedAt: "2026-01-01T00:00:00Z",
        },
      ]);

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "creator@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByRole("option", { name: "Inbox" })).toBeTruthy();
      expect(screen.getByTestId("app.boards.edit.open").hasAttribute("disabled")).toBe(false);
    });

    fireEvent.click(screen.getByTestId("app.boards.create.open"));
    fireEvent.change(screen.getByTestId("app.boards.create.input"), {
      target: { value: "Roadmap" },
    });
    fireEvent.click(screen.getByTestId("app.boards.create.submit"));

    await waitFor(() => {
      expect(createOwnedBoardMock).toHaveBeenCalledWith("Roadmap");
      expect(screen.getByRole("option", { name: "Roadmap" })).toBeTruthy();
      expect(screen.queryByTestId("app.boards.create.modal")).toBeNull();
    });
  });

  // @req UX-016
  // @req UX-017
  it("renames a board from edit modal and refreshes board dropdown", async () => {
    listOwnedBoardsMock
      .mockResolvedValueOnce([
        {
          id: "board-1",
          title: "Inbox",
          boardVersion: 1,
          createdAt: "2026-01-01T00:00:00Z",
          ownerUserId: "user-1",
          updatedAt: "2026-01-01T00:00:00Z",
        },
      ])
      .mockResolvedValueOnce([
        {
          id: "board-1",
          title: "Roadmap",
          boardVersion: 1,
          createdAt: "2026-01-01T00:00:00Z",
          ownerUserId: "user-1",
          updatedAt: "2026-01-01T00:00:00Z",
        },
      ]);

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "editor@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByRole("option", { name: "Inbox" })).toBeTruthy();
      expect(screen.getByTestId("app.boards.edit.open").hasAttribute("disabled")).toBe(false);
    });

    fireEvent.click(screen.getByTestId("app.boards.edit.open"));
    fireEvent.click(screen.getByTestId("app.boards.rename.open"));
    fireEvent.change(screen.getByTestId("app.boards.rename.input"), {
      target: { value: "Roadmap" },
    });
    fireEvent.click(screen.getByTestId("app.boards.rename.submit"));

    await waitFor(() => {
      expect(renameOwnedBoardMock).toHaveBeenCalledWith("board-1", "Roadmap");
      expect(screen.getByRole("option", { name: "Roadmap" })).toBeTruthy();
      expect(screen.queryByTestId("app.boards.rename.modal")).toBeNull();
    });
  });

  // @req COL-001
  it("creates a column from workspace modal", async () => {
    listOwnedBoardsMock.mockResolvedValueOnce([makeBoard()]);

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "column@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByTestId("app.columns.create.open").hasAttribute("disabled")).toBe(false);
    });

    fireEvent.click(screen.getByTestId("app.columns.create.open"));
    fireEvent.change(screen.getByTestId("app.columns.create.input"), {
      target: { value: "Doing" },
    });
    fireEvent.click(screen.getByTestId("app.columns.create.submit"));

    await waitFor(() => {
      expect(createColumnInBoardMock).toHaveBeenCalledWith("board-1", "Doing");
      expect(screen.queryByTestId("app.columns.create.modal")).toBeNull();
    });
  });

  // @req TASK-001
  // @req TASK-011
  // @req UX-045
  it("creates a task from column footer add-task action", async () => {
    listOwnedBoardsMock.mockResolvedValueOnce([
      {
        id: "board-1",
        title: "Inbox",
        boardVersion: 1,
        createdAt: "2026-01-01T00:00:00Z",
        ownerUserId: "user-1",
        updatedAt: "2026-01-01T00:00:00Z",
      },
    ]);
    loadBoardWorkspaceMock
      .mockResolvedValueOnce(
        workspace([makeColumn()]),
      )
      .mockResolvedValueOnce(
        workspace(
          [makeColumn()],
          [makeTask({ description: "Optional description" })],
        ),
      );

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "task@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByTestId("app.tasks.create.open.column-1")).toBeTruthy();
    });

    fireEvent.click(screen.getByTestId("app.tasks.create.open.column-1"));
    fireEvent.change(screen.getByTestId("app.tasks.create.title"), {
      target: { value: "First task" },
    });
    fireEvent.change(screen.getByTestId("app.tasks.create.description"), {
      target: { value: "Optional description" },
    });
    fireEvent.click(screen.getByTestId("app.tasks.create.submit"));

    await waitFor(() => {
      expect(createTaskInBoardMock).toHaveBeenCalledWith("board-1", "column-1", "First task", "Optional description");
      expect(screen.getByText("First task")).toBeTruthy();
      expect(screen.getByText("Optional description")).toBeTruthy();
      expect(screen.queryByTestId("app.tasks.create.modal")).toBeNull();
    });
  });

  // @req TASK-045
  it("does not render a task description block when description is empty", async () => {
    listOwnedBoardsMock.mockResolvedValueOnce([makeBoard()]);
    loadBoardWorkspaceMock.mockResolvedValueOnce(
      workspace(
        [makeColumn()],
        [makeTask()],
      ),
    );

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "task-description-empty@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByTestId("app.task.task-1")).toBeTruthy();
      expect(screen.queryByTestId("app.task.description.task-1")).toBeNull();
    });
  });

  // @req TASK-003
  // @req TASK-DEL-001
  // @req TASK-DEL-002
  // @req TASK-DEL-004
  it("deletes a task from confirmation modal", async () => {
    listOwnedBoardsMock.mockResolvedValueOnce([makeBoard()]);
    loadBoardWorkspaceMock
      .mockResolvedValueOnce(
        workspace(
          [makeColumn()],
          [makeTask({ description: "desc" })],
        ),
      )
      .mockResolvedValueOnce(workspace([makeColumn()]));

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "task-delete@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByTestId("app.task.delete.open.task-1")).toBeTruthy();
    });

    fireEvent.click(screen.getByTestId("app.task.delete.open.task-1"));

    await waitFor(() => {
      const confirmText = screen.getByText("Delete task 'First task'?");
      expect(confirmText).toBeTruthy();
    });

    fireEvent.click(screen.getByTestId("app.tasks.delete.submit"));

    await waitFor(() => {
      expect(deleteTaskInBoardMock).toHaveBeenCalledWith("board-1", "task-1");
      expect(screen.queryByTestId("app.tasks.delete.modal")).toBeNull();
    });
  });

  // @req TASK-DEL-003
  it("does not delete a task when delete confirmation is canceled", async () => {
    listOwnedBoardsMock.mockResolvedValueOnce([makeBoard()]);
    loadBoardWorkspaceMock.mockResolvedValueOnce(
      workspace(
        [makeColumn()],
        [makeTask({ description: "desc" })],
      ),
    );

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "task-delete-cancel@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByTestId("app.task.delete.open.task-1")).toBeTruthy();
    });

    fireEvent.click(screen.getByTestId("app.task.delete.open.task-1"));

    await waitFor(() => {
      expect(screen.getByTestId("app.tasks.delete.modal")).toBeTruthy();
    });

    fireEvent.click(screen.getByTestId("app.tasks.delete.cancel"));

    await waitFor(() => {
      expect(deleteTaskInBoardMock).not.toHaveBeenCalled();
      expect(screen.queryByTestId("app.tasks.delete.modal")).toBeNull();
      expect(screen.getByText("First task")).toBeTruthy();
    });
  });

  // @req BOARD-001
  it("shows columns for the selected board", async () => {
    listOwnedBoardsMock.mockResolvedValueOnce([
      {
        id: "board-1",
        title: "Inbox",
        boardVersion: 1,
        createdAt: "2026-01-01T00:00:00Z",
        ownerUserId: "user-1",
        updatedAt: "2026-01-01T00:00:00Z",
      },
    ]);
    loadBoardWorkspaceMock.mockResolvedValueOnce(workspace([
      {
        id: "column-1",
        boardId: "board-1",
        title: "Backlog",
        position: 1,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z",
      },
      {
        id: "column-2",
        boardId: "board-1",
        title: "Doing",
        position: 2,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z",
      },
    ]));

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "columns@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByText("Backlog")).toBeTruthy();
      expect(screen.getByText("Doing")).toBeTruthy();
      expect(screen.getByTestId("app.columns.list")).toBeTruthy();
    });
  });

  // @req BOARD-001
  it("keeps latest board columns when board selection changes during in-flight loads", async () => {
    listOwnedBoardsMock.mockResolvedValueOnce([
      {
        id: "board-1",
        title: "Inbox",
        boardVersion: 1,
        createdAt: "2026-01-01T00:00:00Z",
        ownerUserId: "user-1",
        updatedAt: "2026-01-01T00:00:00Z",
      },
      {
        id: "board-2",
        title: "Roadmap",
        boardVersion: 1,
        createdAt: "2026-01-01T00:00:00Z",
        ownerUserId: "user-1",
        updatedAt: "2026-01-01T00:00:00Z",
      },
    ]);

    const board1Columns = deferred<BoardWorkspace>();
    const board2Columns = deferred<BoardWorkspace>();
    loadBoardWorkspaceMock.mockImplementation(async (boardId: string) => {
      if (boardId === "board-1") {
        return board1Columns.promise;
      }
      return board2Columns.promise;
    });

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "switch@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByTestId("app.boards.select")).toBeTruthy();
      expect(screen.getByRole("option", { name: "Inbox" })).toBeTruthy();
      expect(screen.getByRole("option", { name: "Roadmap" })).toBeTruthy();
    });

    fireEvent.change(screen.getByTestId("app.boards.select"), {
      target: { value: "board-2" },
    });

    board2Columns.resolve(workspace([
      {
        id: "column-2",
        boardId: "board-2",
        title: "Roadmap Doing",
        position: 1,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z",
      },
    ]));

    await waitFor(() => {
      expect(screen.getByText("Roadmap Doing")).toBeTruthy();
    });

    board1Columns.resolve(workspace([
      {
        id: "column-1",
        boardId: "board-1",
        title: "Inbox Backlog",
        position: 1,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z",
      },
    ]));

    await waitFor(() => {
      expect(screen.getByText("Roadmap Doing")).toBeTruthy();
      expect(screen.queryByText("Inbox Backlog")).toBeNull();
    });
  });

  // @req UX-015
  it("disables board selector while columns are loading", async () => {
    listOwnedBoardsMock.mockResolvedValueOnce([
      {
        id: "board-1",
        title: "Inbox",
        boardVersion: 1,
        createdAt: "2026-01-01T00:00:00Z",
        ownerUserId: "user-1",
        updatedAt: "2026-01-01T00:00:00Z",
      },
      {
        id: "board-2",
        title: "Roadmap",
        boardVersion: 1,
        createdAt: "2026-01-01T00:00:00Z",
        ownerUserId: "user-1",
        updatedAt: "2026-01-01T00:00:00Z",
      },
    ]);

    const pendingColumns = deferred<BoardWorkspace>();
    loadBoardWorkspaceMock.mockImplementation(async () => pendingColumns.promise);

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "loading@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByTestId("app.boards.select")).toBeTruthy();
    });

    await waitFor(() => {
      expect(screen.getByTestId("app.boards.select").hasAttribute("disabled")).toBe(true);
    });

    pendingColumns.resolve(workspace([]));

    await waitFor(() => {
      expect(screen.getByTestId("app.boards.select").hasAttribute("disabled")).toBe(false);
    });
  });

  // @req COL-003
  // @req COL-DEL-001
  // @req COL-DEL-002
  it("deletes a column from confirmation modal", async () => {
    listOwnedBoardsMock.mockResolvedValueOnce([
      {
        id: "board-1",
        title: "Inbox",
        boardVersion: 1,
        createdAt: "2026-01-01T00:00:00Z",
        ownerUserId: "user-1",
        updatedAt: "2026-01-01T00:00:00Z",
      },
    ]);
    loadBoardWorkspaceMock
      .mockResolvedValueOnce(workspace([
        {
          id: "column-1",
          boardId: "board-1",
          title: "Backlog",
          position: 1,
          createdAt: "2026-01-01T00:00:00Z",
          updatedAt: "2026-01-01T00:00:00Z",
        },
      ]))
      .mockResolvedValueOnce(workspace([]));

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "delete-column@example.com" }),
    };

    renderApp(transport);

    await waitFor(() => {
      expect(screen.getByText("Backlog")).toBeTruthy();
    });

    fireEvent.click(screen.getByTestId("app.column.delete.open.column-1"));

    await waitFor(() => {
      const confirmText = screen.getByText("Delete column 'Backlog'?");
      expect(confirmText).toBeTruthy();
    });

    fireEvent.click(screen.getByTestId("app.columns.delete.submit"));

    await waitFor(() => {
      expect(deleteColumnInBoardMock).toHaveBeenCalledWith("board-1", "column-1");
      expect(screen.queryByTestId("app.columns.delete.modal")).toBeNull();
    });
  });

  // @req AUTH-003
  // @req AUTH-004
  it("shows signed-out view and expired status when refresh cannot restore session", async () => {
    let refreshCalls = 0;

    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => {
        refreshCalls += 1;
        return false;
      },
    };

    renderApp(transport);

    await waitFor(() => {
      expect(refreshCalls).toBe(1);
      expect(screen.getByTestId("auth.signin.submit")).toBeTruthy();
      expect(screen.queryByTestId("auth.signout.submit")).toBeNull();
    });
  });

  // @req AUTH-008
  it("redirects signed-out users from /boards to /signin", async () => {
    renderApp(defaultTransport, ["/boards"]);

    await waitFor(() => {
      expect(screen.getByTestId("auth.signin.submit")).toBeTruthy();
      expect(screen.queryByTestId("auth.signout.submit")).toBeNull();
    });
  });

  // @req AUTH-008
  it("redirects signed-in users from /signin to /boards", async () => {
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "routes@example.com" }),
    };

    renderApp(transport, ["/signin"]);

    await waitFor(() => {
      expect(screen.queryByTestId("auth.signin.submit")).toBeNull();
    });

    await openSettingsPanel();
    expect(screen.getByTestId("auth.signout.submit")).toBeTruthy();
  });

  // @req UX-043
  it("toggles settings panel when pressing settings button", async () => {
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "settings@example.com" }),
    };

    renderApp(transport);

    await waitForInitialSessionCheck();

    await waitFor(() => {
      expect(screen.getByTestId("app.settings.toggle")).toBeTruthy();
    });

    const settingsButton = screen.getByTestId("app.settings.toggle");
    fireEvent.click(settingsButton);

    expect(screen.getByTestId("app.settings.panel")).toBeTruthy();
    expect(screen.getByTestId("app.settings.theme.toggle")).toBeTruthy();

    fireEvent.click(settingsButton);

    await waitFor(() => {
      expect(screen.queryByTestId("app.settings.panel")).toBeNull();
    });
  });

  // @req UX-043
  it("closes settings panel when clicking outside", async () => {
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "settings@example.com" }),
    };

    renderApp(transport);

    await waitForInitialSessionCheck();

    await waitFor(() => {
      expect(screen.getByTestId("app.settings.toggle")).toBeTruthy();
    });

    fireEvent.click(screen.getByTestId("app.settings.toggle"));
    expect(screen.getByTestId("app.settings.panel")).toBeTruthy();

    fireEvent.pointerDown(document.body);

    await waitFor(() => {
      expect(screen.queryByTestId("app.settings.panel")).toBeNull();
    });
  });

  // @req UX-043
  it("closes settings panel when escape is pressed", async () => {
    const transport: AuthTransport = {
      ...defaultTransport,
      refreshSession: async () => true,
      getIdentity: async () => ({ email: "settings@example.com" }),
    };

    renderApp(transport);

    await waitForInitialSessionCheck();

    await waitFor(() => {
      expect(screen.getByTestId("app.settings.toggle")).toBeTruthy();
    });

    fireEvent.click(screen.getByTestId("app.settings.toggle"));
    expect(screen.getByTestId("app.settings.panel")).toBeTruthy();

    fireEvent.keyDown(document, { key: "Escape" });

    await waitFor(() => {
      expect(screen.queryByTestId("app.settings.panel")).toBeNull();
    });
  });
});
