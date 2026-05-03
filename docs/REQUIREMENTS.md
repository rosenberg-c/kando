# Requirements

This document is the entry point for product requirements. Detailed requirements are split by domain under `docs/requirements/`.

## Conventions

- Requirement IDs are globally unique and stable.
- Requirement IDs must not be recycled.
- Test tags should reference these IDs using `@req` markers in line comments (for example `// @req AUTH-001, API-012`).
- UI-facing requirements should declare platform applicability (`macOS`, `iOS`, `TUI`) so coverage can be tracked per client surface.
- Platform applicability states should use `required`, `planned`, or `N/A`.

## Domains

- [Authentication and Session](requirements/auth.md)
- [Board Workspace](requirements/board.md)
- [Column Management](requirements/column.md)
- [Task Management](requirements/task.md)
- [API and Error Handling](requirements/api.md)
- [Appwrite Integration and Auth Adapter](requirements/appwrite.md)
- [API Middleware and Security](requirements/security-middleware.md)
- [Public API Contract](requirements/public-api.md)
- [CLI Session and Storage](requirements/cli.md)
- [UX and Layout](requirements/ux.md)
- [Test Harness Baseline](requirements/test-harness.md)
