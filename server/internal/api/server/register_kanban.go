package server

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"go_macos_todo/server/internal/api/contracts"
	"go_macos_todo/server/internal/auth"
	"go_macos_todo/server/internal/kanban"
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

type restoreBoardInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	Body          contracts.RestoreBoardRequest
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

type archiveColumnTasksOutput struct {
	Body contracts.ArchiveColumnTasksResponse
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

type taskBatchMutationInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	Body          contracts.TaskBatchMutationRequest
}

type taskPathInput struct {
	Authorization string `header:"Authorization"`
	BoardID       string `path:"boardId"`
	TaskID        string `path:"taskId"`
}

type exportTasksBundleInput struct {
	Authorization string `header:"Authorization"`
	Body          contracts.TaskExportBundleRequest
}

type exportTasksBundleOutput struct {
	Body contracts.TaskExportBundle
}

type importTasksBundleInput struct {
	Authorization string `header:"Authorization"`
	Body          contracts.TaskImportBundleRequest
}

type importTasksBundleOutput struct {
	Body contracts.TaskImportBundleResponse
}

type taskOutput struct {
	Body contracts.Task
}

type tasksOutput struct {
	Body []contracts.Task
}

type archivedTasksOutput struct {
	Body []contracts.ArchivedTask
}

const (
	taskExportFormatVersionV1       = 1
	taskExportFormatVersionV2       = 2
	taskExportBundleFormatVersionV2 = 2
	taskExportBundleFormatVersionV3 = 3
)

type archiveRepository interface {
	kanban.Repository
	kanban.ArchiveCapableRepository
}

