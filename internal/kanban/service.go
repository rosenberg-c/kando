package kanban

import (
	"context"
	"strings"
)

// Service centralizes kanban business rules while delegating persistence to a repository implementation.
type Service struct {
	repo Repository
}

type archiveRepo interface {
	ArchiveCapableRepository
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

func (s *Service) RestoreBoard(ctx context.Context, ownerUserID, boardID string) (Board, error) {
	ar, ok := s.repo.(archiveRepo)
	if !ok {
		return Board{}, ErrNotImplemented
	}
	return ar.RestoreBoard(ctx, ownerUserID, boardID)
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

func (s *Service) RunInTransaction(ctx context.Context, fn func(repo Repository) error) error {
	txRepo, ok := s.repo.(TransactionalRepository)
	if !ok {
		return ErrNotImplemented
	}

	return txRepo.RunInTransaction(ctx, func(repo Repository) error {
		return fn(NewService(repo))
	})
}
