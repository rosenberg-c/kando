package kanban

import "time"

type Board struct {
	ID           string
	OwnerUserID  string
	Title        string
	BoardVersion int
	CreatedAt    time.Time
	UpdatedAt    time.Time
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
	Position    int
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type BoardDetails struct {
	Board   Board
	Columns []Column
	Tasks   []Task
}