type taskArchiveRepository interface {
	kanban.Repository
	kanban.TaskArchiveCapableRepository
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
		OperationID: "listArchivedBoards",
		Method:      http.MethodGet,
		Path:        "/boards/archived",
		Summary:     "List archived boards for the authenticated user",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *authHeaderInput) (*listBoardsOutput, error) {
		repo, identity, err := requireArchiveKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		boards, err := repo.ListArchivedBoardsByOwner(ctx, identity.UserID)
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

		board, err := repo.CreateBoard(ctx, identity.UserID, input.Body.Title)
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
		OperationID: "archiveBoard",
		Method:      http.MethodPost,
		Path:        "/boards/{boardId}/archive",
		Summary:     "Archive a board",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *boardPathInput) (*boardOutput, error) {
		repo, identity, err := requireArchiveKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		board, err := repo.ArchiveBoard(ctx, identity.UserID, input.BoardID)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &boardOutput{Body: toContractBoard(board)}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "restoreBoard",
		Method:      http.MethodPost,
		Path:        "/boards/{boardId}/restore",
		Summary:     "Restore an archived board",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *restoreBoardInput) (*boardOutput, error) {
		repo, identity, err := requireArchiveKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		titleMode, err := kanban.NormalizeRestoreBoardTitleMode(input.Body.TitleMode)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		board, err := repo.RestoreBoard(ctx, identity.UserID, input.BoardID, titleMode)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &boardOutput{Body: toContractBoard(board)}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID:   "deleteArchivedBoard",
		Method:        http.MethodDelete,
		Path:          "/boards/{boardId}/archive",
		Summary:       "Permanently delete an archived board",
		DefaultStatus: http.StatusNoContent,
		Security:      []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *boardPathInput) (*struct{}, error) {
		repo, identity, err := requireArchiveKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		if err := repo.DeleteArchivedBoard(ctx, identity.UserID, input.BoardID); err != nil {
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
		OperationID: "archiveTasksInColumn",
		Method:      http.MethodPost,
		Path:        "/boards/{boardId}/columns/{columnId}/archive-tasks",
		Summary:     "Archive all active tasks in a column",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *columnPathInput) (*archiveColumnTasksOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		taskArchiveRepo, ok := repo.(taskArchiveRepository)
		if !ok {
			return nil, mapKanbanError(kanban.ErrNotImplemented)
		}

		result, _, err := taskArchiveRepo.ArchiveTasksInColumn(ctx, identity.UserID, input.BoardID, input.ColumnID)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &archiveColumnTasksOutput{Body: contracts.ArchiveColumnTasksResponse{
			ArchivedTaskCount: result.ArchivedTaskCount,
			ArchivedAt:        result.ArchivedAt,
		}}, nil
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
		OperationID: "listArchivedTasksByBoard",
		Method:      http.MethodGet,
		Path:        "/boards/{boardId}/tasks/archived",
		Summary:     "List archived tasks for a board",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *boardPathInput) (*archivedTasksOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		taskArchiveRepo, ok := repo.(taskArchiveRepository)
		if !ok {
			return nil, mapKanbanError(kanban.ErrNotImplemented)
		}

		archivedTasks, err := taskArchiveRepo.ListArchivedTasksByBoard(ctx, identity.UserID, input.BoardID)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		out := make([]contracts.ArchivedTask, 0, len(archivedTasks))
		for _, task := range archivedTasks {
			out = append(out, toContractArchivedTask(task))
		}

		return &archivedTasksOutput{Body: out}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "restoreArchivedTask",
		Method:      http.MethodPost,
		Path:        "/boards/{boardId}/tasks/{taskId}/restore",
		Summary:     "Restore an archived task",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *taskPathInput) (*taskOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		taskArchiveRepo, ok := repo.(taskArchiveRepository)
		if !ok {
			return nil, mapKanbanError(kanban.ErrNotImplemented)
		}

		task, _, err := taskArchiveRepo.RestoreArchivedTask(ctx, identity.UserID, input.BoardID, input.TaskID)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &taskOutput{Body: toContractTask(task)}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID:   "deleteArchivedTask",
		Method:        http.MethodDelete,
		Path:          "/boards/{boardId}/tasks/{taskId}/archived",
		Summary:       "Permanently delete an archived task",
		DefaultStatus: http.StatusNoContent,
		Security:      []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *taskPathInput) (*struct{}, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		taskArchiveRepo, ok := repo.(taskArchiveRepository)
		if !ok {
			return nil, mapKanbanError(kanban.ErrNotImplemented)
		}

		if _, err := taskArchiveRepo.DeleteArchivedTask(ctx, identity.UserID, input.BoardID, input.TaskID); err != nil {
			return nil, mapKanbanError(err)
		}

		return nil, nil
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
		OperationID: "applyTaskBatchMutation",
		Method:      http.MethodPost,
		Path:        "/boards/{boardId}/tasks/actions",
		Summary:     "Apply list-based task batch action",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *taskBatchMutationInput) (*tasksOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		service := kanban.NewService(repo)
		if _, err := service.ApplyTaskBatchMutation(ctx, identity.UserID, input.BoardID, kanban.TaskBatchMutationRequest{
			Action:  kanban.TaskBatchAction(input.Body.Action),
			TaskIDs: input.Body.TaskIDs,
		}); err != nil {
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
		OperationID: "exportTasksBundle",
		Method:      http.MethodPost,
		Path:        "/boards/tasks/export",
		Summary:     "Export selected boards as a multi-board task bundle",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *exportTasksBundleInput) (*exportTasksBundleOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		bundle, err := exportTasksBundle(ctx, repo, identity.UserID, input.Body.BoardIDs, time.Now().UTC())
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &exportTasksBundleOutput{Body: bundle}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "importTasksBundle",
		Method:      http.MethodPost,
		Path:        "/boards/tasks/import",
		Summary:     "Import selected snapshots from a multi-board task bundle",
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *importTasksBundleInput) (*importTasksBundleOutput, error) {
		repo, identity, err := requireKanban(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		response, err := importTasksBundle(ctx, repo, identity.UserID, input.Body)
		if err != nil {
			return nil, mapKanbanError(err)
		}

		return &importTasksBundleOutput{Body: response}, nil
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

func requireArchiveKanban(ctx context.Context, deps Dependencies, authorization string) (archiveRepository, auth.Identity, error) {
	repo, identity, err := requireKanban(ctx, deps, authorization)
	if err != nil {
		return nil, auth.Identity{}, err
	}

	archiveRepo, ok := repo.(archiveRepository)
	if !ok {
		return nil, auth.Identity{}, mapKanbanError(kanban.ErrNotImplemented)
	}

	return archiveRepo, identity, nil
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
		return huma.Error409Conflict(kanban.ConflictDetail(err))
	case errors.Is(err, kanban.ErrNotImplemented):
		return huma.Error501NotImplemented("not implemented")
	default:
		return huma.Error500InternalServerError("internal error")
	}
}

func toContractBoard(board kanban.Board) contracts.Board {
	var archivedOriginalTitle *string
	if strings.TrimSpace(board.ArchivedOriginalTitle) != "" {
		title := board.ArchivedOriginalTitle
		archivedOriginalTitle = &title
	}

	return contracts.Board{
		ID:                    board.ID,
		OwnerUserID:           board.OwnerUserID,
		Title:                 board.Title,
		ArchivedOriginalTitle: archivedOriginalTitle,
		BoardVersion:          board.BoardVersion,
		CreatedAt:             board.CreatedAt,
		UpdatedAt:             board.UpdatedAt,
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

func toContractArchivedTask(task kanban.Task) contracts.ArchivedTask {
	return contracts.ArchivedTask{
		ID:          task.ID,
		BoardID:     task.BoardID,
		ColumnID:    task.ColumnID,
		Title:       task.Title,
		Description: task.Description,
		Position:    task.Position,
		ArchivedAt:  task.ArchivedAt,
		CreatedAt:   task.CreatedAt,
		UpdatedAt:   task.UpdatedAt,
	}
}

func buildTaskExportPayload(details kanban.BoardDetails, exportedAt time.Time) contracts.TaskExportPayload {
	columns := append([]kanban.Column(nil), details.Columns...)
	sort.Slice(columns, func(i, j int) bool {
		return columns[i].Position < columns[j].Position
	})

	activeTasksByColumnID := make(map[string][]kanban.Task)
	archivedTasksByColumnID := make(map[string][]kanban.Task)
	for _, task := range details.Tasks {
		if task.IsArchived {
			archivedTasksByColumnID[task.ColumnID] = append(archivedTasksByColumnID[task.ColumnID], task)
			continue
		}
		activeTasksByColumnID[task.ColumnID] = append(activeTasksByColumnID[task.ColumnID], task)
	}

	exportColumns := make([]contracts.TaskExportColumn, 0, len(columns))
	for _, column := range columns {
		activeTasks := activeTasksByColumnID[column.ID]
		sort.Slice(activeTasks, func(i, j int) bool {
			return activeTasks[i].Position < activeTasks[j].Position
		})

		exportTasks := make([]contracts.TaskExportTask, 0, len(activeTasks))
		for _, task := range activeTasks {
			exportTasks = append(exportTasks, contracts.TaskExportTask{
				Title:       task.Title,
				Description: task.Description,
			})
		}

		archivedTasks := archivedTasksByColumnID[column.ID]
		sort.Slice(archivedTasks, func(i, j int) bool {
			if !archivedTasks[i].ArchivedAt.Equal(archivedTasks[j].ArchivedAt) {
				return archivedTasks[i].ArchivedAt.Before(archivedTasks[j].ArchivedAt)
			}
			if archivedTasks[i].Position != archivedTasks[j].Position {
				return archivedTasks[i].Position < archivedTasks[j].Position
			}
			return archivedTasks[i].ID < archivedTasks[j].ID
		})
		exportArchivedTasks := make([]contracts.TaskExportTask, 0, len(archivedTasks))
		for _, task := range archivedTasks {
			archivedAt := task.ArchivedAt.Format(time.RFC3339Nano)
			exportArchivedTasks = append(exportArchivedTasks, contracts.TaskExportTask{
				Title:       task.Title,
				Description: task.Description,
				ArchivedAt:  &archivedAt,
			})
		}

		exportColumns = append(exportColumns, contracts.TaskExportColumn{
			Title:         column.Title,
			Tasks:         exportTasks,
			ArchivedTasks: exportArchivedTasks,
		})
	}

	return contracts.TaskExportPayload{
		FormatVersion: taskExportFormatVersionV2,
		BoardTitle:    details.Board.Title,
		ExportedAt:    exportedAt.Format(time.RFC3339),
		Columns:       exportColumns,
	}
}

func exportTasksBundle(ctx context.Context, repo kanban.Repository, ownerUserID string, boardIDs []string, exportedAt time.Time) (contracts.TaskExportBundle, error) {
	selectedBoardIDs, err := normalizeUniqueNonEmptyIDs(boardIDs)
	if err != nil {
		return contracts.TaskExportBundle{}, err
	}

	snapshots := make([]contracts.TaskExportBundleBoard, 0, len(selectedBoardIDs))
	for _, boardID := range selectedBoardIDs {
		details, err := repo.GetBoard(ctx, ownerUserID, boardID)
		if err != nil {
			return contracts.TaskExportBundle{}, err
		}

		if archiveRepo, ok := repo.(interface {
			ListArchivedTasksByBoard(ctx context.Context, ownerUserID, boardID string) ([]kanban.Task, error)
		}); ok {
			archivedTasks, err := archiveRepo.ListArchivedTasksByBoard(ctx, ownerUserID, boardID)
			if err != nil {
				return contracts.TaskExportBundle{}, err
			}
			details.Tasks = append(details.Tasks, archivedTasks...)
		}

		snapshots = append(snapshots, contracts.TaskExportBundleBoard{
			SourceBoardID:    details.Board.ID,
			SourceBoardTitle: details.Board.Title,
			Payload:          buildTaskExportPayload(details, exportedAt),
		})
	}

	return contracts.TaskExportBundle{
		FormatVersion: taskExportBundleFormatVersionV3,
		ExportedAt:    exportedAt.Format(time.RFC3339),
		Boards:        snapshots,
	}, nil
}

func importTasksBundle(ctx context.Context, repo kanban.Repository, ownerUserID string, request contracts.TaskImportBundleRequest) (contracts.TaskImportBundleResponse, error) {
	if !isSupportedBundleFormatVersion(request.Bundle.FormatVersion) {
		return contracts.TaskImportBundleResponse{}, kanban.ErrInvalidInput
	}
	if len(request.Bundle.Boards) == 0 {
		return contracts.TaskImportBundleResponse{}, kanban.ErrInvalidInput
	}

	selectedSourceBoardIDs, err := normalizeUniqueNonEmptyIDs(request.SourceBoardIDs)
	if err != nil {
		return contracts.TaskImportBundleResponse{}, err
	}

	bundleBySourceID := make(map[string]contracts.TaskExportBundleBoard, len(request.Bundle.Boards))
	for _, snapshot := range request.Bundle.Boards {
		sourceID := strings.TrimSpace(snapshot.SourceBoardID)
		if sourceID == "" {
			return contracts.TaskImportBundleResponse{}, kanban.ErrInvalidInput
		}
		if _, err := uuid.Parse(sourceID); err != nil {
			return contracts.TaskImportBundleResponse{}, kanban.ErrInvalidInput
		}
		sourceTitle := strings.TrimSpace(snapshot.SourceBoardTitle)
		if sourceTitle == "" {
			return contracts.TaskImportBundleResponse{}, kanban.ErrInvalidInput
		}
		if !isSupportedPayloadFormatVersion(snapshot.Payload.FormatVersion) {
			return contracts.TaskImportBundleResponse{}, kanban.ErrInvalidInput
		}
		if _, exists := bundleBySourceID[sourceID]; exists {
			return contracts.TaskImportBundleResponse{}, kanban.ErrInvalidInput
		}
		normalizedSnapshot := snapshot
		normalizedSnapshot.SourceBoardID = sourceID
		normalizedSnapshot.SourceBoardTitle = sourceTitle
		bundleBySourceID[sourceID] = normalizedSnapshot
	}

	availableBoards, err := repo.ListBoardsByOwner(ctx, ownerUserID)
	if err != nil {
		return contracts.TaskImportBundleResponse{}, err
	}

	results := make([]contracts.TaskImportBundleBoardResult, 0, len(selectedSourceBoardIDs))
	totalCreatedColumns := 0
	totalImportedTasks := 0

	for _, sourceBoardID := range selectedSourceBoardIDs {
		snapshot, exists := bundleBySourceID[sourceBoardID]
		if !exists {
			return contracts.TaskImportBundleResponse{}, kanban.ErrInvalidInput
		}

		destinationBoardID, updatedBoards, err := resolveImportBundleDestinationBoard(ctx, repo, ownerUserID, availableBoards, snapshot)
		if err != nil {
			return contracts.TaskImportBundleResponse{}, err
		}
		availableBoards = updatedBoards

		result, err := importTasksAtomically(ctx, repo, ownerUserID, destinationBoardID, snapshot.Payload)
		if err != nil {
			return contracts.TaskImportBundleResponse{}, err
		}

		results = append(results, contracts.TaskImportBundleBoardResult{
			SourceBoardID:      snapshot.SourceBoardID,
			DestinationBoardID: destinationBoardID,
			CreatedColumnCount: result.CreatedColumnCount,
			ImportedTaskCount:  result.ImportedTaskCount,
		})
		totalCreatedColumns += result.CreatedColumnCount
		totalImportedTasks += result.ImportedTaskCount
	}

	return contracts.TaskImportBundleResponse{
		Results:                 results,
		TotalCreatedColumnCount: totalCreatedColumns,
		TotalImportedTaskCount:  totalImportedTasks,
	}, nil
}

func resolveImportBundleDestinationBoard(
	ctx context.Context,
	repo kanban.Repository,
	ownerUserID string,
	availableBoards []kanban.Board,
	snapshot contracts.TaskExportBundleBoard,
) (string, []kanban.Board, error) {
	for _, board := range availableBoards {
		if board.ID == snapshot.SourceBoardID {
			return board.ID, availableBoards, nil
		}
	}
	for _, board := range availableBoards {
		if board.Title == snapshot.SourceBoardTitle {
			return board.ID, availableBoards, nil
		}
	}

	createdBoard, err := repo.CreateBoard(ctx, ownerUserID, snapshot.SourceBoardTitle)
	if err != nil {
		return "", nil, err
	}

	updatedBoards := append([]kanban.Board{createdBoard}, availableBoards...)
	return createdBoard.ID, updatedBoards, nil
}

func normalizeUniqueNonEmptyIDs(ids []string) ([]string, error) {
	if len(ids) == 0 {
		return nil, kanban.ErrInvalidInput
	}

	normalized := make([]string, 0, len(ids))
	seen := make(map[string]struct{}, len(ids))
	for _, value := range ids {
		id := strings.TrimSpace(value)
		if id == "" {
			return nil, kanban.ErrInvalidInput
		}
		if _, err := uuid.Parse(id); err != nil {
			return nil, kanban.ErrInvalidInput
		}
		if _, exists := seen[id]; exists {
			return nil, kanban.ErrInvalidInput
		}
		seen[id] = struct{}{}
		normalized = append(normalized, id)
	}

	return normalized, nil
}

func importTasksAtomically(ctx context.Context, repo kanban.Repository, ownerUserID, boardID string, payload contracts.TaskExportPayload) (contracts.TaskImportResponse, error) {
	if txRepo, ok := repo.(kanban.TransactionalRepository); ok {
		var response contracts.TaskImportResponse
		err := txRepo.RunInTransaction(ctx, func(transactionRepo kanban.Repository) error {
			innerResponse, err := importTasksWithoutCompensation(ctx, transactionRepo, ownerUserID, boardID, payload)
			if err != nil {
				return importTransactionCallbackError{cause: err}
			}
			response = innerResponse
			return nil
		})

		var callbackErr importTransactionCallbackError
		if errors.As(err, &callbackErr) {
			return contracts.TaskImportResponse{}, callbackErr.cause
		}
		if errors.Is(err, kanban.ErrNotImplemented) {
			return importTasksWithCompensation(ctx, repo, ownerUserID, boardID, payload)
		}
		if err != nil {
			return contracts.TaskImportResponse{}, err
		}

		return response, nil
	}

	return importTasksWithCompensation(ctx, repo, ownerUserID, boardID, payload)
}

type importTransactionCallbackError struct {
	cause error
}

func (e importTransactionCallbackError) Error() string {
	if e.cause == nil {
		return "transaction callback failed"
	}
	return e.cause.Error()
}

func (e importTransactionCallbackError) Unwrap() error {
	return e.cause
}

func importTasksWithoutCompensation(ctx context.Context, repo kanban.Repository, ownerUserID, boardID string, payload contracts.TaskExportPayload) (contracts.TaskImportResponse, error) {
	columnsByTitle, missingTitles, err := resolveImportColumns(ctx, repo, ownerUserID, boardID, payload)
	if err != nil {
		return contracts.TaskImportResponse{}, err
	}

	createdColumnCount := 0
	for _, title := range missingTitles {
		createdColumn, _, createErr := repo.CreateColumn(ctx, ownerUserID, boardID, title)
		if createErr != nil {
			return contracts.TaskImportResponse{}, createErr
		}
		columnsByTitle[title] = createdColumn.ID
		createdColumnCount++
	}

	importedTaskCount, err := importTasksForResolvedColumns(ctx, repo, ownerUserID, boardID, payload, columnsByTitle)
	if err != nil {
		return contracts.TaskImportResponse{}, err
	}

	return contracts.TaskImportResponse{
		CreatedColumnCount: createdColumnCount,
		ImportedTaskCount:  importedTaskCount,
	}, nil
}

func importTasksWithCompensation(ctx context.Context, repo kanban.Repository, ownerUserID, boardID string, payload contracts.TaskExportPayload) (contracts.TaskImportResponse, error) {
	columnsByTitle, missingTitles, err := resolveImportColumns(ctx, repo, ownerUserID, boardID, payload)
	if err != nil {
		return contracts.TaskImportResponse{}, err
	}

	createdColumnIDs := make([]string, 0, len(missingTitles))
	createdTaskIDs := make([]string, 0)
	rollbackCtx := context.WithoutCancel(ctx)

	rollback := func() error {
		for i := len(createdTaskIDs) - 1; i >= 0; i-- {
			if _, err := repo.DeleteTask(rollbackCtx, ownerUserID, boardID, createdTaskIDs[i]); err != nil {
				return fmt.Errorf("rollback delete task %s: %w", createdTaskIDs[i], err)
			}
		}
		for i := len(createdColumnIDs) - 1; i >= 0; i-- {
			if _, err := repo.DeleteColumn(rollbackCtx, ownerUserID, boardID, createdColumnIDs[i]); err != nil {
				return fmt.Errorf("rollback delete column %s: %w", createdColumnIDs[i], err)
			}
		}
		return nil
	}

	for _, title := range missingTitles {
		createdColumn, _, err := repo.CreateColumn(ctx, ownerUserID, boardID, title)
		if err != nil {
			if rollbackErr := rollback(); rollbackErr != nil {
				return contracts.TaskImportResponse{}, fmt.Errorf("import create column rollback failed: %w", rollbackErr)
			}
			return contracts.TaskImportResponse{}, err
		}
		createdColumnIDs = append(createdColumnIDs, createdColumn.ID)
		columnsByTitle[title] = createdColumn.ID
	}

	importedTaskCount, err := importTasksForResolvedColumns(ctx, repo, ownerUserID, boardID, payload, columnsByTitle, func(taskID string) {
		createdTaskIDs = append(createdTaskIDs, taskID)
	})
	if err != nil {
		if rollbackErr := rollback(); rollbackErr != nil {
			return contracts.TaskImportResponse{}, fmt.Errorf("import create task rollback failed: %w", rollbackErr)
		}
		return contracts.TaskImportResponse{}, err
	}

	return contracts.TaskImportResponse{
		CreatedColumnCount: len(createdColumnIDs),
		ImportedTaskCount:  importedTaskCount,
	}, nil
}

func resolveImportColumns(ctx context.Context, repo kanban.Repository, ownerUserID, boardID string, payload contracts.TaskExportPayload) (map[string]string, []string, error) {
	details, err := repo.GetBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return nil, nil, err
	}

	columnsByTitle := make(map[string]string, len(details.Columns))
	for _, column := range details.Columns {
		title := strings.TrimSpace(column.Title)
		if title == "" {
			continue
		}
		if _, exists := columnsByTitle[title]; !exists {
			columnsByTitle[title] = column.ID
		}
	}

	missingTitles := make([]string, 0)
	seenMissing := make(map[string]struct{})
	for _, column := range payload.Columns {
		title := strings.TrimSpace(column.Title)
		if title == "" {
			continue
		}
		if _, exists := columnsByTitle[title]; exists {
			continue
		}
		if _, exists := seenMissing[title]; exists {
			continue
		}
		seenMissing[title] = struct{}{}
		missingTitles = append(missingTitles, title)
	}

	return columnsByTitle, missingTitles, nil
}

func importTasksForResolvedColumns(
	ctx context.Context,
	repo kanban.Repository,
	ownerUserID, boardID string,
	payload contracts.TaskExportPayload,
	columnsByTitle map[string]string,
	onCreate ...func(taskID string),
) (int, error) {
	fallbackArchivedAt := time.Now().UTC()
	if parsedExportedAt, err := time.Parse(time.RFC3339, strings.TrimSpace(payload.ExportedAt)); err == nil {
		fallbackArchivedAt = parsedExportedAt.UTC()
	}

	importedTaskCount := 0
	for _, column := range payload.Columns {
		title := strings.TrimSpace(column.Title)
		if title == "" {
			continue
		}
		columnID, exists := columnsByTitle[title]
		if !exists {
			continue
		}

		for _, task := range column.ArchivedTasks {
			taskTitle := strings.TrimSpace(task.Title)
			if taskTitle == "" {
				continue
			}

			archivedAt := fallbackArchivedAt
			if task.ArchivedAt != nil {
				parsedArchivedAt, err := time.Parse(time.RFC3339, strings.TrimSpace(*task.ArchivedAt))
				if err != nil {
					return 0, kanban.ErrInvalidInput
				}
				archivedAt = parsedArchivedAt.UTC()
			}

			createdTask, _, err := createImportedTask(ctx, repo, ownerUserID, boardID, columnID, taskTitle, task.Description, &archivedAt)
			if err != nil {
				return 0, err
			}
			if len(onCreate) > 0 && onCreate[0] != nil {
				onCreate[0](createdTask.ID)
			}
			importedTaskCount++
		}

		for _, task := range column.Tasks {
			taskTitle := strings.TrimSpace(task.Title)
			if taskTitle == "" {
				continue
			}

			createdTask, _, err := createImportedTask(ctx, repo, ownerUserID, boardID, columnID, taskTitle, task.Description, nil)
			if err != nil {
				return 0, err
			}
			if len(onCreate) > 0 && onCreate[0] != nil {
				onCreate[0](createdTask.ID)
			}
			importedTaskCount++
		}
	}

	return importedTaskCount, nil
}

func createImportedTask(
	ctx context.Context,
	repo kanban.Repository,
	ownerUserID, boardID, columnID, title, description string,
	archivedAt *time.Time,
) (kanban.Task, kanban.Board, error) {
	if archivedAt == nil {
		return repo.CreateTask(ctx, ownerUserID, boardID, columnID, title, description)
	}

	archiveRepo, ok := repo.(interface {
		CreateTaskWithArchivedAt(ctx context.Context, ownerUserID, boardID, columnID, title, description string, archivedAt *time.Time) (kanban.Task, kanban.Board, error)
	})
	if !ok {
		return kanban.Task{}, kanban.Board{}, kanban.ErrNotImplemented
	}

	archivedAtUTC := archivedAt.UTC()
	return archiveRepo.CreateTaskWithArchivedAt(ctx, ownerUserID, boardID, columnID, title, description, &archivedAtUTC)
}

func isSupportedBundleFormatVersion(version int) bool {
	return version == taskExportBundleFormatVersionV2 || version == taskExportBundleFormatVersionV3
}

func isSupportedPayloadFormatVersion(version int) bool {
	return version == taskExportFormatVersionV1 || version == taskExportFormatVersionV2
}
