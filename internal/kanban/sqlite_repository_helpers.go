package kanban

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

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

func getOwnedTask(ctx context.Context, q queryRower, ownerUserID, boardID, taskID string) (Task, error) {
	task, err := scanTask(q.QueryRowContext(
		ctx,
		`SELECT id, board_id, column_id, owner_user_id, title, description, position, created_at_ms, updated_at_ms
		 FROM tasks
		 WHERE id = ?`,
		taskID,
	).Scan)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Task{}, ErrNotFound
		}
		return Task{}, err
	}
	if task.BoardID != boardID {
		return Task{}, ErrNotFound
	}
	if task.OwnerUserID != ownerUserID {
		return Task{}, ErrForbidden
	}

	return task, nil
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

func scanTask(scan scannerFunc) (Task, error) {
	var task Task
	var createdAtMS int64
	var updatedAtMS int64

	if err := scan(
		&task.ID,
		&task.BoardID,
		&task.ColumnID,
		&task.OwnerUserID,
		&task.Title,
		&task.Description,
		&task.Position,
		&createdAtMS,
		&updatedAtMS,
	); err != nil {
		return Task{}, err
	}

	task.CreatedAt = fromUnixMillis(createdAtMS)
	task.UpdatedAt = fromUnixMillis(updatedAtMS)

	return task, nil
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

func reindexTasksTx(ctx context.Context, tx *sql.Tx, columnID string, now time.Time) error {
	rows, err := tx.QueryContext(ctx, `SELECT id FROM tasks WHERE column_id = ? ORDER BY position`, columnID)
	if err != nil {
		return fmt.Errorf("list tasks for reindex: %w", err)
	}
	defer rows.Close()

	ids := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return fmt.Errorf("scan task id: %w", err)
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate tasks for reindex: %w", err)
	}

	for i, id := range ids {
		if _, err := tx.ExecContext(
			ctx,
			`UPDATE tasks SET position = ?, updated_at_ms = ? WHERE id = ?`,
			i,
			toUnixMillis(now),
			id,
		); err != nil {
			return fmt.Errorf("update task position: %w", err)
		}
	}

	return nil
}

func taskIDsByColumnTx(ctx context.Context, tx *sql.Tx, columnID string) ([]string, error) {
	rows, err := tx.QueryContext(ctx, `SELECT id FROM tasks WHERE column_id = ? ORDER BY position`, columnID)
	if err != nil {
		return nil, fmt.Errorf("list task ids by column: %w", err)
	}
	defer rows.Close()

	ids := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("scan task id: %w", err)
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate task ids by column: %w", err)
	}

	return ids, nil
}

func applyTaskOrderTx(ctx context.Context, tx *sql.Tx, columnID string, taskIDs []string, now time.Time) error {
	for i, id := range taskIDs {
		if _, err := tx.ExecContext(
			ctx,
			`UPDATE tasks SET column_id = ?, position = ?, updated_at_ms = ? WHERE id = ?`,
			columnID,
			i,
			toUnixMillis(now),
			id,
		); err != nil {
			return fmt.Errorf("apply task order: %w", err)
		}
	}

	return nil
}

func bumpBoardTx(ctx context.Context, tx *sql.Tx, board Board, now time.Time) (Board, error) {
	board.BoardVersion++
	board.UpdatedAt = now.UTC()

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
