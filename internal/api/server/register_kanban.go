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

type reorderColumnsInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	Body          contracts.ReorderColumnsRequest
}

type columnsOutput struct {
	Body []contracts.Column
}

type columnPathInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	ColumnID      string `path:"columnId"`
}

type createTaskInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	Body          contracts.CreateTaskRequest
}

type updateTaskInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	TaskID        string `path:"taskId"`
	Body          contracts.UpdateTaskRequest
}

type reorderTasksInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	Body          contracts.ReorderTasksRequest
}

type taskPathInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	TaskID        string `path:"taskId"`
}

type taskOutput struct {
	Body contracts.Task
}

type tasksOutput struct {
	Body []contracts.Task
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
		Summary:     "Get board with columns and tasks",
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

		tasks := make([]contracts.Task, 0, len(details.Tasks))
		for _, task := range details.Tasks {
			tasks = append(tasks, toContractTask(task))
		}

		return &boardDetailsOutput{Body: contracts.BoardDetailsResponse{
			Board:   toContractBoard(details.Board),
			Columns: columns,
			Tasks:   tasks,
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
		OperationID: "reorderColumns",
		Method:      http.MethodPut,
		Path:        "/boards/{boardId}/columns/order",
		Summary:     "Replace board column order",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *reorderColumnsInput) (*columnsOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		if _, err := repo.ReorderColumns(ctx, identity.UserID, input.BoardID, input.Body.ColumnIDs); err != nil {
			return nil, mapKanbanError(err)
		}

		details, err := repo.GetBoard(ctx, identity.UserID, input.BoardID)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		columns := make([]contracts.Column, 0, len(details.Columns))
		for _, column := range details.Columns {
			columns = append(columns, toContractColumn(column))
		}

		return &columnsOutput{Body: columns}, nil
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
		OperationID: "createTask",
		Method:      http.MethodPost,
		Path:        "/boards/{boardId}/tasks",
		Summary:     "Create a task",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *createTaskInput) (*taskOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		task, _, err := repo.CreateTask(ctx, identity.UserID, input.BoardID, input.Body.ColumnID, input.Body.Title, input.Body.Description)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &taskOutput{Body: toContractTask(task)}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "updateTask",
		Method:      http.MethodPatch,
		Path:        "/boards/{boardId}/tasks/{taskId}",
		Summary:     "Update a task",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *updateTaskInput) (*taskOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		task, _, err := repo.UpdateTask(ctx, identity.UserID, input.BoardID, input.TaskID, input.Body.Title, input.Body.Description)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &taskOutput{Body: toContractTask(task)}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "reorderTasks",
		Method:      http.MethodPut,
		Path:        "/boards/{boardId}/tasks/order",
		Summary:     "Replace board task order",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *reorderTasksInput) (*tasksOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		orders := make([]kanban.TaskColumnOrder, 0, len(input.Body.Columns))
		for _, column := range input.Body.Columns {
			orders = append(orders, kanban.TaskColumnOrder{ColumnID: column.ColumnID, TaskIDs: column.TaskIDs})
		}

		if _, err := repo.ReorderTasks(ctx, identity.UserID, input.BoardID, orders); err != nil {
			return nil, mapKanbanError(err)
		}

		details, err := repo.GetBoard(ctx, identity.UserID, input.BoardID)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		tasks := make([]contracts.Task, 0, len(details.Tasks))
		for _, task := range details.Tasks {
			tasks = append(tasks, toContractTask(task))
		}

		return &tasksOutput{Body: tasks}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID:   "deleteTask",
		Method:        http.MethodDelete,
		Path:          "/boards/{boardId}/tasks/{taskId}",
		Summary:       "Delete a task",
		DefaultStatus: http.StatusNoContent,
		Security:      []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *taskPathInput) (*struct{}, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		if _, err := repo.DeleteTask(ctx, identity.UserID, input.BoardID, input.TaskID); err != nil {
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
	case errors.Is(err, kanban.ErrNotImplemented):
		return huma.Error501NotImplemented("not implemented")
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

func toContractTask(task kanban.Task) contracts.Task {
	return contracts.Task{
		ID:          task.ID,
		BoardID:     task.BoardID,
		ColumnID:    task.ColumnID,
		Title:       task.Title,
		Description: task.Description,
		Position:    task.Position,
		CreatedAt:   task.CreatedAt,
		UpdatedAt:   task.UpdatedAt,
	}
}
