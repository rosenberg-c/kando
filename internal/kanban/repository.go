package kanban

import "context"

type Repository interface {
	ListBoardsByOwner(ctx context.Context, ownerUserID string) ([]Board, error)
	GetBoard(ctx context.Context, ownerUserID, boardID string) (BoardDetails, error)
	CreateBoard(ctx context.Context, ownerUserID, title string) (Board, error)
	UpdateBoardTitle(ctx context.Context, ownerUserID, boardID, title string) (Board, error)
	DeleteBoard(ctx context.Context, ownerUserID, boardID string) error

	CreateColumn(ctx context.Context, ownerUserID, boardID, title string) (Column, Board, error)
	UpdateColumnTitle(ctx context.Context, ownerUserID, boardID, columnID, title string) (Column, Board, error)
	DeleteColumn(ctx context.Context, ownerUserID, boardID, columnID string) (Board, error)

	CreateTodo(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (Todo, Board, error)
	UpdateTodo(ctx context.Context, ownerUserID, boardID, todoID, title, description string) (Todo, Board, error)
	DeleteTodo(ctx context.Context, ownerUserID, boardID, todoID string) (Board, error)
}
