export type WorkspaceColumn = {
  id: string;
  boardId: string;
  title: string;
  position: number;
  createdAt: string;
  updatedAt: string;
};

export type WorkspaceTask = {
  id: string;
  boardId: string;
  columnId: string;
  title: string;
  description: string;
  position: number;
  createdAt: string;
  updatedAt: string;
};

export type BoardWorkspace = {
  columns: WorkspaceColumn[];
  tasks: WorkspaceTask[];
};
