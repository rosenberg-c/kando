import { ApiError, BoardsService, type Board } from "../generated/api";
import { configureOpenApiClient } from "../api/openApi";
import type { Column } from "../generated/api";

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

export async function listBoardColumns(boardId: string): Promise<Column[]> {
  configureOpenApiClient();

  try {
    const response = await BoardsService.getBoard({ boardId });
    if (!response || typeof response !== "object" || !("columns" in response)) {
      return [];
    }

    const columns = (response as { columns: Column[] | null }).columns;
    if (!Array.isArray(columns)) {
      return [];
    }

    return [...columns].sort((left, right) => left.position - right.position);
  } catch (error) {
    if (error instanceof ApiError) {
      return [];
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
