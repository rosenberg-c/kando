import type { Meta, StoryObj } from "@storybook/react";
import { ThemeProvider } from "../../theme/ThemeProvider";
import {
  CreateBoardModal,
  CreateColumnModal,
  DeleteColumnModal,
  EditBoardModal,
  RenameBoardModal,
} from "./BoardsModals";

const meta = {
  title: "Pages/BoardsModals",
  decorators: [
    (Story) => (
      <ThemeProvider>
        <div style={{ minHeight: "100vh" }}>
          <Story />
        </div>
      </ThemeProvider>
    ),
  ],
} satisfies Meta;

export default meta;

type Story = StoryObj<typeof meta>;

export const CreateBoard: Story = {
  render: () => (
    <CreateBoardModal
      isBusy={false}
      value="Roadmap"
      onChange={() => {}}
      onCancel={() => {}}
      onSubmit={() => {}}
    />
  ),
};

export const RenameBoardBusy: Story = {
  render: () => (
    <RenameBoardModal
      isBusy
      value="Inbox"
      onChange={() => {}}
      onCancel={() => {}}
      onSubmit={() => {}}
    />
  ),
};

export const EditBoard: Story = {
  render: () => <EditBoardModal onOpenRename={() => {}} onCancel={() => {}} />,
};

export const CreateColumn: Story = {
  render: () => (
    <CreateColumnModal
      isBusy={false}
      value="In progress"
      onChange={() => {}}
      onCancel={() => {}}
      onSubmit={() => {}}
    />
  ),
};

export const DeleteColumn: Story = {
  render: () => (
    <DeleteColumnModal
      isBusy={false}
      columnTitle="Backlog"
      onCancel={() => {}}
      onSubmit={() => {}}
    />
  ),
};
