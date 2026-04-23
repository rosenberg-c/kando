# Task Management

- `TASK-001`: Users can create a task in a selected column with a non-empty title.
- `TASK-002`: Users can edit task title and description.
- `TASK-003`: Users can delete a task.
- `TASK-004`: Task order is stable and reindexed after structural updates.
- `TASK-005`: Users can move a task to a different column.
- `TASK-006`: Task ordering in a destination column is defined by a list-based API payload (`taskIds`) so moved tasks can be placed at specific positions.
- `TASK-007`: Moving a task preserves stable ordering in both source and destination columns after reindexing.
- `TASK-008`: Each task row exposes explicit move-up and move-down controls to adjust ordering within its column.
- `TASK-009`: Each task row exposes explicit `Top` and `Bottom` controls to move a task to the first or last position within its column.
- `TASK-010`: In each task row, `Top` and `Bottom` controls are shown above the task title, with `Top` left-aligned and `Bottom` right-aligned.

## Delete Task Confirmation

- `TASK-DEL-001`: Deleting a task requires explicit user confirmation.
- `TASK-DEL-002`: The confirmation dialog includes the task title.
- `TASK-DEL-003`: Canceling the dialog performs no delete operation.
- `TASK-DEL-004`: Confirming the dialog executes the delete request.

## Platform Applicability

- `TASK-008`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-009`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-010`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-DEL-001`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-DEL-002`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-DEL-003`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-DEL-004`: macOS (required), iOS (planned), TUI (N/A).
