import type { Preview } from "@storybook/react-vite";
import "@kando/styles/tokens.css";
import "@kando/styles/base.css";

const THEME_STORAGE_KEY = "kando.theme";

const StorybookTheme = {
  Light: "light",
  Dark: "dark",
  System: "system",
} as const;

type StorybookTheme = (typeof StorybookTheme)[keyof typeof StorybookTheme];

function resolveTheme(selectedTheme: StorybookTheme): "light" | "dark" {
  if (selectedTheme === StorybookTheme.System) {
    if (
      typeof window !== "undefined" &&
      typeof window.matchMedia === "function" &&
      window.matchMedia("(prefers-color-scheme: dark)").matches
    ) {
      return StorybookTheme.Dark;
    }
    return StorybookTheme.Light;
  }

  return selectedTheme;
}

const preview: Preview = {
  globalTypes: {
    theme: {
      name: "Theme",
      description: "Global color theme",
      defaultValue: StorybookTheme.System,
      toolbar: {
        icon: "mirror",
        items: [
          { value: StorybookTheme.System, title: "System" },
          { value: StorybookTheme.Light, title: "Light" },
          { value: StorybookTheme.Dark, title: "Dark" },
        ],
      },
    },
  },
  decorators: [
    (Story, context) => {
      const selectedTheme = (context.globals.theme ?? StorybookTheme.System) as StorybookTheme;
      const resolvedTheme = resolveTheme(selectedTheme);
      document.documentElement.dataset.theme = resolvedTheme;

      if (typeof window !== "undefined") {
        window.localStorage.setItem(THEME_STORAGE_KEY, resolvedTheme);
      }

      return Story();
    },
  ],
};

export default preview;
