import type { Meta, StoryObj } from "@storybook/react";
import { ThemeProvider } from "../theme/ThemeProvider";
import { SettingsPanel } from "./SettingsPanel";
import styles from "./SettingsPanel.stories.module.css";

const meta = {
  title: "App/SettingsPanel",
  component: SettingsPanel,
  decorators: [
    (Story) => (
      <ThemeProvider>
        <div className={styles.storySurface}>
          <Story />
        </div>
      </ThemeProvider>
    ),
  ],
  args: {
    hasSession: true,
    signedInEmail: "person@example.com",
    isBusy: false,
    isDarkTheme: false,
    panelId: "storybook.settings.panel",
    onToggleTheme: () => {},
    onSignOut: async () => {},
  },
} satisfies Meta<typeof SettingsPanel>;

export default meta;

type Story = StoryObj<typeof meta>;

export const SignedIn: Story = {};

export const SignedOut: Story = {
  args: {
    hasSession: false,
    signedInEmail: null,
  },
};

export const Busy: Story = {
  args: {
    isBusy: true,
  },
};

export const DarkThemeLabel: Story = {
  args: {
    isDarkTheme: true,
  },
};
