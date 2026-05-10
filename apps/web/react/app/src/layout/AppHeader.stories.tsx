import type { Meta, StoryObj } from "@storybook/react";
import { ThemeProvider } from "../theme/ThemeProvider";
import { AppHeader } from "./AppHeader";

const meta = {
  title: "App/AppHeader",
  component: AppHeader,
  decorators: [
    (Story) => (
      <ThemeProvider>
        <Story />
      </ThemeProvider>
    ),
  ],
  args: {
    hasSession: true,
    signedInEmail: "person@example.com",
    isBusy: false,
    onSignOut: async () => {},
  },
} satisfies Meta<typeof AppHeader>;

export default meta;

type Story = StoryObj<typeof meta>;

export const SignedIn: Story = {};

export const SignedOut: Story = {
  args: {
    hasSession: false,
    signedInEmail: "",
  },
};

export const Busy: Story = {
  args: {
    isBusy: true,
  },
};
