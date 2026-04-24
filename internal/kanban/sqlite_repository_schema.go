package kanban

import (
	"context"
	"fmt"
)

const sqliteSchema = `
CREATE TABLE IF NOT EXISTS boards (
	id TEXT PRIMARY KEY,
	owner_user_id TEXT NOT NULL,
	title TEXT NOT NULL,
	board_version INTEGER NOT NULL,
	created_at_ms INTEGER NOT NULL,
	updated_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS columns (
	id TEXT PRIMARY KEY,
	board_id TEXT NOT NULL,
	owner_user_id TEXT NOT NULL,
	title TEXT NOT NULL,
	position INTEGER NOT NULL,
	created_at_ms INTEGER NOT NULL,
	updated_at_ms INTEGER NOT NULL,
	FOREIGN KEY(board_id) REFERENCES boards(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tasks (
	id TEXT PRIMARY KEY,
	board_id TEXT NOT NULL,
	column_id TEXT NOT NULL,
	owner_user_id TEXT NOT NULL,
	title TEXT NOT NULL,
	description TEXT NOT NULL,
	position INTEGER NOT NULL,
	created_at_ms INTEGER NOT NULL,
	updated_at_ms INTEGER NOT NULL,
	FOREIGN KEY(board_id) REFERENCES boards(id) ON DELETE CASCADE,
	FOREIGN KEY(column_id) REFERENCES columns(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_boards_owner ON boards(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_columns_board_position ON columns(board_id, position);
CREATE INDEX IF NOT EXISTS idx_tasks_board ON tasks(board_id);
CREATE INDEX IF NOT EXISTS idx_tasks_column_position ON tasks(column_id, position);
`

func (r *SQLiteRepository) initSchema(ctx context.Context) error {
	if _, err := r.db.ExecContext(ctx, sqliteSchema); err != nil {
		return fmt.Errorf("initialize sqlite schema: %w", err)
	}

	return nil
}
