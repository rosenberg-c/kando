# API and Error Handling

- `API-001`: The backend API is the source of truth for boards, columns, and tasks.
- `API-002`: Clients use generated OpenAPI client models and operations.
- `API-003`: Errors map to meaningful user-facing states (unauthorized, conflict, invalid input, not found).
- `API-004`: Backend API error responses include stable status and detail fields.
- `API-005`: Backend API provides list-based task reordering via `PUT /boards/{boardId}/tasks/order` with body `{ columns: [{ columnId: string, taskIds: string[] }] }`.
- `API-006`: Task reorder operations are atomic and do not expose partial-update states.
- `API-007`: Backend API provides dedicated task transfer endpoints for export/import (`GET /boards/{boardId}/tasks/export`, `POST /boards/{boardId}/tasks/import`) instead of requiring clients to orchestrate row-level transfer mutations.
- `API-008`: Task import validates payload format version and returns import summary counts (`createdColumnCount`, `importedTaskCount`).
- `API-009`: Task import applies atomically; on failure, it leaves board task/column state unchanged from pre-import state.
- `API-010`: Backend API creates a new board for `POST /boards` requests and does not enforce single-board-per-user semantics.
- `API-011`: Backend API returns all owned boards from `GET /boards`, sorted by most recently updated first.
- `API-012`: Board-scoped mutations require a valid board ID selected by the client and return stable `404`/`403` errors for missing/forbidden board access.
