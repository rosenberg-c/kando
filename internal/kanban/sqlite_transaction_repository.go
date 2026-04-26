package kanban

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
)

func (r *SQLiteRepository) RunInTransaction(ctx context.Context, fn func(repo Repository) error) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	txRepo := &sqliteTxRepository{tx: tx, now: r.now}
	if err := fn(txRepo); err != nil {
		return err
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}

	return nil
}

type sqliteTxRepository struct {
	tx  *sql.Tx
	now func() time.Time
}

func (r *sqliteTxRepository) ListBoardsByOwner(context.Context, string) ([]Board, error) {
	return nil, ErrNotImplemented
}

func (r *sqliteTxRepository) GetBoard(ctx context.Context, ownerUserID, boardID string) (BoardDetails, error) {
	board, err := getOwnedBoard(ctx, r.tx, ownerUserID, boardID)
	if err != nil {
		return BoardDetails{}, err
	}

	columns, err := listColumnsForQuery(ctx, r.tx, boardID)
	if err != nil {
		return BoardDetails{}, err
	}

	tasks, err := listTasksForQuery(ctx, r.tx, boardID)
	if err != nil {
		return BoardDetails{}, err
	}

	return BoardDetails{Board: board, Columns: columns, Tasks: tasks}, nil
}

func (r *sqliteTxRepository) CreateBoard(context.Context, string, string) (Board, error) {
	return Board{}, ErrNotImplemented
}

func (r *sqliteTxRepository) UpdateBoardTitle(context.Context, string, string, string) (Board, error) {
	return Board{}, ErrNotImplemented
}

func (r *sqliteTxRepository) DeleteBoard(context.Context, string, string) error {
	return ErrNotImplemented
}

func (r *sqliteTxRepository) CreateColumn(ctx context.Context, ownerUserID, boardID, title string) (Column, Board, error) {
	board, err := getOwnedBoard(ctx, r.tx, ownerUserID, boardID)
	if err != nil {
		return Column{}, Board{}, err
	}

	position, err := nextPosition(ctx, r.tx, `SELECT COALESCE(MAX(position), -1) + 1 FROM columns WHERE board_id = ?`, boardID)
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

	if _, err := r.tx.ExecContext(
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

	board, err = bumpBoardTx(ctx, r.tx, board, r.now().UTC())
	if err != nil {
		return Column{}, Board{}, err
	}

	return column, board, nil
}

func (r *sqliteTxRepository) UpdateColumnTitle(context.Context, string, string, string, string) (Column, Board, error) {
	return Column{}, Board{}, ErrNotImplemented
}

func (r *sqliteTxRepository) ReorderColumns(context.Context, string, string, []string) (Board, error) {
	return Board{}, ErrNotImplemented
}

func (r *sqliteTxRepository) DeleteColumn(context.Context, string, string, string) (Board, error) {
	return Board{}, ErrNotImplemented
}

func (r *sqliteTxRepository) CreateTask(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (Task, Board, error) {
	return r.CreateTaskWithArchivedAt(ctx, ownerUserID, boardID, columnID, title, description, nil)
}

func (r *sqliteTxRepository) CreateTaskWithArchivedAt(ctx context.Context, ownerUserID, boardID, columnID, title, description string, archivedAt *time.Time) (Task, Board, error) {
	board, err := getOwnedBoard(ctx, r.tx, ownerUserID, boardID)
	if err != nil {
		return Task{}, Board{}, err
	}

	if _, err := getOwnedColumn(ctx, r.tx, ownerUserID, boardID, columnID); err != nil {
		return Task{}, Board{}, err
	}

	archivedFlag := 0
	archivedAtMS := any(nil)
	positionQuery := `SELECT COALESCE(MAX(position), -1) + 1 FROM tasks WHERE column_id = ? AND is_archived = 0`
	if archivedAt != nil {
		normalizedArchivedAt := fromUnixMillis(toUnixMillis(archivedAt.UTC()))
		archivedFlag = 1
		archivedAtMS = toUnixMillis(normalizedArchivedAt)
		positionQuery = `SELECT COALESCE(MAX(position), -1) + 1 FROM tasks WHERE column_id = ? AND is_archived = 1`
		archivedAt = &normalizedArchivedAt
	}

	position, err := nextPosition(ctx, r.tx, positionQuery, columnID)
	if err != nil {
		return Task{}, Board{}, err
	}

	now := r.now().UTC()
	task := Task{
		ID:          uuid.NewString(),
		BoardID:     boardID,
		ColumnID:    columnID,
		OwnerUserID: ownerUserID,
		Title:       title,
		Description: description,
		IsArchived:  archivedFlag == 1,
		Position:    position,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	if archivedAt != nil {
		task.ArchivedAt = archivedAt.UTC()
	}

	if _, err := r.tx.ExecContext(
		ctx,
		`INSERT INTO tasks (id, board_id, column_id, owner_user_id, title, description, is_archived, archived_at_ms, position, created_at_ms, updated_at_ms)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		task.ID,
		task.BoardID,
		task.ColumnID,
		task.OwnerUserID,
		task.Title,
		task.Description,
		task.IsArchived,
		archivedAtMS,
		task.Position,
		toUnixMillis(task.CreatedAt),
		toUnixMillis(task.UpdatedAt),
	); err != nil {
		return Task{}, Board{}, fmt.Errorf("create task: %w", err)
	}

	board, err = bumpBoardTx(ctx, r.tx, board, r.now().UTC())
	if err != nil {
		return Task{}, Board{}, err
	}

	return task, board, nil
}

func (r *sqliteTxRepository) UpdateTask(context.Context, string, string, string, string, string) (Task, Board, error) {
	return Task{}, Board{}, ErrNotImplemented
}

func (r *sqliteTxRepository) ReorderTasks(context.Context, string, string, []TaskColumnOrder) (Board, error) {
	return Board{}, ErrNotImplemented
}

func (r *sqliteTxRepository) DeleteTask(context.Context, string, string, string) (Board, error) {
	return Board{}, ErrNotImplemented
}
