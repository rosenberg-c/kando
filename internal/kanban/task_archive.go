package kanban

import (
	"context"
	"time"
)

// TaskArchiveCapableRepository defines repository operations for archived-task
// lifecycle flows and archive-aware task creation.
type TaskArchiveCapableRepository interface {
	// ArchiveTasksInColumn archives active tasks in the target column and returns
	// the count plus the shared archived timestamp used for the batch.
	ArchiveTasksInColumn(ctx context.Context, ownerUserID, boardID, columnID string) (ColumnTaskArchiveResult, Board, error)
	// ListArchivedTasksByBoard returns archived tasks scoped to a board.
	ListArchivedTasksByBoard(ctx context.Context, ownerUserID, boardID string) ([]Task, error)
	// RestoreArchivedTask restores a single archived task into active state.
	RestoreArchivedTask(ctx context.Context, ownerUserID, boardID, taskID string) (Task, Board, error)
	// DeleteArchivedTask permanently deletes a single archived task.
	DeleteArchivedTask(ctx context.Context, ownerUserID, boardID, taskID string) (Board, error)
	// CreateTaskWithArchivedAt creates a task and optionally marks it archived at
	// the provided timestamp when archivedAt is non-nil.
	CreateTaskWithArchivedAt(ctx context.Context, ownerUserID, boardID, columnID, title, description string, archivedAt *time.Time) (Task, Board, error)
}
