import type { Meta, StoryObj } from "@storybook/react";
import { SignInCard } from "./SignInCard";

const meta = {
  title: "Auth/SignInCard",
  component: SignInCard,
  args: {
    isBusy: false,
    statusMessage: "",
    statusIsError: false,
    onSubmit: async () => {},
  },
} satisfies Meta<typeof SignInCard>;

export default meta;

type Story = StoryObj<typeof meta>;

export const Default: Story = {};

export const Busy: Story = {
  args: {
    isBusy: true,
  },
};

export const SuccessStatus: Story = {
  args: {
    statusMessage: "Signed in successfully.",
    statusIsError: false,
  },
};

export const ErrorStatus: Story = {
  args: {
    statusMessage: "Sign-in failed.",
    statusIsError: true,
  },
};
