package kanban

import "time"

type Board struct {
	ID                    string
	OwnerUserID           string
	Title                 string
	ArchivedOriginalTitle string
	IsArchived            bool
	BoardVersion          int
	CreatedAt             time.Time
	UpdatedAt             time.Time
}

type Column struct {
	ID          string
	BoardID     string
	OwnerUserID string
	Title       string
	Position    int
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type Task struct {
	ID          string
	BoardID     string
	ColumnID    string
	OwnerUserID string
	Title       string
	Description string
	IsArchived  bool
	ArchivedAt  time.Time
	Position    int
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// ColumnTaskArchiveResult describes the outcome of archiving active tasks in a
// column using one shared archive timestamp.
type ColumnTaskArchiveResult struct {
	ArchivedTaskCount int
	ArchivedAt        time.Time
}

type BoardDetails struct {
	Board   Board
	Columns []Column
	Tasks   []Task
}

type TaskColumnOrder struct {
	ColumnID string
	TaskIDs  []string
}
