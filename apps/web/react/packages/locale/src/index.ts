import i18next from "i18next";
import { authEn } from "./en/auth";
import { commonEn } from "./en/common";

const dictionary = {
  ...commonEn,
  ...authEn,
} as const;

type Dictionary = typeof dictionary;

void i18next.init({
  lng: "en",
  fallbackLng: "en",
  interpolation: {
    escapeValue: false,
  },
  resources: {
    en: {
      translation: dictionary,
    },
  },
});

type TemplateValues = Record<string, string>;

type LeafPaths<T, Prefix extends string = ""> = {
  [K in keyof T & string]: T[K] extends string
    ? `${Prefix}${K}`
    : T[K] extends Record<string, unknown>
      ? LeafPaths<T[K], `${Prefix}${K}.`>
      : never;
}[keyof T & string];

type KeyTree<T, Prefix extends string = ""> = {
  [K in keyof T & string]: T[K] extends string
    ? `${Prefix}${K}`
    : T[K] extends Record<string, unknown>
      ? KeyTree<T[K], `${Prefix}${K}.`>
      : never;
};

function buildKeyTree<T extends Record<string, unknown>>(
  value: T,
  prefix = "",
): KeyTree<T> {
  const result: Record<string, unknown> = {};
  for (const [key, nested] of Object.entries(value)) {
    const path = `${prefix}${key}`;
    result[key] =
      typeof nested === "string" ? path : buildKeyTree(nested as Record<string, unknown>, `${path}.`);
  }
  return result as KeyTree<T>;
}

export const keys = buildKeyTree(dictionary);

type TranslationKey = LeafPaths<Dictionary>;

export function t(key: TranslationKey, values?: TemplateValues): string {
  return i18next.t(key, { ...values, defaultValue: key });
}
