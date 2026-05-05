package kanban

import (
	"context"
	"errors"
	"strings"
	"time"
)

// Service centralizes kanban business rules while delegating persistence to a repository implementation.
type Service struct {
	repo Repository
}

type archiveRepo interface {
	ArchiveCapableRepository
}

type taskArchiveRepo interface {
	TaskArchiveCapableRepository
}

// TaskBatchAction identifies which collection-level mutation to apply.
type TaskBatchAction string

const (
	// TaskBatchActionDelete permanently deletes the requested task IDs.
	TaskBatchActionDelete TaskBatchAction = "delete"
)

// TaskBatchMutationRequest describes one explicit batch action request.
type TaskBatchMutationRequest struct {
	Action  TaskBatchAction
	TaskIDs []string
}

// NewService returns a Repository that applies shared kanban domain rules.
func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) ListBoardsByOwner(ctx context.Context, ownerUserID string) ([]Board, error) {
	return s.repo.ListBoardsByOwner(ctx, ownerUserID)
}

func (s *Service) GetBoard(ctx context.Context, ownerUserID, boardID string) (BoardDetails, error) {
	return s.repo.GetBoard(ctx, ownerUserID, boardID)
}

func (s *Service) CreateBoard(ctx context.Context, ownerUserID, title string) (Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Board{}, ErrInvalidInput
	}
	return s.repo.CreateBoard(ctx, ownerUserID, trimmedTitle)
}

func (s *Service) UpdateBoardTitle(ctx context.Context, ownerUserID, boardID, title string) (Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Board{}, ErrInvalidInput
	}
	return s.repo.UpdateBoardTitle(ctx, ownerUserID, boardID, trimmedTitle)
}

func (s *Service) DeleteBoard(ctx context.Context, ownerUserID, boardID string) error {
	details, err := s.repo.GetBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return err
	}
	if len(details.Tasks) > 0 {
		return NewConflictError(ConflictBoardHasTasks, "board has tasks")
	}

	return s.repo.DeleteBoard(ctx, ownerUserID, boardID)
}

func (s *Service) ListArchivedBoardsByOwner(ctx context.Context, ownerUserID string) ([]Board, error) {
	ar, ok := s.repo.(archiveRepo)
	if !ok {
		return nil, ErrNotImplemented
	}
	return ar.ListArchivedBoardsByOwner(ctx, ownerUserID)
}

func (s *Service) ArchiveBoard(ctx context.Context, ownerUserID, boardID string) (Board, error) {
	ar, ok := s.repo.(archiveRepo)
	if !ok {
		return Board{}, ErrNotImplemented
	}
	return ar.ArchiveBoard(ctx, ownerUserID, boardID)
}

func (s *Service) RestoreBoard(ctx context.Context, ownerUserID, boardID string, mode RestoreBoardTitleMode) (Board, error) {
	ar, ok := s.repo.(archiveRepo)
	if !ok {
		return Board{}, ErrNotImplemented
	}
	return ar.RestoreBoard(ctx, ownerUserID, boardID, mode)
}

func (s *Service) DeleteArchivedBoard(ctx context.Context, ownerUserID, boardID string) error {
	ar, ok := s.repo.(archiveRepo)
	if !ok {
		return ErrNotImplemented
	}
	return ar.DeleteArchivedBoard(ctx, ownerUserID, boardID)
}

func (s *Service) CreateColumn(ctx context.Context, ownerUserID, boardID, title string) (Column, Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Column{}, Board{}, ErrInvalidInput
	}
	return s.repo.CreateColumn(ctx, ownerUserID, boardID, trimmedTitle)
}

func (s *Service) UpdateColumnTitle(ctx context.Context, ownerUserID, boardID, columnID, title string) (Column, Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Column{}, Board{}, ErrInvalidInput
	}
	return s.repo.UpdateColumnTitle(ctx, ownerUserID, boardID, columnID, trimmedTitle)
}

func (s *Service) ReorderColumns(ctx context.Context, ownerUserID, boardID string, orderedColumnIDs []string) (Board, error) {
	if len(orderedColumnIDs) == 0 {
		return Board{}, ErrInvalidInput
	}
	return s.repo.ReorderColumns(ctx, ownerUserID, boardID, orderedColumnIDs)
}

func (s *Service) DeleteColumn(ctx context.Context, ownerUserID, boardID, columnID string) (Board, error) {
	details, err := s.repo.GetBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}
	for _, task := range details.Tasks {
		if task.ColumnID == columnID {
			return Board{}, NewConflictError(ConflictColumnHasTasks, "column has tasks")
		}
	}

	if ar, ok := s.repo.(taskArchiveRepo); ok {
		archivedTasks, err := ar.ListArchivedTasksByBoard(ctx, ownerUserID, boardID)
		if err != nil {
			return Board{}, err
		}
		for _, task := range archivedTasks {
			if task.ColumnID == columnID {
				return Board{}, NewConflictError(ConflictColumnHasArchivedTasks, "column has archived tasks")
			}
		}
	}
	return s.repo.DeleteColumn(ctx, ownerUserID, boardID, columnID)
}

func (s *Service) CreateTask(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (Task, Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Task{}, Board{}, ErrInvalidInput
	}
	return s.repo.CreateTask(ctx, ownerUserID, boardID, columnID, trimmedTitle, strings.TrimSpace(description))
}

func (s *Service) UpdateTask(ctx context.Context, ownerUserID, boardID, taskID, title, description string) (Task, Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Task{}, Board{}, ErrInvalidInput
	}
	return s.repo.UpdateTask(ctx, ownerUserID, boardID, taskID, trimmedTitle, strings.TrimSpace(description))
}

