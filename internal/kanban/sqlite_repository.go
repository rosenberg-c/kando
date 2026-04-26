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
		`SELECT id, owner_user_id, title, archived_original_title, is_archived, board_version, created_at_ms, updated_at_ms
		 FROM boards
		 WHERE owner_user_id = ? AND is_archived = 0
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

func (r *SQLiteRepository) ListArchivedBoardsByOwner(ctx context.Context, ownerUserID string) ([]Board, error) {
	rows, err := r.db.QueryContext(
		ctx,
		`SELECT id, owner_user_id, title, archived_original_title, is_archived, board_version, created_at_ms, updated_at_ms
		 FROM boards
		 WHERE owner_user_id = ? AND is_archived = 1
		 ORDER BY updated_at_ms DESC`,
		ownerUserID,
	)
	if err != nil {
		return nil, fmt.Errorf("list archived boards: %w", err)
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
		return nil, fmt.Errorf("iterate archived boards: %w", err)
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

	tasks, err := r.listTasks(ctx, boardID)
	if err != nil {
		return BoardDetails{}, err
	}

	return BoardDetails{Board: board, Columns: columns, Tasks: tasks}, nil
}

func (r *SQLiteRepository) CreateBoard(ctx context.Context, ownerUserID, title string) (Board, error) {
	now := r.now().UTC()
	board := Board{
		ID:           uuid.NewString(),
		OwnerUserID:  ownerUserID,
		Title:        title,
		IsArchived:   false,
		BoardVersion: 1,
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	_, err := r.db.ExecContext(
		ctx,
		`INSERT INTO boards (id, owner_user_id, title, archived_original_title, is_archived, board_version, created_at_ms, updated_at_ms)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		board.ID,
		board.OwnerUserID,
		board.Title,
		nil,
		board.IsArchived,
		board.BoardVersion,
		toUnixMillis(board.CreatedAt),
		toUnixMillis(board.UpdatedAt),
	)
	if err != nil {
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

func (r *SQLiteRepository) ArchiveBoard(ctx context.Context, ownerUserID, boardID string) (Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}
	if board.IsArchived {
		if err := tx.Commit(); err != nil {
			return Board{}, fmt.Errorf("commit tx: %w", err)
		}
		return board, nil
	}

	now := r.now().UTC()
	board.IsArchived = true
	board.ArchivedOriginalTitle = board.Title
	board.Title = ArchivedBoardTitle(board.Title, now)
	board.BoardVersion++
	board.UpdatedAt = now

	if _, err := tx.ExecContext(
		ctx,
		`UPDATE boards SET title = ?, archived_original_title = ?, is_archived = 1, board_version = ?, updated_at_ms = ? WHERE id = ?`,
		board.Title,
		board.ArchivedOriginalTitle,
		board.BoardVersion,
		toUnixMillis(board.UpdatedAt),
		board.ID,
	); err != nil {
		return Board{}, fmt.Errorf("archive board: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return board, nil
}

func (r *SQLiteRepository) RestoreBoard(ctx context.Context, ownerUserID, boardID string, mode RestoreBoardTitleMode) (Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}
	if !board.IsArchived {
		if err := tx.Commit(); err != nil {
			return Board{}, fmt.Errorf("commit tx: %w", err)
		}
		return board, nil
	}

	desiredTitle := board.Title
	if mode == RestoreBoardTitleModeOriginal && board.ArchivedOriginalTitle != "" {
		desiredTitle = board.ArchivedOriginalTitle
	}
	if mode == RestoreBoardTitleModeOriginal {
		var conflictCount int
		if err := tx.QueryRowContext(
			ctx,
			`SELECT COUNT(*) FROM boards WHERE owner_user_id = ? AND is_archived = 0 AND title = ? AND id <> ?`,
			ownerUserID,
			desiredTitle,
			board.ID,
		).Scan(&conflictCount); err != nil {
			return Board{}, fmt.Errorf("check restore board title conflict: %w", err)
		}
		if conflictCount > 0 {
			return Board{}, NewConflictError(ConflictBoardTitleExists, "board title already exists")
		}
	}

	now := r.now().UTC()
	board.IsArchived = false
	board.Title = desiredTitle
	board.ArchivedOriginalTitle = ""
	board.BoardVersion++
	board.UpdatedAt = now

	if _, err := tx.ExecContext(
		ctx,
		`UPDATE boards SET title = ?, is_archived = 0, archived_original_title = NULL, board_version = ?, updated_at_ms = ? WHERE id = ?`,
		board.Title,
		board.BoardVersion,
		toUnixMillis(board.UpdatedAt),
		board.ID,
	); err != nil {
		return Board{}, fmt.Errorf("restore board: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return board, nil
}

func (r *SQLiteRepository) DeleteArchivedBoard(ctx context.Context, ownerUserID, boardID string) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return err
	}
	if !board.IsArchived {
		return ErrConflict
	}

	if _, err := tx.ExecContext(ctx, `DELETE FROM boards WHERE id = ?`, boardID); err != nil {
		return fmt.Errorf("delete archived board: %w", err)
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

func (r *SQLiteRepository) ReorderColumns(ctx context.Context, ownerUserID, boardID string, orderedColumnIDs []string) (Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	currentIDs, err := columnIDsByBoardTx(ctx, tx, boardID)
	if err != nil {
		return Board{}, err
	}
	if err := ValidateExactOrder(currentIDs, orderedColumnIDs); err != nil {
		return Board{}, err
	}

	now := r.now().UTC()
	if err := applyColumnOrderTx(ctx, tx, orderedColumnIDs, now); err != nil {
		return Board{}, err
	}

	board, err = bumpBoardTx(ctx, tx, board, now)
	if err != nil {
		return Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return board, nil
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

func (r *SQLiteRepository) CreateTask(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (Task, Board, error) {
	return r.CreateTaskWithArchivedAt(ctx, ownerUserID, boardID, columnID, title, description, nil)
}

func (r *SQLiteRepository) CreateTaskWithArchivedAt(ctx context.Context, ownerUserID, boardID, columnID, title, description string, archivedAt *time.Time) (Task, Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Task{}, Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Task{}, Board{}, err
	}

	if _, err := getOwnedColumn(ctx, tx, ownerUserID, boardID, columnID); err != nil {
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

	position, err := nextPosition(ctx, tx, positionQuery, columnID)
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

	if _, err := tx.ExecContext(
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

	board, err = bumpBoardTx(ctx, tx, board, r.now().UTC())
	if err != nil {
		return Task{}, Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Task{}, Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return task, board, nil
}

func (r *SQLiteRepository) ArchiveTasksInColumn(ctx context.Context, ownerUserID, boardID, columnID string) (ColumnTaskArchiveResult, Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return ColumnTaskArchiveResult{}, Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return ColumnTaskArchiveResult{}, Board{}, err
	}
	if _, err := getOwnedColumn(ctx, tx, ownerUserID, boardID, columnID); err != nil {
		return ColumnTaskArchiveResult{}, Board{}, err
	}

	archivedAt := fromUnixMillis(toUnixMillis(r.now().UTC()))
	result, err := tx.ExecContext(
		ctx,
		`UPDATE tasks
		 SET is_archived = 1, archived_at_ms = ?, updated_at_ms = ?
		 WHERE board_id = ? AND column_id = ? AND owner_user_id = ? AND is_archived = 0`,
		toUnixMillis(archivedAt),
		toUnixMillis(archivedAt),
		boardID,
		columnID,
		ownerUserID,
	)
	if err != nil {
		return ColumnTaskArchiveResult{}, Board{}, fmt.Errorf("archive tasks in column: %w", err)
	}

	if err := reindexTasksTx(ctx, tx, columnID, archivedAt); err != nil {
		return ColumnTaskArchiveResult{}, Board{}, err
	}

	board, err = bumpBoardTx(ctx, tx, board, archivedAt)
	if err != nil {
		return ColumnTaskArchiveResult{}, Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return ColumnTaskArchiveResult{}, Board{}, fmt.Errorf("commit tx: %w", err)
	}

	archivedCount, err := result.RowsAffected()
	if err != nil {
		return ColumnTaskArchiveResult{}, Board{}, fmt.Errorf("archive tasks in column: rows affected: %w", err)
	}

	return ColumnTaskArchiveResult{
		ArchivedTaskCount: int(archivedCount),
		ArchivedAt:        archivedAt,
	}, board, nil
}

func (r *SQLiteRepository) ListArchivedTasksByBoard(ctx context.Context, ownerUserID, boardID string) ([]Task, error) {
	if _, err := getOwnedBoard(ctx, r.db, ownerUserID, boardID); err != nil {
		return nil, err
	}

	rows, err := r.db.QueryContext(
		ctx,
		`SELECT t.id, t.board_id, t.column_id, t.owner_user_id, t.title, t.description, t.is_archived, t.archived_at_ms, t.position, t.created_at_ms, t.updated_at_ms
		 FROM tasks t
		 INNER JOIN columns c ON c.id = t.column_id
		 WHERE t.board_id = ? AND t.owner_user_id = ? AND t.is_archived = 1
		 ORDER BY c.position, t.archived_at_ms, t.position, t.id`,
		boardID,
		ownerUserID,
	)
	if err != nil {
		return nil, fmt.Errorf("list archived tasks: %w", err)
	}
	defer rows.Close()

	tasks := make([]Task, 0)
	for rows.Next() {
		task, scanErr := scanTask(rows.Scan)
		if scanErr != nil {
			return nil, scanErr
		}
		tasks = append(tasks, task)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate archived tasks: %w", err)
	}

	return tasks, nil
}

func (r *SQLiteRepository) RestoreArchivedTask(ctx context.Context, ownerUserID, boardID, taskID string) (Task, Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Task{}, Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Task{}, Board{}, err
	}

	task, err := getOwnedArchivedTask(ctx, tx, ownerUserID, boardID, taskID)
	if err != nil {
		return Task{}, Board{}, err
	}

	position, err := nextPosition(ctx, tx, `SELECT COALESCE(MAX(position), -1) + 1 FROM tasks WHERE column_id = ? AND is_archived = 0`, task.ColumnID)
	if err != nil {
		return Task{}, Board{}, err
	}

	now := r.now().UTC()
	task.IsArchived = false
	task.ArchivedAt = time.Time{}
	task.Position = position
	task.UpdatedAt = now

	if _, err := tx.ExecContext(
		ctx,
		`UPDATE tasks SET is_archived = 0, archived_at_ms = NULL, position = ?, updated_at_ms = ? WHERE id = ?`,
		task.Position,
		toUnixMillis(task.UpdatedAt),
		task.ID,
	); err != nil {
		return Task{}, Board{}, fmt.Errorf("restore archived task: %w", err)
	}

	board, err = bumpBoardTx(ctx, tx, board, now)
	if err != nil {
		return Task{}, Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Task{}, Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return task, board, nil
}

func (r *SQLiteRepository) DeleteArchivedTask(ctx context.Context, ownerUserID, boardID, taskID string) (Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	if _, err := getOwnedArchivedTask(ctx, tx, ownerUserID, boardID, taskID); err != nil {
		return Board{}, err
	}

	if _, err := tx.ExecContext(ctx, `DELETE FROM tasks WHERE id = ?`, taskID); err != nil {
		return Board{}, fmt.Errorf("delete archived task: %w", err)
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

func (r *SQLiteRepository) UpdateTask(ctx context.Context, ownerUserID, boardID, taskID, title, description string) (Task, Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Task{}, Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Task{}, Board{}, err
	}

	task, err := getOwnedTask(ctx, tx, ownerUserID, boardID, taskID)
	if err != nil {
		return Task{}, Board{}, err
	}

	task.Title = title
	task.Description = description
	task.UpdatedAt = r.now().UTC()

	if _, err := tx.ExecContext(
		ctx,
		`UPDATE tasks SET title = ?, description = ?, updated_at_ms = ? WHERE id = ?`,
		task.Title,
		task.Description,
		toUnixMillis(task.UpdatedAt),
		task.ID,
	); err != nil {
		return Task{}, Board{}, fmt.Errorf("update task: %w", err)
	}

	board, err = bumpBoardTx(ctx, tx, board, r.now().UTC())
	if err != nil {
		return Task{}, Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Task{}, Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return task, board, nil
}

func (r *SQLiteRepository) ReorderTasks(ctx context.Context, ownerUserID, boardID string, orderedTasksByColumn []TaskColumnOrder) (Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	currentColumnIDs, err := columnIDsByBoardTx(ctx, tx, boardID)
	if err != nil {
		return Board{}, err
	}
	candidateColumnIDs := make([]string, 0, len(orderedTasksByColumn))
	for _, columnOrder := range orderedTasksByColumn {
		candidateColumnIDs = append(candidateColumnIDs, columnOrder.ColumnID)
	}
	if err := ValidateExactOrder(currentColumnIDs, candidateColumnIDs); err != nil {
		return Board{}, err
	}

	currentTaskIDs, err := taskIDsByBoardTx(ctx, tx, boardID)
	if err != nil {
		return Board{}, err
	}
	candidateTaskIDs := make([]string, 0)
	for _, columnOrder := range orderedTasksByColumn {
		for _, taskID := range columnOrder.TaskIDs {
			task, err := getOwnedTask(ctx, tx, ownerUserID, boardID, taskID)
			if err != nil {
				if err == ErrNotFound || err == ErrForbidden {
					return Board{}, ErrInvalidInput
				}
				return Board{}, err
			}
			if task.BoardID != boardID {
				return Board{}, ErrInvalidInput
			}
			candidateTaskIDs = append(candidateTaskIDs, taskID)
		}
	}
	if err := ValidateExactOrder(currentTaskIDs, candidateTaskIDs); err != nil {
		return Board{}, err
	}

	now := r.now().UTC()
	for _, columnOrder := range orderedTasksByColumn {
		if err := applyTaskOrderTx(ctx, tx, columnOrder.ColumnID, columnOrder.TaskIDs, now); err != nil {
			return Board{}, err
		}
	}

	board, err = bumpBoardTx(ctx, tx, board, now)
	if err != nil {
		return Board{}, err
	}

	if err := tx.Commit(); err != nil {
		return Board{}, fmt.Errorf("commit tx: %w", err)
	}

	return board, nil
}

func (r *SQLiteRepository) DeleteTask(ctx context.Context, ownerUserID, boardID, taskID string) (Board, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return Board{}, fmt.Errorf("begin tx: %w", err)
	}
	defer rollback(tx)

	board, err := getOwnedBoard(ctx, tx, ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	task, err := getOwnedTask(ctx, tx, ownerUserID, boardID, taskID)
	if err != nil {
		return Board{}, err
	}

	if _, err := tx.ExecContext(ctx, `DELETE FROM tasks WHERE id = ?`, taskID); err != nil {
		return Board{}, fmt.Errorf("delete task: %w", err)
	}

	if err := reindexTasksTx(ctx, tx, task.ColumnID, r.now().UTC()); err != nil {
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
	return listColumnsForQuery(ctx, r.db, boardID)
}

func (r *SQLiteRepository) listTasks(ctx context.Context, boardID string) ([]Task, error) {
	return listTasksForQuery(ctx, r.db, boardID)
}
