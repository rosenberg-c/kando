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
