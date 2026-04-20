# Todo Kanban Feature Plan

## Goal

Build a Todo app with a Kanban-style board made of:

- Boards
- Columns (lists)
- Todos (cards)

The backend remains the source of truth, and clients (CLI + macOS) use generated API clients from the OpenAPI contract.

## Delivery Order

Before Kanban feature work, first rebuild the existing CLI into a TUI.

Reason:

- Faster iteration loop for board/column/todo workflows.
- Reusable interaction patterns for macOS UX decisions.
- Better developer/operator usability during backend development.

## Product Scope

### MVP

1. Authenticated user can create one board.
2. User can create, rename, reorder, and delete columns.
3. User can create, edit, move, reorder, and delete todos inside columns.
4. Board updates persist and reload correctly.
5. Basic optimistic UI for drag-and-drop with rollback on failure.

### Post-MVP

- Multiple boards per user.
- Due dates, labels, priorities.
- Search/filter.
- Real-time collaboration.
- Activity history/audit log.

## Domain Model

- `Board`
  - `id`, `ownerUserId`, `title`, `createdAt`, `updatedAt`
- `Column`
  - `id`, `boardId`, `title`, `position`, `createdAt`, `updatedAt`
- `Todo`
  - `id`, `boardId`, `columnId`, `title`, `description`, `position`, `status`, `createdAt`, `updatedAt`

Position fields define order inside board/column.

## Backend Features

### API Endpoints (planned)

- `GET /boards` - list user boards
- `POST /boards` - create board
- `GET /boards/{boardId}` - get board with columns + todos
- `PATCH /boards/{boardId}` - update board title
- `DELETE /boards/{boardId}` - delete board

- `POST /boards/{boardId}/columns` - create column
- `PATCH /boards/{boardId}/columns/{columnId}` - rename column
- `PATCH /boards/{boardId}/columns/reorder` - reorder columns
- `DELETE /boards/{boardId}/columns/{columnId}` - delete column

- `POST /boards/{boardId}/todos` - create todo
- `PATCH /boards/{boardId}/todos/{todoId}` - edit todo
- `PATCH /boards/{boardId}/todos/{todoId}/move` - move todo across columns
- `PATCH /boards/{boardId}/todos/reorder` - reorder todos in a column
- `DELETE /boards/{boardId}/todos/{todoId}` - delete todo

### API Contract Draft (reorder/move)

Use dense integer positions (`0..n-1`) and return ordered lists sorted by `position`.

All mutation responses include an incrementing `boardVersion` for optimistic concurrency.
Clients SHOULD send `expectedBoardVersion`; server returns `409` if stale.

