# Public API Contract

- `PUBLIC-001`: `/hello` responds with HTTP 200 and `text/plain` content type.
- `PUBLIC-002`: OpenAPI contract defines `/hello` response as `text/plain`.
- `PUBLIC-003`: OpenAPI contract defines all kanban board/column/task paths and methods.
- `PUBLIC-004`: OpenAPI contract defines `PUT /boards/{boardId}/tasks/order` with request field `columns[]` (`columnId`, `taskIds`) plus response/error schemas.
- `PUBLIC-005`: OpenAPI contract defines `PUT /boards/{boardId}/columns/order` with request field `columnIds` (full ordered list) and response/error schemas.
