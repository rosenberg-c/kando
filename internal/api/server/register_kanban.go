package server

import (
	"context"
	"errors"
	"net/http"

	"github.com/danielgtaylor/huma/v2"

	"go_macos_todo/internal/api/contracts"
	"go_macos_todo/internal/auth"
	"go_macos_todo/internal/kanban"
)

type authHeaderInput struct {
	Authorization string `header:"Authorization"`
}

type listBoardsOutput struct {
	Body []contracts.Board
}

type createBoardInput struct {
	Authorization string `header:"Authorization"`
	Body          contracts.CreateBoardRequest
}

type boardOutput struct {
	Body contracts.Board
}

type boardPathInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
}

type updateBoardInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	Body          contracts.UpdateBoardRequest
}

type boardDetailsOutput struct {
	Body contracts.BoardDetailsResponse
}

type createColumnInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	Body          contracts.CreateColumnRequest
}

type columnOutput struct {
	Body contracts.Column
}

type updateColumnInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	ColumnID      string `path:"columnId"`
	Body          contracts.UpdateColumnRequest
}

type columnPathInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	ColumnID      string `path:"columnId"`
}

type createTodoInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	Body          contracts.CreateTodoRequest
}

type updateTodoInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	TodoID        string `path:"todoId"`
	Body          contracts.UpdateTodoRequest
}

type todoPathInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	TodoID        string `path:"todoId"`
}

type todoOutput struct {
	Body contracts.Todo
}

func registerKanban(api huma.API, deps Dependencies) {
	huma.Register(api, huma.Operation{
		OperationID: "listBoards",
		Method:      http.MethodGet,
		Path:        "/boards",
		Summary:     "List boards for the authenticated user",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *authHeaderInput) (*listBoardsOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		boards, err := repo.ListBoardsByOwner(ctx, identity.UserID)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		out := make([]contracts.Board, 0, len(boards))
		for _, board := range boards {
			out = append(out, toContractBoard(board))
		}
		return &listBoardsOutput{Body: out}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "createBoard",
		Method:      http.MethodPost,
		Path:        "/boards",
		Summary:     "Create a board",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *createBoardInput) (*boardOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		board, err := repo.CreateBoardIfAbsent(ctx, identity.UserID, input.Body.Title)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &boardOutput{Body: toContractBoard(board)}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getBoard",
		Method:      http.MethodGet,
		Path:        "/boards/{boardId}",
		Summary:     "Get board with columns and todos",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *boardPathInput) (*boardDetailsOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		details, err := repo.GetBoard(ctx, identity.UserID, input.BoardID)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		columns := make([]contracts.Column, 0, len(details.Columns))
		for _, column := range details.Columns {
			columns = append(columns, toContractColumn(column))
		}

		todos := make([]contracts.Todo, 0, len(details.Todos))
		for _, todo := range details.Todos {
			todos = append(todos, toContractTodo(todo))
		}

		return &boardDetailsOutput{Body: contracts.BoardDetailsResponse{
			Board:   toContractBoard(details.Board),
			Columns: columns,
			Todos:   todos,
		}}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "updateBoard",
		Method:      http.MethodPatch,
		Path:        "/boards/{boardId}",
		Summary:     "Update board title",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *updateBoardInput) (*boardOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		board, err := repo.UpdateBoardTitle(ctx, identity.UserID, input.BoardID, input.Body.Title)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &boardOutput{Body: toContractBoard(board)}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID:   "deleteBoard",
		Method:        http.MethodDelete,
		Path:          "/boards/{boardId}",
		Summary:       "Delete a board",
		DefaultStatus: http.StatusNoContent,
		Security:      []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *boardPathInput) (*struct{}, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		if err := repo.DeleteBoard(ctx, identity.UserID, input.BoardID); err != nil {
			return nil, mapKanbanError(err)
		}

		return nil, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "createColumn",
		Method:      http.MethodPost,
		Path:        "/boards/{boardId}/columns",
		Summary:     "Create a column",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *createColumnInput) (*columnOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		column, _, err := repo.CreateColumn(ctx, identity.UserID, input.BoardID, input.Body.Title)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &columnOutput{Body: toContractColumn(column)}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "updateColumn",
		Method:      http.MethodPatch,
		Path:        "/boards/{boardId}/columns/{columnId}",
		Summary:     "Update column title",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *updateColumnInput) (*columnOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		column, _, err := repo.UpdateColumnTitle(ctx, identity.UserID, input.BoardID, input.ColumnID, input.Body.Title)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &columnOutput{Body: toContractColumn(column)}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID:   "deleteColumn",
		Method:        http.MethodDelete,
		Path:          "/boards/{boardId}/columns/{columnId}",
		Summary:       "Delete a column",
		DefaultStatus: http.StatusNoContent,
		Security:      []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *columnPathInput) (*struct{}, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		if _, err := repo.DeleteColumn(ctx, identity.UserID, input.BoardID, input.ColumnID); err != nil {
			return nil, mapKanbanError(err)
		}

		return nil, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "createTodo",
		Method:      http.MethodPost,
		Path:        "/boards/{boardId}/todos",
		Summary:     "Create a todo",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *createTodoInput) (*todoOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		todo, _, err := repo.CreateTodo(ctx, identity.UserID, input.BoardID, input.Body.ColumnID, input.Body.Title, input.Body.Description)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &todoOutput{Body: toContractTodo(todo)}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "updateTodo",
		Method:      http.MethodPatch,
		Path:        "/boards/{boardId}/todos/{todoId}",
		Summary:     "Update a todo",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *updateTodoInput) (*todoOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		todo, _, err := repo.UpdateTodo(ctx, identity.UserID, input.BoardID, input.TodoID, input.Body.Title, input.Body.Description)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &todoOutput{Body: toContractTodo(todo)}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID:   "deleteTodo",
		Method:        http.MethodDelete,
		Path:          "/boards/{boardId}/todos/{todoId}",
		Summary:       "Delete a todo",
		DefaultStatus: http.StatusNoContent,
		Security:      []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *todoPathInput) (*struct{}, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		if _, err := repo.DeleteTodo(ctx, identity.UserID, input.BoardID, input.TodoID); err != nil {
			return nil, mapKanbanError(err)
		}

		return nil, nil
	})
}

