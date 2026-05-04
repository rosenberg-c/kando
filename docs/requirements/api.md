# API and Error Handling

### `API-001`

The backend API is the source of truth for boards, columns, and tasks.

### `API-002`

Clients use generated OpenAPI client models and operations.

### `API-003`

Errors map to meaningful user-facing states (unauthorized, conflict, invalid input, not found).

### `API-004`

Backend API error responses include stable status and detail fields.

### `API-005`

Backend API provides list-based task reordering via `PUT /boards/{boardId}/tasks/order` with body `{ columns: [{ columnId: string, taskIds: string[] }] }`.

### `API-006`

Task reorder operations are atomic and do not expose partial-update states.

### `API-007`

Backend API provides dedicated task transfer endpoints for export/import (`POST /boards/tasks/export`, `POST /boards/tasks/import`) so clients can transfer selected board snapshots without row-level mutation orchestration.

### `API-008`

Task import validates payload format version and returns import summary counts (`createdColumnCount`/`importedTaskCount` for per-board results and `totalCreatedColumnCount`/`totalImportedTaskCount` for bundle totals).

### `API-009`

Task import applies atomically; on failure, it leaves board task/column state unchanged from pre-import state.

### `API-010`

Backend API creates a new board for `POST /boards` requests and does not enforce single-board-per-user semantics.

### `API-011`

Backend API returns all owned boards from `GET /boards`, sorted by most recently updated first.

### `API-012`

Board-scoped mutations require a valid board ID selected by the client and return stable `404`/`403` errors for missing/forbidden board access.

### `API-013`

Backend API deletes a board via board-scoped delete endpoint only when the board has zero tasks; otherwise it returns a stable conflict/invalid-state error.

### `API-014`

Backend API supports board archive state transitions (`active` <-> `archived`) and enforces ownership checks on archive/restore operations.

### `API-015`

Backend API provides archived-board listing separate from active-board listing.

### `API-016`

Backend API permanent-delete operation is supported for archived boards and returns stable conflict/invalid-state errors when deletion preconditions are not met.

### `API-017`

Backend API supports multi-board task export/import so clients can transfer selected board snapshots in one operation.

### `API-018`

Multi-board task import applies atomically per selected destination board; failure for one selected board does not partially mutate that board.

### `API-019`

Multi-board task transfer payload includes stable source board identity metadata and keeps columns/tasks nested under their board snapshot.

### `API-020`

Archiving a board rewrites the board title with an archive timestamp suffix and returns the updated title in the archive response.

### `API-021`

Backend archive persistence stores the pre-archive board title separately from the display `title` so restore behavior does not depend on string parsing.

### `API-022`

`POST /boards/{boardId}/restore` accepts an explicit restore title mode (`original` or `archived`) and returns the restored board with the selected title.

### `API-023`

Restore requests using title mode `original` fail with a stable conflict error when the original title matches an existing active board title for the same owner.

### `API-024`

Backend API exposes a column-scoped archive endpoint for tasks at `POST /boards/{boardId}/columns/{columnId}/archive-tasks`.

### `API-025`

Column task archive endpoint returns stable and meaningful error mapping for invalid input, missing resources, and unauthorized access (`400`/`404`/`403`).

### `API-026`

Task export/import contracts include archived tasks per column snapshot and enforce stable format-version validation for archived-task payloads.

### `API-027`

Backend API exposes a board-scoped archived-task listing endpoint at `GET /boards/{boardId}/tasks/archived` for workspace presentation flows.

### `API-028`

Archived-task listing returns tasks with stable column identity and archival metadata (`columnId`, `archivedAt`) suitable for grouping by original column in clients.

### `API-029`

Archived-task listing order is stable and deterministic (`column position`, then `archivedAt`, then `position`, then `id`) so clients do not need custom tie-breaking logic.

### `API-030`

Backend API exposes archived-task restore endpoint at `POST /boards/{boardId}/tasks/{taskId}/restore` and restores only archived tasks owned by the caller.

### `API-031`

Backend API exposes archived-task delete endpoint at `DELETE /boards/{boardId}/tasks/{taskId}/archived` and permanently removes only archived tasks owned by the caller.

### `API-032`

Archived-task restore/delete endpoints return stable conflict/not-found behavior for invalid task state transitions (for example restoring active tasks or deleting non-archived tasks).

### `API-033`

Backend API exposes list-based task batch action contracts where each request carries explicit action intent and task membership (`action`, `taskIds[]`) rather than client-side sequential single-task mutation loops. For the Appwrite backend, task batch delete currently uses a non-atomic sequential fallback and does not guarantee all-or-nothing behavior on failure.
