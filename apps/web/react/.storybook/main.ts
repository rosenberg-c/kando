import type { StorybookConfig } from "@storybook/react-vite";

const config: StorybookConfig = {
  stories: ["../packages/**/*.stories.@(ts|tsx)", "../app/src/**/*.stories.@(ts|tsx)"],
  addons: [
    "@storybook/addon-essentials",
    "@storybook/addon-a11y",
    "@storybook/addon-interactions",
  ],
  framework: {
    name: "@storybook/react-vite",
    options: {},
  },
  viteFinal: async (viteConfig) => {
    viteConfig.resolve = viteConfig.resolve ?? {};
    const existingDedupe = viteConfig.resolve.dedupe ?? [];
    viteConfig.resolve.dedupe = [...existingDedupe, "react", "react-dom"];
    return viteConfig;
  },
};

export default config;