```yaml
components:
  schemas:
    Column:
      type: object
      additionalProperties: false
      required: [id, boardId, title, position, createdAt, updatedAt]
      properties:
        id: { type: string, format: uuid }
        boardId: { type: string, format: uuid }
        title: { type: string, minLength: 1, maxLength: 120 }
        position: { type: integer, minimum: 0 }
        createdAt: { type: string, format: date-time }
        updatedAt: { type: string, format: date-time }

    Todo:
      type: object
      additionalProperties: false
      required: [id, boardId, columnId, title, description, position, createdAt, updatedAt]
      properties:
        id: { type: string, format: uuid }
        boardId: { type: string, format: uuid }
        columnId: { type: string, format: uuid }
        title: { type: string, minLength: 1, maxLength: 200 }
        description: { type: string, maxLength: 4000 }
        position: { type: integer, minimum: 0 }
        createdAt: { type: string, format: date-time }
        updatedAt: { type: string, format: date-time }

    BoardVersionedMutationResult:
      type: object
      additionalProperties: false
      required: [boardId, boardVersion]
      properties:
        boardId: { type: string, format: uuid }
        boardVersion: { type: integer, minimum: 1 }

    ReorderColumnsRequest:
      type: object
      additionalProperties: false
      required: [columnIds]
      properties:
        columnIds:
          type: array
          minItems: 1
          items: { type: string, format: uuid }
          uniqueItems: true
          description: Full ordered set of column ids for the board.
        expectedBoardVersion:
          type: integer
          minimum: 1

    ReorderColumnsResponse:
      allOf:
        - $ref: '#/components/schemas/BoardVersionedMutationResult'
        - type: object
          required: [columns]
          properties:
            columns:
              type: array
              items: { $ref: '#/components/schemas/Column' }

    MoveTodoRequest:
      type: object
      additionalProperties: false
      required: [toColumnId, toPosition]
      properties:
        toColumnId: { type: string, format: uuid }
        toPosition: { type: integer, minimum: 0 }
        expectedBoardVersion:
          type: integer
          minimum: 1

    MoveTodoResponse:
      allOf:
        - $ref: '#/components/schemas/BoardVersionedMutationResult'
        - type: object
          required: [movedTodo, sourceColumnTodos, destinationColumnTodos]
          properties:
            movedTodo:
              $ref: '#/components/schemas/Todo'
            sourceColumnTodos:
              type: array
              items: { $ref: '#/components/schemas/Todo' }
            destinationColumnTodos:
              type: array
              items: { $ref: '#/components/schemas/Todo' }

    ReorderTodosRequest:
      type: object
      additionalProperties: false
      required: [columnId, todoIds]
      properties:
        columnId: { type: string, format: uuid }
        todoIds:
          type: array
          minItems: 0
          items: { type: string, format: uuid }
          uniqueItems: true
          description: Full ordered set of todo ids currently in the column.
        expectedBoardVersion:
          type: integer
          minimum: 1

    ReorderTodosResponse:
      allOf:
        - $ref: '#/components/schemas/BoardVersionedMutationResult'
        - type: object
          required: [columnId, todos]
          properties:
            columnId: { type: string, format: uuid }
            todos:
              type: array
              items: { $ref: '#/components/schemas/Todo' }

paths:
  /boards/{boardId}/columns/reorder:
    patch:
      summary: Reorder columns in a board
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/ReorderColumnsRequest' }
      responses:
        '200':
          description: Updated column order
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ReorderColumnsResponse' }
        '409':
          description: Version conflict (stale expectedBoardVersion)

  /boards/{boardId}/todos/{todoId}/move:
    patch:
      summary: Move todo across columns (or within same column)
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/MoveTodoRequest' }
      responses:
        '200':
          description: Updated source/destination orders
          content:
            application/json:
              schema: { $ref: '#/components/schemas/MoveTodoResponse' }
        '409':
          description: Version conflict (stale expectedBoardVersion)

  /boards/{boardId}/todos/reorder:
    patch:
      summary: Reorder todos in one column
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/ReorderTodosRequest' }
      responses:
        '200':
          description: Updated todo order
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ReorderTodosResponse' }
        '409':
          description: Version conflict (stale expectedBoardVersion)
```

Validation/error expectations:

- `400` invalid payload (duplicate IDs, missing IDs, invalid positions).
- `403` board exists but user is not owner.
- `404` board/column/todo not found or does not belong to board.
- `409` expected version mismatch.

### Backend Rules

- Enforce board ownership at all endpoints.
- Position updates must be atomic (transaction).
- Validate IDs belong to the same board when moving todos.
- Return deterministic ordering by `position`.

## Storage Architecture (Appwrite-first, SQLite-ready)

Use storage-agnostic repository interfaces in backend domain code so handlers and API contracts stay unchanged when replacing storage.

### Repository Ports (domain boundary)

- `BoardRepository`
  - `ListBoardsByOwner(ctx, ownerUserID)`
  - `GetBoard(ctx, ownerUserID, boardID)`
  - `CreateBoard(ctx, input)`
  - `UpdateBoardTitle(ctx, ownerUserID, boardID, title, expectedBoardVersion)`
  - `DeleteBoard(ctx, ownerUserID, boardID, expectedBoardVersion)`
- `ColumnRepository`
  - `CreateColumn(ctx, ownerUserID, boardID, title, expectedBoardVersion)`
  - `RenameColumn(ctx, ownerUserID, boardID, columnID, title, expectedBoardVersion)`
  - `ReorderColumns(ctx, ownerUserID, boardID, orderedColumnIDs, expectedBoardVersion)`
  - `DeleteColumn(ctx, ownerUserID, boardID, columnID, expectedBoardVersion)`
