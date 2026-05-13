import { BoardsService, type Board } from "../../generated/api";
import type { BoardDetailsResponse, Column as ApiColumn, Task as ApiTask } from "../../generated/api";
import { ensureApiClientConfigured } from "../client";
import { mapApiError } from "../handleApiError";
import type { BoardWorkspace, WorkspaceColumn, WorkspaceTask } from "./models";

export type { BoardWorkspace, WorkspaceColumn, WorkspaceTask } from "./models";

function mapWorkspaceColumn(column: ApiColumn): WorkspaceColumn {
  return {
    id: column.id,
    boardId: column.boardId,
    title: column.title,
    position: column.position,
    createdAt: column.createdAt,
    updatedAt: column.updatedAt,
  };
}

function mapWorkspaceTask(task: ApiTask): WorkspaceTask {
  return {
    id: task.id,
    boardId: task.boardId,
    columnId: task.columnId,
    title: task.title,
    description: task.description,
    position: task.position,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
  };
}

function isBoardList(value: unknown): value is Board[] {
  return Array.isArray(value);
}

export async function listOwnedBoards(): Promise<Board[]> {
  ensureApiClientConfigured();

  try {
    const response = await BoardsService.listBoards({});
    return isBoardList(response) ? response : [];
  } catch (error) {
    return mapApiError(error, () => []);
  }
}

export async function createOwnedBoard(title: string): Promise<boolean> {
  ensureApiClientConfigured();

  try {
    await BoardsService.createBoard({
      requestBody: {
        title,
      },
    });
    return true;
  } catch (error) {
    return mapApiError(error, () => false);
  }
}

export async function renameOwnedBoard(boardId: string, title: string): Promise<boolean> {
  ensureApiClientConfigured();

  try {
    await BoardsService.updateBoard({
      boardId,
      requestBody: {
        title,
      },
    });
    return true;
  } catch (error) {
    return mapApiError(error, () => false);
  }
}

export async function createColumnInBoard(boardId: string, title: string): Promise<boolean> {
  ensureApiClientConfigured();

  try {
    await BoardsService.createColumn({
      boardId,
      requestBody: {
        title,
      },
    });
    return true;
  } catch (error) {
    return mapApiError(error, () => false);
  }
}

function mapBoardWorkspace(response: BoardDetailsResponse): BoardWorkspace {
  const columns = Array.isArray(response.columns)
    ? [...response.columns]
      .sort((left, right) => left.position - right.position)
      .map(mapWorkspaceColumn)
    : [];
  const tasks = Array.isArray(response.tasks)
    ? [...response.tasks]
      .sort((left, right) => left.position - right.position)
      .map(mapWorkspaceTask)
    : [];

  return { columns, tasks };
}

export async function loadBoardWorkspace(boardId: string): Promise<BoardWorkspace> {
  ensureApiClientConfigured();

  try {
    const response = await BoardsService.getBoard({ boardId });
    if (!response || typeof response !== "object" || !("columns" in response) || !("tasks" in response)) {
      return { columns: [], tasks: [] };
    }

    return mapBoardWorkspace(response as BoardDetailsResponse);
  } catch (error) {
    return mapApiError(error, () => ({ columns: [], tasks: [] }));
  }
}

export async function createTaskInBoard(boardId: string, columnId: string, title: string, description: string): Promise<boolean> {
  ensureApiClientConfigured();

  try {
    await BoardsService.createTask({
      boardId,
      requestBody: {
        columnId,
        title,
        description,
      },
    });
    return true;
  } catch (error) {
    return mapApiError(error, () => false);
  }
}

export async function deleteTaskInBoard(boardId: string, taskId: string): Promise<boolean> {
  ensureApiClientConfigured();

  try {
    await BoardsService.deleteTask({
      boardId,
      taskId,
    });
    return true;
  } catch (error) {
    return mapApiError(error, () => false);
  }
}

export async function deleteColumnInBoard(boardId: string, columnId: string): Promise<boolean> {
  ensureApiClientConfigured();

  try {
    await BoardsService.deleteColumn({
      boardId,
      columnId,
    });
    return true;
  } catch (error) {
    return mapApiError(error, () => false);
  }
}
