# API and Error Handling

- `API-001`: The backend API is the source of truth for boards, columns, and tasks.
- `API-002`: Clients use generated OpenAPI client models and operations.
- `API-003`: Errors map to meaningful user-facing states (unauthorized, conflict, invalid input, not found).
- `API-004`: Backend API error responses include stable status and detail fields.
- `API-005`: Backend API provides `PATCH /boards/{boardId}/tasks/{taskId}/move` for moving tasks across columns and positions.
- `API-006`: Task move operations are atomic and do not expose partial-move states.