- `TodoRepository`
  - `CreateTodo(ctx, ownerUserID, boardID, columnID, title, description, expectedBoardVersion)`
  - `UpdateTodo(ctx, ownerUserID, boardID, todoID, title, description, expectedBoardVersion)`
  - `MoveTodo(ctx, ownerUserID, boardID, todoID, toColumnID, toPosition, expectedBoardVersion)`
  - `ReorderTodos(ctx, ownerUserID, boardID, columnID, orderedTodoIDs, expectedBoardVersion)`
  - `DeleteTodo(ctx, ownerUserID, boardID, todoID, expectedBoardVersion)`

### Adapter implementations

- `AppwriteRepository` (initial implementation)
- `SQLiteRepository` (future implementation)

Both adapters must satisfy the same repository interfaces and behavior.

### Data mapping rule

- Keep domain structs (`Board`, `Column`, `Todo`) independent from storage schemas.
- Keep Appwrite row models and SQLite row models in adapter packages.
- Map transport <-> domain <-> storage at boundaries only.

### Appwrite physical model (initial)

- Database: `todo`
- Tables:
  - `boards`: `id`, `ownerUserId`, `title`, `boardVersion`, `createdAt`, `updatedAt`
  - `columns`: `id`, `boardId`, `ownerUserId`, `title`, `position`, `createdAt`, `updatedAt`
  - `todos`: `id`, `boardId`, `columnId`, `ownerUserId`, `title`, `description`, `position`, `createdAt`, `updatedAt`
- Indexes:
  - `boards(ownerUserId, updatedAt)`
  - `columns(boardId, position)`
  - `todos(boardId, columnId, position)`

### Concurrency, ownership, and migration rules

- `boardVersion` is incremented on every mutation.
- Mutations accept `expectedBoardVersion`; stale versions return `409`.
- Backend is the primary ownership enforcement point (`ownerUserId` + board scope).
- Appwrite permissions are optional defense-in-depth, not the only authorization layer.
- SQLite adapter is complete only when it passes the same repository test suite as Appwrite.

## macOS App Features

### Board UI

- Board header (title + quick actions).
- Horizontal column lane.
- Column card with title and todo count.
- Todo card with title and short description.

### Interactions

- Drag todo within column and across columns.
- Add/edit/delete todo from modal or inline sheet.
- Add/rename/delete column.
- Empty states for new board/column.

### State + Data

- Use generated `TodoAPIClient` wrappers only.
- Keep view-model boundaries (`AuthAPI` pattern) for board domain too.
- Retry/error banners for failed mutations.

## CLI Features

### TUI-first phase (do this first)

- Rebuild current CLI commands into a terminal UI (TUI) shell.
- Keep backend API usage unchanged (generated client + backend-only auth model).
- Provide views for auth/session status, board list, board detail, and quick todo actions.
- Support keyboard-first navigation and clear loading/error states.

### Board command parity

- Board list/create/select.
- Column list/add/rename/delete/reorder.
- Todo add/edit/move/delete.
- Text-first table/compact board output.

## Milestones

1. **CLI -> TUI foundation**
   - Build TUI app shell and state management.
   - Port auth/session + current CLI flows into TUI.
   - Ensure `make test` coverage remains green.
2. **Contracts + Repository Ports + Appwrite Adapter**
   - Finalize board/column/todo schemas and endpoints.
   - Implement repository interfaces and shared adapter test suite.
   - Implement Appwrite adapter mappings, indexes, and invariants.
   - Wire HTTP handlers to repository ports.
   - Generate clients and add tests.
3. **macOS Board Read Path**
   - Fetch and render board with columns/todos.
4. **macOS Mutations + DnD**
   - Implement create/edit/delete/move/reorder flows.
5. **TUI Board Workflows**
   - Add end-to-end board/column/todo flows in the TUI.
6. **Polish + Hardening**
   - Error handling, loading states, test coverage, docs.

## Acceptance Criteria

- User can fully manage a board (columns + todos) on macOS.
- User can manage the same data via TUI (CLI replacement).
- Ordering is stable and consistent across clients.
- Appwrite and SQLite adapters satisfy the same repository contract.
- `make generate`, `make test`, and `make test-macos-unit` pass.
