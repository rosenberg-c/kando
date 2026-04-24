# UX and Layout

- `UX-001`: Main workspace content anchors to top-leading layout.
- `UX-002`: Important status feedback is exposed in UI-facing state for success and failure states.
- `UX-003`: Destructive actions use destructive affordances and confirmations.
- `UX-004`: Client app surfaces API failure context (status/detail) in user-visible state.
- `UX-005`: Users can drag and drop tasks between columns in the board workspace.
- `UX-006`: Task move failures are surfaced to the user with actionable status context.
- `UX-007`: Releasing a dragged task on a column header area (not just on another task row) resolves to a valid destination position and does not fail with invalid-input errors.
- `UX-008`: Column content grows as tasks are added, but when a column's content would exceed the app viewport height, the task list area becomes scrollable instead of pushing workspace content (for example app title) out of bounds.
- `UX-009`: While a board mutation is pending, workspace interactions are disabled and a visible loading indicator is shown until the operation completes.
- `UX-010`: Workspace header exposes a `Settings` control in the upper-right area.
- `UX-011`: Refresh and sign-out actions are available from the settings panel instead of inline in the workspace header.

## Platform Applicability

- `UX-001`: macOS (required), iOS (planned), TUI (N/A).
- `UX-002`: macOS (required), iOS (planned), TUI (N/A).
- `UX-003`: macOS (required), iOS (planned), TUI (N/A).
- `UX-004`: macOS (required), iOS (planned), TUI (N/A).
- `UX-005`: macOS (required), iOS (planned), TUI (N/A).
- `UX-006`: macOS (required), iOS (planned), TUI (N/A).
- `UX-007`: macOS (required), iOS (planned), TUI (N/A).
- `UX-008`: macOS (required), iOS (planned), TUI (N/A).
- `UX-009`: macOS (required), iOS (planned), TUI (N/A).
- `UX-010`: macOS (required), iOS (planned), TUI (N/A).
- `UX-011`: macOS (required), iOS (planned), TUI (N/A).
