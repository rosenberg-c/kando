package kanban

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	_ "modernc.org/sqlite"
)

type SQLiteRepository struct {
	db  *sql.DB
	now func() time.Time
}

func NewSQLiteRepository(path string) (*SQLiteRepository, error) {
	trimmedPath := strings.TrimSpace(path)
	if trimmedPath == "" {
		return nil, fmt.Errorf("sqlite path is required: %w", ErrInvalidInput)
	}

	if trimmedPath != ":memory:" {
		if err := os.MkdirAll(filepath.Dir(trimmedPath), 0o755); err != nil {
			return nil, fmt.Errorf("create sqlite directory: %w", err)
		}
	}

	dsn := sqliteDSN(trimmedPath)
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("open sqlite database: %w", err)
	}

	db.SetMaxOpenConns(1)

	repo := &SQLiteRepository{
		db:  db,
		now: time.Now,
	}

	if err := repo.initSchema(context.Background()); err != nil {
		_ = db.Close()
		return nil, err
	}

	return repo, nil
}

func sqliteDSN(path string) string {
	if path == ":memory:" {
		return "file::memory:?cache=shared&_pragma=foreign_keys(1)"
	}
	return "file:" + path + "?_pragma=busy_timeout(5000)&_pragma=foreign_keys(1)"
}

func (r *SQLiteRepository) Close() error {
	return r.db.Close()
}

func (r *SQLiteRepository) ListBoardsByOwner(ctx context.Context, ownerUserID string) ([]Board, error) {
	rows, err := r.db.QueryContext(
		ctx,
		`SELECT id, owner_user_id, title, board_version, created_at_ms, updated_at_ms
		 FROM boards
		 WHERE owner_user_id = ?
		 ORDER BY updated_at_ms DESC`,
		ownerUserID,
	)
	if err != nil {
		return nil, fmt.Errorf("list boards: %w", err)
	}
	defer rows.Close()

	boards := make([]Board, 0)
	for rows.Next() {
		board, scanErr := scanBoard(rows.Scan)
		if scanErr != nil {
			return nil, scanErr
		}
		boards = append(boards, board)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate boards: %w", err)
	}

	return boards, nil
}

func (r *SQLiteRepository) GetBoard(ctx context.Context, ownerUserID, boardID string) (BoardDetails, error) {
	board, err := getOwnedBoard(ctx, r.db, ownerUserID, boardID)
	if err != nil {
		return BoardDetails{}, err
	}

	columns, err := r.listColumns(ctx, boardID)
	if err != nil {
		return BoardDetails{}, err
	}

	todos, err := r.listTodos(ctx, boardID)
	if err != nil {
		return BoardDetails{}, err
	}

	return BoardDetails{Board: board, Columns: columns, Todos: todos}, nil
}

