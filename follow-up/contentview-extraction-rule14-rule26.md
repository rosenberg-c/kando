## Context

`apps/apple/Sources/Todo/TodoMacOS/ContentView.swift` has grown large and now carries substantial UI/state wiring.

## Follow-up

Perform a focused refactor to extract cohesive subviews/helpers and reduce prop/state sprawl.

## Why

- Improve readability and maintainability.
- Better align with `RULE 14` (keep functions small and explicit).
- Better align with `RULE 26` (prefer grouped UI state for repeated prop drilling).

## Scope

Non-blocking; not required for the current branch.
