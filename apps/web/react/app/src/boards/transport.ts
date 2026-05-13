import { ApiError, BoardsService, type Board } from "../generated/api";
import { configureOpenApiClient } from "../api/openApi";
import type { BoardDetailsResponse, Column, Task } from "../generated/api";

export type BoardWorkspace = {
  columns: Column[];
  tasks: Task[];
};

function isBoardList(value: unknown): value is Board[] {
  return Array.isArray(value);
}

export async function listOwnedBoards(): Promise<Board[]> {
  configureOpenApiClient();

  try {
    const response = await BoardsService.listBoards({});
    return isBoardList(response) ? response : [];
  } catch (error) {
    if (error instanceof ApiError) {
      return [];
    }
    throw error;
  }
}

export async function createOwnedBoard(title: string): Promise<boolean> {
  configureOpenApiClient();

  try {
    await BoardsService.createBoard({
      requestBody: {
        title,
      },
    });
    return true;
  } catch (error) {
    if (error instanceof ApiError) {
      return false;
    }
    throw error;
  }
}

export async function renameOwnedBoard(boardId: string, title: string): Promise<boolean> {
  configureOpenApiClient();

  try {
    await BoardsService.updateBoard({
      boardId,
      requestBody: {
        title,
      },
    });
    return true;
  } catch (error) {
    if (error instanceof ApiError) {
      return false;
    }
    throw error;
  }
}

export async function createColumnInBoard(boardId: string, title: string): Promise<boolean> {
  configureOpenApiClient();

  try {
    await BoardsService.createColumn({
      boardId,
      requestBody: {
        title,
      },
    });
    return true;
  } catch (error) {
    if (error instanceof ApiError) {
      return false;
    }
    throw error;
  }
}

function mapBoardWorkspace(response: BoardDetailsResponse): BoardWorkspace {
  const columns = Array.isArray(response.columns)
    ? [...response.columns].sort((left, right) => left.position - right.position)
    : [];
  const tasks = Array.isArray(response.tasks)
    ? [...response.tasks].sort((left, right) => left.position - right.position)
    : [];

  return { columns, tasks };
}

export async function loadBoardWorkspace(boardId: string): Promise<BoardWorkspace> {
  configureOpenApiClient();

  try {
    const response = await BoardsService.getBoard({ boardId });
    if (!response || typeof response !== "object" || !("columns" in response) || !("tasks" in response)) {
      return { columns: [], tasks: [] };
    }

    return mapBoardWorkspace(response as BoardDetailsResponse);
  } catch (error) {
    if (error instanceof ApiError) {
      return { columns: [], tasks: [] };
    }
    throw error;
  }
}

export async function createTaskInBoard(boardId: string, columnId: string, title: string, description: string): Promise<boolean> {
  configureOpenApiClient();

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
    if (error instanceof ApiError) {
      return false;
    }
    throw error;
  }
}

export async function deleteTaskInBoard(boardId: string, taskId: string): Promise<boolean> {
  configureOpenApiClient();

  try {
    await BoardsService.deleteTask({
      boardId,
      taskId,
    });
    return true;
  } catch (error) {
    if (error instanceof ApiError) {
      return false;
    }
    throw error;
  }
}

export async function deleteColumnInBoard(boardId: string, columnId: string): Promise<boolean> {
  configureOpenApiClient();

  try {
    await BoardsService.deleteColumn({
      boardId,
      columnId,
    });
    return true;
  } catch (error) {
    if (error instanceof ApiError) {
      return false;
    }
    throw error;
  }
}
