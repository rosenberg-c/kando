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
- `TASK-011`: Creating a task adds it to the selected column and the created task is visible after the board refresh cycle.
- `TASK-012`: On macOS, users can select a task row by clicking it with the mouse.
- `TASK-013`: On macOS, pressing `t` moves the selected task to the top of its column and pressing `b` moves the selected task to the bottom.
- `TASK-014`: On macOS, pressing `Esc` clears the current task-row selection.
- `TASK-015`: On macOS, pressing `u` moves the selected task one position up within its column.
- `TASK-016`: On macOS, pressing `d` moves the selected task one position down within its column.
- `TASK-017`: On macOS, pressing `e` opens edit mode for the selected task.
- `TASK-018`: On macOS, pressing `x` initiates delete flow for the selected task.
- `TASK-019`: On macOS, users can toggle whether `Top` and `Bottom` task controls are visible from settings.
- `TASK-020`: On macOS, users can toggle whether move-up and move-down task controls are visible from settings.
- `TASK-021`: On macOS, users can toggle whether task edit and delete controls are visible from settings.
- `TASK-022`: On macOS, in the task editor sheet, pressing `Enter` while focused on the title input submits the same primary action as tapping the sheet submit button.

## Delete Task Confirmation

- `TASK-DEL-001`: Deleting a task requires explicit user confirmation.
- `TASK-DEL-002`: The confirmation dialog includes the task title.
- `TASK-DEL-003`: Canceling the dialog performs no delete operation.
- `TASK-DEL-004`: Confirming the dialog executes the delete request.

## Platform Applicability

- `TASK-008`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-009`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-010`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-011`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-012`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-013`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-014`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-015`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-016`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-017`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-018`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-019`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-020`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-021`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-022`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-DEL-001`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-DEL-002`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-DEL-003`: macOS (required), iOS (planned), TUI (N/A).
- `TASK-DEL-004`: macOS (required), iOS (planned), TUI (N/A).
