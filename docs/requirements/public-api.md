# Public API Contract

- `PUBLIC-001`: `/hello` responds with HTTP 200 and `text/plain` content type.
- `PUBLIC-002`: OpenAPI contract defines `/hello` response as `text/plain`.
- `PUBLIC-003`: OpenAPI contract defines all kanban board/column/task paths and methods.
- `PUBLIC-004`: OpenAPI contract defines `PUT /boards/{boardId}/tasks/order` with request field `columns[]` (`columnId`, `taskIds`) plus response/error schemas.
- `PUBLIC-005`: OpenAPI contract defines `PUT /boards/{boardId}/columns/order` with request field `columnIds` (full ordered list) and response/error schemas.
- `PUBLIC-006`: OpenAPI contract defines `GET /boards/{boardId}/tasks/export` with versioned task transfer payload response schema.
- `PUBLIC-007`: OpenAPI contract defines `POST /boards/{boardId}/tasks/import` with versioned task transfer payload request schema and import summary response schema.
