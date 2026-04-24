package schema

import "strings"

// AppwriteDatabase describes a TablesDB database and its managed tables.
type AppwriteDatabase struct {
	ID     string          `json:"id"`
	Name   string          `json:"name"`
	Tables []AppwriteTable `json:"tables"`
}

// AppwriteTable describes a managed Appwrite table.
type AppwriteTable struct {
	ID      string           `json:"id"`
	Name    string           `json:"name"`
	Columns []AppwriteColumn `json:"columns"`
	Indexes []AppwriteIndex  `json:"indexes"`
}

// AppwriteColumn describes a managed Appwrite table column.
type AppwriteColumn struct {
	Kind     string `json:"kind"`
	Key      string `json:"key"`
	Required bool   `json:"required"`
	Size     int    `json:"size,omitempty"`
}

// AppwriteIndex describes a managed Appwrite table index.
type AppwriteIndex struct {
	Key     string   `json:"key"`
	Type    string   `json:"type"`
	Columns []string `json:"columns"`
	Orders  []string `json:"orders"`
}

// AppwriteIDOverrides allows environment-specific ID/name overrides.
type AppwriteIDOverrides struct {
	DatabaseID     string
	DatabaseName   string
	BoardsTableID  string
	ColumnsTableID string
	TasksTableID   string
}

// KanbanAppwriteDatabase returns the canonical Appwrite schema for Kanban data.
func KanbanAppwriteDatabase() AppwriteDatabase {
	return AppwriteDatabase{
		ID:   "task",
		Name: "Task",
		Tables: []AppwriteTable{
			{
				ID:   "boards",
				Name: "Boards",
				Columns: []AppwriteColumn{
					{Kind: "string", Key: "ownerUserId", Required: true, Size: 64},
					{Kind: "string", Key: "title", Required: true, Size: 120},
					{Kind: "integer", Key: "boardVersion", Required: true},
					{Kind: "datetime", Key: "createdAt", Required: true},
					{Kind: "datetime", Key: "updatedAt", Required: true},
				},
				Indexes: []AppwriteIndex{
					{Key: "boards_owner_updated", Type: "key", Columns: []string{"ownerUserId", "updatedAt"}, Orders: []string{"ASC", "DESC"}},
				},
			},
			{
				ID:   "columns",
				Name: "Columns",
				Columns: []AppwriteColumn{
					{Kind: "string", Key: "boardId", Required: true, Size: 64},
					{Kind: "string", Key: "ownerUserId", Required: true, Size: 64},
					{Kind: "string", Key: "title", Required: true, Size: 120},
					{Kind: "integer", Key: "position", Required: true},
					{Kind: "datetime", Key: "createdAt", Required: true},
					{Kind: "datetime", Key: "updatedAt", Required: true},
				},
				Indexes: []AppwriteIndex{
					{Key: "columns_board_position", Type: "key", Columns: []string{"boardId", "position"}, Orders: []string{"ASC", "ASC"}},
				},
			},
			{
				ID:   "tasks",
				Name: "Tasks",
				Columns: []AppwriteColumn{
					{Kind: "string", Key: "boardId", Required: true, Size: 64},
					{Kind: "string", Key: "columnId", Required: true, Size: 64},
					{Kind: "string", Key: "ownerUserId", Required: true, Size: 64},
					{Kind: "string", Key: "title", Required: true, Size: 200},
					{Kind: "string", Key: "description", Required: true, Size: 4000},
					{Kind: "integer", Key: "position", Required: true},
					{Kind: "datetime", Key: "createdAt", Required: true},
					{Kind: "datetime", Key: "updatedAt", Required: true},
				},
				Indexes: []AppwriteIndex{
					{Key: "tasks_board_column_position", Type: "key", Columns: []string{"boardId", "columnId", "position"}, Orders: []string{"ASC", "ASC", "ASC"}},
				},
			},
		},
	}
}

// ApplyAppwriteIDOverrides applies optional environment-specific ID/name overrides in-place.
func ApplyAppwriteIDOverrides(database *AppwriteDatabase, overrides AppwriteIDOverrides) {
	if database == nil {
		return
	}
	if trimmed := strings.TrimSpace(overrides.DatabaseID); trimmed != "" {
		database.ID = trimmed
	}
	if trimmed := strings.TrimSpace(overrides.DatabaseName); trimmed != "" {
		database.Name = trimmed
	}

	rewriteTableID(database, "boards", strings.TrimSpace(overrides.BoardsTableID))
	rewriteTableID(database, "columns", strings.TrimSpace(overrides.ColumnsTableID))
	rewriteTableID(database, "tasks", strings.TrimSpace(overrides.TasksTableID))
}

func rewriteTableID(database *AppwriteDatabase, defaultID, override string) {
	if override == "" {
		return
	}
	for i := range database.Tables {
		if database.Tables[i].ID == defaultID {
			database.Tables[i].ID = override
			return
		}
	}
}
