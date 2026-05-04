# Column Management

### `COL-001`

Users can create a column with a non-empty title.

### `COL-002`

Users can rename a column with a non-empty title.

### `COL-003`

Users can delete a column.

### `COL-004`

Column order is stable and reindexed after structural updates.


## Delete Column Confirmation

### `COL-DEL-001`

Deleting a column requires explicit user confirmation.

### `COL-DEL-002`

The confirmation dialog includes the column title.

### `COL-DEL-003`

Canceling the dialog performs no delete operation.

### `COL-DEL-004`

Confirming the dialog executes the delete request.


## Delete Column Rule

### `COL-RULE-001`

A column that still contains tasks must not be deletable.

### `COL-RULE-002`

The API returns conflict (`409`) for this case.

### `COL-RULE-003`

The UI surfaces the failure status to the user.

### `COL-RULE-004`

A column that contains archived tasks must not be deletable until those archived tasks are removed or restored.

### `COL-RULE-005`

Column-delete conflicts for archived-task presence return stable conflict detail and do not partially mutate column/task state.


## Move Column

### `COL-MOVE-001`

Users can reorder columns within a board.

### `COL-MOVE-002`

Reordering supports moving a column to any valid destination position (start, middle, or end), including full reversals such as `A, B, C -> C, B, A`.

### `COL-MOVE-003`

Column move operations are atomic and must not expose partial-order states.

### `COL-MOVE-004`

After a successful move, column positions are stable, contiguous, and reindexed.

### `COL-MOVE-005`

Column moves are board-scoped and owner-scoped; cross-board moves are rejected.

### `COL-MOVE-006`

Invalid move inputs return meaningful API errors (`422` malformed reorder payload shape, `400` invalid board membership/order semantics, `404` missing board, `403` unauthorized).

### `COL-MOVE-007`

The backend exposes bulk reorder API `PUT /boards/{boardId}/columns/order` with body `{ columnIds: string[] }` (full ordered list, exact board membership) and returns reordered columns on success.

### `COL-MOVE-008`

Client UI preserves prior order on move failure and surfaces failure context.

### `COL-MOVE-009`

On macOS, column reordering is initiated from `Edit board`, managed inside the reorder modal, and persisted only when the user confirms with `Done`.

### `COL-MOVE-010`

Concurrent move requests preserve a valid deterministic order without duplicate or missing positions.

### `COL-MOVE-011`

Bulk reorder requests are atomic: either the full new order is persisted or no column positions change.


## Archive Column Tasks

### `COL-ARCH-001`

When archiving tasks for a column, all tasks archived by the same archive action must receive the exact same `archivedAt` timestamp value.

### `COL-ARCH-002`

Users can archive all active tasks in a single column with one archive action.

### `COL-ARCH-003`

Archiving tasks for a column is column-scoped and must not archive tasks in other columns.

### `COL-ARCH-004`

Column task archive actions are atomic: either all targeted tasks are archived or none are.

### `COL-ARCH-005`

Archived tasks remain associated with their original board and column identity.


## Platform Applicability

- `COL-DEL-001`: macOS (required), iOS (planned), TUI (N/A).
- `COL-DEL-002`: macOS (required), iOS (planned), TUI (N/A).
- `COL-DEL-003`: macOS (required), iOS (planned), TUI (N/A).
- `COL-DEL-004`: macOS (required), iOS (planned), TUI (N/A).
- `COL-RULE-003`: macOS (required), iOS (planned), TUI (N/A).
- `COL-RULE-004`: macOS (required), iOS (planned), TUI (planned).
- `COL-RULE-005`: macOS (required), iOS (planned), TUI (planned).
- `COL-MOVE-008`: macOS (required), iOS (planned), TUI (planned).
- `COL-MOVE-009`: macOS (required), iOS (planned), TUI (planned).
- `COL-ARCH-001`: macOS (required), iOS (planned), TUI (planned).
- `COL-ARCH-002`: macOS (required), iOS (planned), TUI (planned).
- `COL-ARCH-003`: macOS (required), iOS (planned), TUI (planned).
- `COL-ARCH-004`: macOS (required), iOS (planned), TUI (planned).
- `COL-ARCH-005`: macOS (required), iOS (planned), TUI (planned).