func (r *SQLiteRepository) CreateBoard(ctx context.Context, ownerUserID, title string) (Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Board{}, ErrInvalidInput
	}

	now := r.now().UTC()
	board := Board{
		ID:           uuid.NewString(),
		OwnerUserID:  ownerUserID,
		Title:        trimmedTitle,
		BoardVersion: 1,
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	_, err := r.db.ExecContext(
		ctx,
		`INSERT INTO boards (id, owner_user_id, title, board_version, created_at_ms, updated_at_ms)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		board.ID,
		board.OwnerUserID,
		board.Title,
		board.BoardVersion,
		toUnixMillis(board.CreatedAt),
		toUnixMillis(board.UpdatedAt),
	)
	if err != nil {
		if isUniqueConstraintError(err) {
			return Board{}, fmt.Errorf("single board per user: %w", ErrConflict)
		}
		return Board{}, fmt.Errorf("create board: %w", err)
	}

	return board, nil
}

func (r *SQLiteRepository) UpdateBoardTitle(ctx context.Context, ownerUserID, boardID, title string) (Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Board{}, ErrInvalidInput
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	now := r.now().UTC()
	board.Title = trimmedTitle
	board.BoardVersion++
	board.UpdatedAt = now

	if _, err := tx.ExecContext(
		ctx,
		`UPDATE boards SET title = ?, board_version = ?, updated_at_ms = ? WHERE id = ?`,
		board.Title,
		board.BoardVersion,
		toUnixMillis(board.UpdatedAt),
		board.ID,
	); err != nil {
		return Board{}, fmt.Errorf("update board: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return board, nil
}

func (r *SQLiteRepository) DeleteBoard(ctx context.Context, ownerUserID, boardID string) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	if _, err := getOwnedBoard(ctx, tx, ownerUserID, boardID); err != nil {
		return err
	}

	if _, err := tx.ExecContext(ctx, `DELETE FROM boards WHERE id = ?`, boardID); err != nil {
		return fmt.Errorf("delete board: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}

	return nil
}

func (r *SQLiteRepository) CreateColumn(ctx context.Context, ownerUserID, boardID, title string) (Column, Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Column{}, Board{}, ErrInvalidInput
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Column{}, Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Column{}, Board{}, err
	}

	position, err := nextPosition(ctx, tx, `SELECT COALESCE(MAX(position), -1) + 1 FROM columns WHERE board_id = ?`, boardID)
	if err != nil {
		return Column{}, Board{}, err
	}

	now := r.now().UTC()
	column := Column{
		ID:          uuid.NewString(),
		BoardID:     boardID,
		OwnerUserID: ownerUserID,
		Title:       trimmedTitle,
		Position:    position,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	if _, err := tx.ExecContext(
		ctx,
		`INSERT INTO columns (id, board_id, owner_user_id, title, position, created_at_ms, updated_at_ms)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		column.ID,
		column.BoardID,
		column.OwnerUserID,
		column.Title,
		column.Position,
		toUnixMillis(column.CreatedAt),
		toUnixMillis(column.UpdatedAt),
	); err != nil {
		return Column{}, Board{}, fmt.Errorf("create column: %w", err)
	}

	board, err = bumpBoardTx(ctx, tx, board)
	if err != nil {
		return Column{}, Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Column{}, Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return column, board, nil
}

func (r *SQLiteRepository) UpdateColumnTitle(ctx context.Context, ownerUserID, boardID, columnID, title string) (Column, Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	if trimmedTitle == "" {
		return Column{}, Board{}, ErrInvalidInput
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Column{}, Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Column{}, Board{}, err
	}

	column, err := getOwnedColumn(ctx, tx, ownerUserID, boardID, columnID)
	if err != nil {
		return Column{}, Board{}, err
	}

	column.Title = trimmedTitle
	column.UpdatedAt = r.now().UTC()

	if _, err := tx.ExecContext(
		ctx,
		`UPDATE columns SET title = ?, updated_at_ms = ? WHERE id = ?`,
		column.Title,
		toUnixMillis(column.UpdatedAt),
		column.ID,
	); err != nil {
		return Column{}, Board{}, fmt.Errorf("update column: %w", err)
	}

	board, err = bumpBoardTx(ctx, tx, board)
	if err != nil {
		return Column{}, Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Column{}, Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return column, board, nil
}

func (r *SQLiteRepository) DeleteColumn(ctx context.Context, ownerUserID, boardID, columnID string) (Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	if _, err := getOwnedColumn(ctx, tx, ownerUserID, boardID, columnID); err != nil {
		return Board{}, err
	}

	if _, err := tx.ExecContext(ctx, `DELETE FROM columns WHERE id = ?`, columnID); err != nil {
		return Board{}, fmt.Errorf("delete column: %w", err)
	}

	if err := reindexColumnsTx(ctx, tx, boardID, r.now().UTC()); err != nil {
		return Board{}, err
	}

	board, err = bumpBoardTx(ctx, tx, board)
	if err != nil {
		return Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return board, nil
}

func (r *SQLiteRepository) CreateTodo(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (Todo, Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	trimmedDescription := strings.TrimSpace(description)
	if trimmedTitle == "" {
		return Todo{}, Board{}, ErrInvalidInput
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Todo{}, Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Todo{}, Board{}, err
	}

	if _, err := getOwnedColumn(ctx, tx, ownerUserID, boardID, columnID); err != nil {
		return Todo{}, Board{}, err
	}

	position, err := nextPosition(ctx, tx, `SELECT COALESCE(MAX(position), -1) + 1 FROM todos WHERE column_id = ?`, columnID)
	if err != nil {
		return Todo{}, Board{}, err
	}

	now := r.now().UTC()
	todo := Todo{
		ID:          uuid.NewString(),
		BoardID:     boardID,
		ColumnID:    columnID,
		OwnerUserID: ownerUserID,
		Title:       trimmedTitle,
		Description: trimmedDescription,
		Position:    position,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	if _, err := tx.ExecContext(
		ctx,
		`INSERT INTO todos (id, board_id, column_id, owner_user_id, title, description, position, created_at_ms, updated_at_ms)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		todo.ID,
		todo.BoardID,
		todo.ColumnID,
		todo.OwnerUserID,
		todo.Title,
		todo.Description,
		todo.Position,
		toUnixMillis(todo.CreatedAt),
		toUnixMillis(todo.UpdatedAt),
	); err != nil {
		return Todo{}, Board{}, fmt.Errorf("create todo: %w", err)
	}

	board, err = bumpBoardTx(ctx, tx, board)
	if err != nil {
		return Todo{}, Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Todo{}, Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return todo, board, nil
}

func (r *SQLiteRepository) UpdateTodo(ctx context.Context, ownerUserID, boardID, todoID, title, description string) (Todo, Board, error) {
	trimmedTitle := strings.TrimSpace(title)
	trimmedDescription := strings.TrimSpace(description)
	if trimmedTitle == "" {
		return Todo{}, Board{}, ErrInvalidInput
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Todo{}, Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Todo{}, Board{}, err
	}

	todo, err := getOwnedTodo(ctx, tx, ownerUserID, boardID, todoID)
	if err != nil {
		return Todo{}, Board{}, err
	}

	todo.Title = trimmedTitle
	todo.Description = trimmedDescription
	todo.UpdatedAt = r.now().UTC()

	if _, err := tx.ExecContext(
		ctx,
		`UPDATE todos SET title = ?, description = ?, updated_at_ms = ? WHERE id = ?`,
		todo.Title,
		todo.Description,
		toUnixMillis(todo.UpdatedAt),
		todo.ID,
	); err != nil {
		return Todo{}, Board{}, fmt.Errorf("update todo: %w", err)
	}

	board, err = bumpBoardTx(ctx, tx, board)
	if err != nil {
		return Todo{}, Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Todo{}, Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return todo, board, nil
}

func (r *SQLiteRepository) DeleteTodo(ctx context.Context, ownerUserID, boardID, todoID string) (Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	todo, err := getOwnedTodo(ctx, tx, ownerUserID, boardID, todoID)
	if err != nil {
		return Board{}, err
	}

	if _, err := tx.ExecContext(ctx, `DELETE FROM todos WHERE id = ?`, todoID); err != nil {
		return Board{}, fmt.Errorf("delete todo: %w", err)
	}

	if err := reindexTodosTx(ctx, tx, todo.ColumnID, r.now().UTC()); err != nil {
		return Board{}, err
	}

	board, err = bumpBoardTx(ctx, tx, board)
	if err != nil {
		return Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return board, nil
}

func (r *SQLiteRepository) initSchema(ctx context.Context) error {
	const schema = `
CREATE TABLE IF NOT EXISTS boards (
	id TEXT PRIMARY KEY,
	owner_user_id TEXT NOT NULL UNIQUE,
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

CREATE TABLE IF NOT EXISTS todos (
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
CREATE INDEX IF NOT EXISTS idx_todos_board ON todos(board_id);
CREATE INDEX IF NOT EXISTS idx_todos_column_position ON todos(column_id, position);
`

	if _, err := r.db.ExecContext(ctx, schema); err != nil {
		return fmt.Errorf("initialize sqlite schema: %w", err)
	}

	return nil
}

func (r *SQLiteRepository) listColumns(ctx context.Context, boardID string) ([]Column, error) {
	rows, err := r.db.QueryContext(
		ctx,
		`SELECT id, board_id, owner_user_id, title, position, created_at_ms, updated_at_ms
		 FROM columns
		 WHERE board_id = ?
		 ORDER BY position`,
		boardID,
	)
	if err != nil {
		return nil, fmt.Errorf("list columns: %w", err)
	}
	defer rows.Close()

	columns := make([]Column, 0)
	for rows.Next() {
		column, scanErr := scanColumn(rows.Scan)
		if scanErr != nil {
			return nil, scanErr
		}
		columns = append(columns, column)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate columns: %w", err)
	}

	return columns, nil
}

func (r *SQLiteRepository) listTodos(ctx context.Context, boardID string) ([]Todo, error) {
	rows, err := r.db.QueryContext(
		ctx,
		`SELECT id, board_id, column_id, owner_user_id, title, description, position, created_at_ms, updated_at_ms
		 FROM todos
		 WHERE board_id = ?
		 ORDER BY column_id, position`,
		boardID,
	)
	if err != nil {
		return nil, fmt.Errorf("list todos: %w", err)
	}
	defer rows.Close()

	todos := make([]Todo, 0)
	for rows.Next() {
		todo, scanErr := scanTodo(rows.Scan)
		if scanErr != nil {
			return nil, scanErr
		}
		todos = append(todos, todo)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate todos: %w", err)
	}

	return todos, nil
}

type queryRower interface {
	QueryRowContext(context.Context, string, ...any) *sql.Row
}

func getOwnedBoard(ctx context.Context, q queryRower, ownerUserID, boardID string) (Board, error) {
	board, err := scanBoard(q.QueryRowContext(
		ctx,
		`SELECT id, owner_user_id, title, board_version, created_at_ms, updated_at_ms
		 FROM boards
		 WHERE id = ?`,
		boardID,
	).Scan)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Board{}, ErrNotFound
		}
		return Board{}, err
	}
	if board.OwnerUserID != ownerUserID {
		return Board{}, ErrForbidden
	}
	return board, nil
}

func getOwnedColumn(ctx context.Context, q queryRower, ownerUserID, boardID, columnID string) (Column, error) {
	column, err := scanColumn(q.QueryRowContext(
		ctx,
		`SELECT id, board_id, owner_user_id, title, position, created_at_ms, updated_at_ms
		 FROM columns
		 WHERE id = ?`,
		columnID,
	).Scan)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Column{}, ErrNotFound
		}
		return Column{}, err
	}
	if column.BoardID != boardID {
		return Column{}, ErrNotFound
	}
	if column.OwnerUserID != ownerUserID {
		return Column{}, ErrForbidden
	}
	return column, nil
}

func getOwnedTodo(ctx context.Context, q queryRower, ownerUserID, boardID, todoID string) (Todo, error) {
	todo, err := scanTodo(q.QueryRowContext(
		ctx,
		`SELECT id, board_id, column_id, owner_user_id, title, description, position, created_at_ms, updated_at_ms
		 FROM todos
		 WHERE id = ?`,
		todoID,
	).Scan)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Todo{}, ErrNotFound
		}
		return Todo{}, err
	}
	if todo.BoardID != boardID {
		return Todo{}, ErrNotFound
	}
	if todo.OwnerUserID != ownerUserID {
		return Todo{}, ErrForbidden
	}
	return todo, nil
}

type scannerFunc func(dest ...any) error

func scanBoard(scan scannerFunc) (Board, error) {
	var board Board
	var createdAtMS int64
	var updatedAtMS int64

	if err := scan(
		&board.ID,
		&board.OwnerUserID,
		&board.Title,
		&board.BoardVersion,
		&createdAtMS,
		&updatedAtMS,
	); err != nil {
		return Board{}, err
	}

	board.CreatedAt = fromUnixMillis(createdAtMS)
	board.UpdatedAt = fromUnixMillis(updatedAtMS)

	return board, nil
}

func scanColumn(scan scannerFunc) (Column, error) {
	var column Column
	var createdAtMS int64
	var updatedAtMS int64

	if err := scan(
		&column.ID,
		&column.BoardID,
		&column.OwnerUserID,
		&column.Title,
		&column.Position,
		&createdAtMS,
		&updatedAtMS,
	); err != nil {
		return Column{}, err
	}

	column.CreatedAt = fromUnixMillis(createdAtMS)
	column.UpdatedAt = fromUnixMillis(updatedAtMS)

	return column, nil
}

func scanTodo(scan scannerFunc) (Todo, error) {
	var todo Todo
	var createdAtMS int64
	var updatedAtMS int64

	if err := scan(
		&todo.ID,
		&todo.BoardID,
		&todo.ColumnID,
		&todo.OwnerUserID,
		&todo.Title,
		&todo.Description,
		&todo.Position,
		&createdAtMS,
		&updatedAtMS,
	); err != nil {
		return Todo{}, err
	}

	todo.CreatedAt = fromUnixMillis(createdAtMS)
	todo.UpdatedAt = fromUnixMillis(updatedAtMS)

	return todo, nil
}

func nextPosition(ctx context.Context, q queryRower, query string, arg string) (int, error) {
	var position int
	if err := q.QueryRowContext(ctx, query, arg).Scan(&position); err != nil {
		return 0, fmt.Errorf("load next position: %w", err)
	}
	return position, nil
}

func reindexColumnsTx(ctx context.Context, tx *sql.Tx, boardID string, now time.Time) error {
	rows, err := tx.QueryContext(ctx, `SELECT id FROM columns WHERE board_id = ? ORDER BY position`, boardID)
	if err != nil {
		return fmt.Errorf("list columns for reindex: %w", err)
	}
	defer rows.Close()

	ids := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return fmt.Errorf("scan column id: %w", err)
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate columns for reindex: %w", err)
	}

	for i, id := range ids {
		if _, err := tx.ExecContext(
			ctx,
			`UPDATE columns SET position = ?, updated_at_ms = ? WHERE id = ?`,
			i,
			toUnixMillis(now),
			id,
		); err != nil {
			return fmt.Errorf("update column position: %w", err)
		}
	}

	return nil
}

func reindexTodosTx(ctx context.Context, tx *sql.Tx, columnID string, now time.Time) error {
	rows, err := tx.QueryContext(ctx, `SELECT id FROM todos WHERE column_id = ? ORDER BY position`, columnID)
	if err != nil {
		return fmt.Errorf("list todos for reindex: %w", err)
	}
	defer rows.Close()

	ids := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return fmt.Errorf("scan todo id: %w", err)
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate todos for reindex: %w", err)
	}

	for i, id := range ids {
		if _, err := tx.ExecContext(
			ctx,
			`UPDATE todos SET position = ?, updated_at_ms = ? WHERE id = ?`,
			i,
			toUnixMillis(now),
			id,
		); err != nil {
			return fmt.Errorf("update todo position: %w", err)
		}
	}

	return nil
}

func bumpBoardTx(ctx context.Context, tx *sql.Tx, board Board) (Board, error) {
	board.BoardVersion++
	board.UpdatedAt = time.Now().UTC()

	if _, err := tx.ExecContext(
		ctx,
		`UPDATE boards SET board_version = ?, updated_at_ms = ? WHERE id = ?`,
		board.BoardVersion,
		toUnixMillis(board.UpdatedAt),
		board.ID,
	); err != nil {
		return Board{}, fmt.Errorf("bump board version: %w", err)
	}

	return board, nil
}

func rollback(tx *sql.Tx) {
	_ = tx.Rollback()
}

func isUniqueConstraintError(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(strings.ToLower(err.Error()), "unique constraint failed")
}

func toUnixMillis(t time.Time) int64 {
	return t.UTC().UnixMilli()
}

func fromUnixMillis(ms int64) time.Time {
	return time.UnixMilli(ms).UTC()
}
