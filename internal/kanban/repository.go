package kanban

import "context"

type Repository interface {
	ListBoardsByOwner(ctx context.Context, ownerUserID string) ([]Board, error)
	GetBoard(ctx context.Context, ownerUserID, boardID string) (BoardDetails, error)
	CreateBoardIfAbsent(ctx context.Context, ownerUserID, title string) (Board, error)
	UpdateBoardTitle(ctx context.Context, ownerUserID, boardID, title string) (Board, error)
	DeleteBoard(ctx context.Context, ownerUserID, boardID string) error

	CreateColumn(ctx context.Context, ownerUserID, boardID, title string) (Column, Board, error)
	UpdateColumnTitle(ctx context.Context, ownerUserID, boardID, columnID, title string) (Column, Board, error)
	ReorderColumns(ctx context.Context, ownerUserID, boardID string, orderedColumnIDs []string) (Board, error)
	DeleteColumn(ctx context.Context, ownerUserID, boardID, columnID string) (Board, error)

	CreateTask(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (Task, Board, error)
	UpdateTask(ctx context.Context, ownerUserID, boardID, taskID, title, description string) (Task, Board, error)
	MoveTask(ctx context.Context, ownerUserID, boardID, taskID, destinationColumnID string, destinationPosition int) (Task, Board, error)
	DeleteTask(ctx context.Context, ownerUserID, boardID, taskID string) (Board, error)
}
