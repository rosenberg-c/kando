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
