package kanban

import (
	"context"
	"database/sql"
	"fmt"
)

const sqliteSchema = `
CREATE TABLE IF NOT EXISTS boards (
	id TEXT PRIMARY KEY,
	owner_user_id TEXT NOT NULL,
	title TEXT NOT NULL,
	archived_original_title TEXT,
	is_archived INTEGER NOT NULL DEFAULT 0,
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

	if err := ensureBoardArchiveColumn(ctx, r.db); err != nil {
		return fmt.Errorf("initialize sqlite schema: %w", err)
	}
	if err := ensureBoardArchivedOriginalTitleColumn(ctx, r.db); err != nil {
		return fmt.Errorf("initialize sqlite schema: %w", err)
	}
	if _, err := r.db.ExecContext(
		ctx,
		`CREATE INDEX IF NOT EXISTS idx_boards_owner_archived ON boards(owner_user_id, is_archived, updated_at_ms)`,
	); err != nil {
		return fmt.Errorf("initialize sqlite schema: create archive index: %w", err)
	}

	return nil
}

func ensureBoardArchiveColumn(ctx context.Context, db *sql.DB) error {
	rows, err := db.QueryContext(ctx, `PRAGMA table_info(boards)`)
	if err != nil {
		return fmt.Errorf("load boards table info: %w", err)
	}
	defer rows.Close()

	hasArchiveColumn := false
	for rows.Next() {
		var cid int
		var name string
		var ctype string
		var notnull int
		var dfltValue any
		var pk int
		if err := rows.Scan(&cid, &name, &ctype, &notnull, &dfltValue, &pk); err != nil {
			return fmt.Errorf("scan boards table info: %w", err)
		}
		if name == "is_archived" {
			hasArchiveColumn = true
		}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate boards table info: %w", err)
	}

	if hasArchiveColumn {
		return nil
	}

	if _, err := db.ExecContext(ctx, `ALTER TABLE boards ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0`); err != nil {
		return fmt.Errorf("add boards.is_archived column: %w", err)
	}

	return nil
}

func ensureBoardArchivedOriginalTitleColumn(ctx context.Context, db *sql.DB) error {
	rows, err := db.QueryContext(ctx, `PRAGMA table_info(boards)`)
	if err != nil {
		return fmt.Errorf("load boards table info: %w", err)
	}
	defer rows.Close()

	hasColumn := false
	for rows.Next() {
		var cid int
		var name string
		var ctype string
		var notnull int
		var dfltValue any
		var pk int
		if err := rows.Scan(&cid, &name, &ctype, &notnull, &dfltValue, &pk); err != nil {
			return fmt.Errorf("scan boards table info: %w", err)
		}
		if name == "archived_original_title" {
			hasColumn = true
		}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate boards table info: %w", err)
	}

	if hasColumn {
		return nil
	}

	if _, err := db.ExecContext(ctx, `ALTER TABLE boards ADD COLUMN archived_original_title TEXT`); err != nil {
		return fmt.Errorf("add boards.archived_original_title column: %w", err)
	}

	return nil
}
