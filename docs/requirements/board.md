# Board Workspace

- `BOARD-001`: The app loads the current user's board after sign-in.
- `BOARD-002`: The workspace shows board title, columns, and tasks.
- `BOARD-003`: Workspace actions are disabled while the board is not ready (no board context or loading state).
- `BOARD-004`: The app supports manual refresh of board state.
- `BOARD-005`: The app supports exporting all tasks on the active board to a JSON file.
- `BOARD-006`: The app supports importing tasks from a JSON file to populate the active board.
- `BOARD-007`: Exported task JSON includes a format version so future imports can validate compatibility.
- `BOARD-008`: Board task export/import uses dedicated backend transfer endpoints rather than client-side row-by-row mutation orchestration.
- `BOARD-009`: The app supports creating multiple boards/projects per authenticated user.
- `BOARD-010`: The app supports renaming the active board.
- `BOARD-011`: The app supports switching the active board from a board selector in the workspace header.
- `BOARD-012`: The app restores the last selected board when board context is available for the signed-in user.
- `BOARD-013`: The app supports deleting the active board only when that board has no tasks.
- `BOARD-014`: The app supports archiving the active board, including boards with tasks, to remove it from active board selection.
- `BOARD-015`: The app supports listing archived boards separately from active boards.
- `BOARD-016`: The app supports restoring an archived board back to active state.
- `BOARD-017`: The app supports permanent deletion of archived boards.
- `BOARD-018`: Task export supports selecting one or more owned boards and includes only checked boards in the exported JSON.
- `BOARD-019`: Task import supports selecting one or more boards discovered in the import file and imports only checked boards.
- `BOARD-020`: Multi-board export/import preserves board boundaries so columns and tasks remain associated with the correct board snapshot.

## Platform Applicability

- `BOARD-001`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-002`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-003`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-004`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-005`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-006`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-007`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-008`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-009`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-010`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-011`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-012`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-013`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-014`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-015`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-016`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-017`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-018`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-019`: macOS (required), iOS (planned), TUI (N/A).
- `BOARD-020`: macOS (required), iOS (planned), TUI (N/A).