func requireKanban(ctx context.Context, deps Dependencies, authorization string) (kanban.Repository, auth.Identity, error) {
	if deps.KanbanRepo == nil {
		return nil, auth.Identity{}, huma.Error500InternalServerError("kanban dependencies are not configured")
	}
	if deps.Verifier == nil {
		return nil, auth.Identity{}, huma.Error500InternalServerError("auth dependencies are not configured")
	}

	token, ok := bearerToken(authorization)
	if !ok {
		return nil, auth.Identity{}, huma.Error401Unauthorized("missing bearer token")
	}

	identity, err := deps.Verifier.VerifyJWT(ctx, token)
	if err != nil {
		return nil, auth.Identity{}, huma.Error401Unauthorized("unauthorized")
	}

	return deps.KanbanRepo, identity, nil
}

func mapKanbanError(err error) error {
	switch {
	case errors.Is(err, kanban.ErrInvalidInput):
		return huma.Error400BadRequest(err.Error())
	case errors.Is(err, kanban.ErrForbidden):
		return huma.Error403Forbidden("forbidden")
	case errors.Is(err, kanban.ErrNotFound):
		return huma.Error404NotFound("not found")
	case errors.Is(err, kanban.ErrConflict):
		return huma.Error409Conflict("conflict")
	default:
		return huma.Error500InternalServerError("internal error")
	}
}

func toContractBoard(board kanban.Board) contracts.Board {
	return contracts.Board{
		ID:           board.ID,
		OwnerUserID:  board.OwnerUserID,
		Title:        board.Title,
		BoardVersion: board.BoardVersion,
		CreatedAt:    board.CreatedAt,
		UpdatedAt:    board.UpdatedAt,
	}
}

func toContractColumn(column kanban.Column) contracts.Column {
	return contracts.Column{
		ID:        column.ID,
		BoardID:   column.BoardID,
		Title:     column.Title,
		Position:  column.Position,
		CreatedAt: column.CreatedAt,
		UpdatedAt: column.UpdatedAt,
	}
}

func toContractTodo(todo kanban.Todo) contracts.Todo {
	return contracts.Todo{
		ID:          todo.ID,
		BoardID:     todo.BoardID,
		ColumnID:    todo.ColumnID,
		Title:       todo.Title,
		Description: todo.Description,
		Position:    todo.Position,
		CreatedAt:   todo.CreatedAt,
		UpdatedAt:   todo.UpdatedAt,
	}
}
