import type { Meta, StoryObj } from "@storybook/react";
import { MemoryRouter } from "react-router-dom";
import { ThemeProvider } from "../../theme/ThemeProvider";
import { BoardsPage } from "./BoardsPage";

const meta = {
  title: "Pages/BoardsPage",
  component: BoardsPage,
  decorators: [
    (Story) => (
      <ThemeProvider>
        <MemoryRouter initialEntries={["/boards"]}>
          <div style={{ minHeight: "100vh", padding: "0.5rem" }}>
            <Story />
          </div>
        </MemoryRouter>
      </ThemeProvider>
    ),
  ],
  args: {
    hasSession: true,
    signedInEmail: "person@example.com",
    authUiState: {
      isBusy: false,
      statusMessage: "",
      statusIsError: false,
    },
    boards: [
      { id: "board-1", title: "Inbox" },
      { id: "board-2", title: "Roadmap" },
    ],
    onCreateBoard: async () => true,
    onRenameBoard: async () => true,
    onCreateColumn: async () => true,
    onCreateTask: async () => true,
    onDeleteColumn: async () => true,
    onDeleteTask: async () => true,
    onLoadWorkspace: async () => ({
      columns: [
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
      ],
      tasks: [
        {
          id: "task-1",
          boardId: "board-1",
          columnId: "column-1",
          title: "Draft requirements",
          description: "",
          position: 1,
          createdAt: "2026-01-01T00:00:00Z",
          updatedAt: "2026-01-01T00:00:00Z",
        },
      ],
    }),
    onSignOut: async () => {},
  },
} satisfies Meta<typeof BoardsPage>;

export default meta;

type Story = StoryObj<typeof meta>;

export const Default: Story = {};

export const EmptyBoards: Story = {
  args: {
    boards: [],
    onLoadWorkspace: async () => ({ columns: [], tasks: [] }),
  },
};

export const AuthStatusError: Story = {
  args: {
    authUiState: {
      isBusy: false,
      statusMessage: "Could not refresh session.",
      statusIsError: true,
    },
  },
};