func (s *Service) ReorderTasks(ctx context.Context, ownerUserID, boardID string, orderedTasksByColumn []TaskColumnOrder) (Board, error) {
	if len(orderedTasksByColumn) == 0 {
		return Board{}, ErrInvalidInput
	}
	return s.repo.ReorderTasks(ctx, ownerUserID, boardID, orderedTasksByColumn)
}

func (s *Service) DeleteTask(ctx context.Context, ownerUserID, boardID, taskID string) (Board, error) {
	return s.repo.DeleteTask(ctx, ownerUserID, boardID, taskID)
}

// ApplyTaskBatchMutation validates and executes a list-based task batch action.
func (s *Service) ApplyTaskBatchMutation(ctx context.Context, ownerUserID, boardID string, request TaskBatchMutationRequest) (Board, error) {
	taskIDs, err := normalizeUniqueNonEmptyIDs(request.TaskIDs)
	if err != nil {
		return Board{}, err
	}

	switch request.Action {
	case TaskBatchActionDelete:
		return s.deleteTasksBatch(ctx, ownerUserID, boardID, taskIDs)
	default:
		return Board{}, ErrInvalidInput
	}
}

func (s *Service) deleteTasksBatch(ctx context.Context, ownerUserID, boardID string, taskIDs []string) (Board, error) {
	txRepo, ok := s.repo.(TransactionalRepository)
	if ok {
		if err := txRepo.RunInTransaction(ctx, func(repo Repository) error {
			for _, taskID := range taskIDs {
				if _, err := repo.DeleteTask(ctx, ownerUserID, boardID, taskID); err != nil {
					return err
				}
			}
			return nil
		}); err != nil {
			if !errors.Is(err, ErrNotImplemented) {
				return Board{}, err
			}
		} else {
			details, err := s.repo.GetBoard(ctx, ownerUserID, boardID)
			if err != nil {
				return Board{}, err
			}
			return details.Board, nil
		}
	}

	for _, taskID := range taskIDs {
		if _, err := s.repo.DeleteTask(ctx, ownerUserID, boardID, taskID); err != nil {
			return Board{}, err
		}
	}

	details, err := s.repo.GetBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}
	return details.Board, nil
}

func normalizeUniqueNonEmptyIDs(ids []string) ([]string, error) {
	if len(ids) == 0 {
		return nil, ErrInvalidInput
	}

	seen := make(map[string]struct{}, len(ids))
	normalized := make([]string, 0, len(ids))
	for _, rawID := range ids {
		id := strings.TrimSpace(rawID)
		if id == "" {
			return nil, ErrInvalidInput
		}
		if _, exists := seen[id]; exists {
			return nil, ErrInvalidInput
		}
		seen[id] = struct{}{}
		normalized = append(normalized, id)
	}

	return normalized, nil
}

// ArchiveTasksInColumn archives all active tasks in the provided column.
func (s *Service) ArchiveTasksInColumn(ctx context.Context, ownerUserID, boardID, columnID string) (ColumnTaskArchiveResult, Board, error) {
	ar, ok := s.repo.(taskArchiveRepo)
	if !ok {
		return ColumnTaskArchiveResult{}, Board{}, ErrNotImplemented
	}
	return ar.ArchiveTasksInColumn(ctx, ownerUserID, boardID, columnID)
}

// ListArchivedTasksByBoard lists archived tasks for the specified board.
func (s *Service) ListArchivedTasksByBoard(ctx context.Context, ownerUserID, boardID string) ([]Task, error) {
	ar, ok := s.repo.(taskArchiveRepo)
	if !ok {
		return nil, ErrNotImplemented
	}
	return ar.ListArchivedTasksByBoard(ctx, ownerUserID, boardID)
}

// RestoreArchivedTask restores a single archived task back to active state.
func (s *Service) RestoreArchivedTask(ctx context.Context, ownerUserID, boardID, taskID string) (Task, Board, error) {
	ar, ok := s.repo.(taskArchiveRepo)
	if !ok {
		return Task{}, Board{}, ErrNotImplemented
	}
	return ar.RestoreArchivedTask(ctx, ownerUserID, boardID, taskID)
}

// DeleteArchivedTask permanently deletes a single archived task.
func (s *Service) DeleteArchivedTask(ctx context.Context, ownerUserID, boardID, taskID string) (Board, error) {
	ar, ok := s.repo.(taskArchiveRepo)
	if !ok {
		return Board{}, ErrNotImplemented
	}
	return ar.DeleteArchivedTask(ctx, ownerUserID, boardID, taskID)
}

// CreateTaskWithArchivedAt creates a task and optionally marks it archived at
// the provided timestamp when archivedAt is non-nil.
func (s *Service) CreateTaskWithArchivedAt(ctx context.Context, ownerUserID, boardID, columnID, title, description string, archivedAt *time.Time) (Task, Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Task{}, Board{}, ErrInvalidInput
	}
	ar, ok := s.repo.(taskArchiveRepo)
	if !ok {
		return Task{}, Board{}, ErrNotImplemented
	}
	return ar.CreateTaskWithArchivedAt(ctx, ownerUserID, boardID, columnID, trimmedTitle, strings.TrimSpace(description), archivedAt)
}

func (s *Service) RunInTransaction(ctx context.Context, fn func(repo Repository) error) error {
	txRepo, ok := s.repo.(TransactionalRepository)
	if !ok {
		return ErrNotImplemented
	}

	return txRepo.RunInTransaction(ctx, func(repo Repository) error {
		return fn(NewService(repo))
	})
}
