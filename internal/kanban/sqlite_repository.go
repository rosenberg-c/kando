package kanban

import (
	"context"
	"database/sql"
	"fmt"
	"net/url"
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

	db, err := sql.Open("sqlite", sqliteDSN(trimmedPath))
	if err != nil {
		return nil, fmt.Errorf("open sqlite database: %w", err)
	}
	db.SetMaxOpenConns(1)

	repo := &SQLiteRepository{db: db, now: time.Now}
	if err := repo.initSchema(context.Background()); err != nil {
		_ = db.Close()
		return nil, err
	}

	return repo, nil
}

func sqliteDSN(path string) string {
	query := url.Values{}
	query.Add("_pragma", "foreign_keys(1)")

	if path == ":memory:" {
		query.Set("cache", "shared")
		return (&url.URL{Scheme: "file", Opaque: ":memory:", RawQuery: query.Encode()}).String()
	}

	query.Add("_pragma", "busy_timeout(5000)")
	return (&url.URL{Scheme: "file", Path: path, RawQuery: query.Encode()}).String()
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

func (r *SQLiteRepository) CreateBoardIfAbsent(ctx context.Context, ownerUserID, title string) (Board, error) {
	// SQLite atomicity relies on the unique constraint for owner_user_id.
	now := r.now().UTC()
	board := Board{
		ID:           uuid.NewString(),
		OwnerUserID:  ownerUserID,
		Title:        title,
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
			return Board{}, fmt.Errorf("create board conflict: %w", ErrConflict)
		}
		return Board{}, fmt.Errorf("create board: %w", err)
	}

	return board, nil
}

func (r *SQLiteRepository) UpdateBoardTitle(ctx context.Context, ownerUserID, boardID, title string) (Board, error) {
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
	board.Title = title
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
		Title:       title,
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

	board, err = bumpBoardTx(ctx, tx, board, r.now().UTC())
	if err != nil {
		return Column{}, Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Column{}, Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return column, board, nil
}

func (r *SQLiteRepository) UpdateColumnTitle(ctx context.Context, ownerUserID, boardID, columnID, title string) (Column, Board, error) {
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

	column.Title = title
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

	board, err = bumpBoardTx(ctx, tx, board, r.now().UTC())
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

	board, err = bumpBoardTx(ctx, tx, board, r.now().UTC())
	if err != nil {
		return Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return board, nil
}

func (r *SQLiteRepository) CreateTodo(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (Todo, Board, error) {
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
		Title:       title,
		Description: description,
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

	board, err = bumpBoardTx(ctx, tx, board, r.now().UTC())
	if err != nil {
		return Todo{}, Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Todo{}, Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return todo, board, nil
}

func (r *SQLiteRepository) UpdateTodo(ctx context.Context, ownerUserID, boardID, todoID, title, description string) (Todo, Board, error) {
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

	todo.Title = title
	todo.Description = description
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

	board, err = bumpBoardTx(ctx, tx, board, r.now().UTC())
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

	board, err = bumpBoardTx(ctx, tx, board, r.now().UTC())
	if err != nil {
		return Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return board, nil
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
		`SELECT t.id, t.board_id, t.column_id, t.owner_user_id, t.title, t.description, t.position, t.created_at_ms, t.updated_at_ms
		 FROM todos t
		 INNER JOIN columns c ON c.id = t.column_id
		 WHERE t.board_id = ?
		 ORDER BY c.position, t.position`,
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
