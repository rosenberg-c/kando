# TypeScript and React Rules

These rules apply to TypeScript and React code in this repository.
Use these alongside `docs/RULES.md` and `docs/PROJECT_RULES.md`.
When rules conflict, follow the most specific file for the area being changed.

## 1. Avoid TypeScript enums; prefer enum-like `as const` objects

- do not introduce `enum` or `const enum` in application code
- model named constant sets with object literals plus `as const`, then derive the union type from values
- keep keys descriptive (for usage/readability) and values explicit/stable (for serialization and boundary mapping)
- when migrating existing enum-like types, update comparisons and assignments to use the new object constants

Why:

- `const enum` depends on compile-time inlining and can break across tooling/transpile boundaries (for example isolated transpilation and mixed build pipelines)
- regular `enum` emits runtime JavaScript objects and reverse mappings, adding bundle/runtime overhead that object literals avoid
- `as const` objects are explicit at runtime, tree-shake well, and keep type inference and value-level usage aligned
- object-literal constants interoperate cleanly with JSON/network/storage values where stable string values are required

---

## 2. Prefer enum-like `as const` objects for multi-state UI status values

- when a UI/domain status has 2+ named states, define a single enum-like `as const` object and derive the union type from it
- use the constant object values in state initialization, comparisons, and assignments instead of repeating raw string literals
- keep status values stable and explicit so they remain safe for telemetry, storage, and API boundary mapping
- keep this pattern feature-local unless the same status set is intentionally shared across features

Why:

- centralizing status values prevents string drift and typo-prone comparisons
- constant-based comparisons improve refactor safety and readability in components with multiple state transitions
- deriving the union type from values preserves strict typing without introducing runtime-heavy enum objects

---

## 3. Prefer `null` over empty-string sentinels for missing values

- when a value can be absent, model it explicitly as `T | null` instead of using `""` as a sentinel
- initialize optional selected IDs, references, and derived lookup values with `null` unless an empty string is a real domain value
- branch on `value === null` (or a dedicated guard) for missing-state behavior, and keep `""` only for user-entered text fields that are actively being edited
- avoid overloading `""` to mean both "user entered empty text" and "no value exists"
- exception: controlled form inputs (for example `input`, `textarea`, and text-like `select` values in edit/create forms) may use `""` as the default and reset value because they represent editable text, not missing identity/state

Why:

- `null` communicates absence clearly and avoids ambiguous state semantics
- explicit nullable types improve type safety and make invalid transitions easier to catch
- separating "missing value" from "editable text" reduces UI bugs in selection and modal flows

---

## 4. Add Storybook coverage when implementing web UI features

- for new React UI features in `apps/web/react`, add or update Storybook stories in the same change
- include representative feature states (for example default, empty, loading/busy, success/error, and key interaction states)
- keep stories deterministic and local (no live network calls; use mocks/fixtures)
- when feature UI is composed from reusable components, ensure both feature-level stories and reusable component stories stay aligned

Why:

- stories make new UI behavior reviewable without booting full app flows
- feature states stay documented and easier to regression-test visually
- keeping story updates in the same change reduces drift between implementation and documentation
