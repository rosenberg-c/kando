package kanban

import (
	"context"
	"fmt"
	"strings"
)

// Service centralizes kanban business rules while delegating persistence to a repository implementation.
type Service struct {
	repo Repository
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
	return s.repo.DeleteBoard(ctx, ownerUserID, boardID)
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

func (s *Service) DeleteColumn(ctx context.Context, ownerUserID, boardID, columnID string) (Board, error) {
	details, err := s.repo.GetBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}
	for _, todo := range details.Todos {
		if todo.ColumnID == columnID {
			return Board{}, fmt.Errorf("column has todos: %w", ErrConflict)
		}
	}
	return s.repo.DeleteColumn(ctx, ownerUserID, boardID, columnID)
}

func (s *Service) CreateTodo(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (Todo, Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Todo{}, Board{}, ErrInvalidInput
	}
	return s.repo.CreateTodo(ctx, ownerUserID, boardID, columnID, trimmedTitle, strings.TrimSpace(description))
}

func (s *Service) UpdateTodo(ctx context.Context, ownerUserID, boardID, todoID, title, description string) (Todo, Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Todo{}, Board{}, ErrInvalidInput
	}
	return s.repo.UpdateTodo(ctx, ownerUserID, boardID, todoID, trimmedTitle, strings.TrimSpace(description))
}

func (s *Service) DeleteTodo(ctx context.Context, ownerUserID, boardID, todoID string) (Board, error) {
	return s.repo.DeleteTodo(ctx, ownerUserID, boardID, todoID)
}
