package kanban

import (
	"context"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"

	"go_macos_todo/internal/sliceutil"
)

// MemoryRepository is an in-memory repository suitable for local development.
type MemoryRepository struct {
	mu sync.RWMutex

	boards  map[string]Board
	columns map[string]Column
	tasks   map[string]Task

	ownerBoards  map[string][]string
	boardColumns map[string][]string
	columnTasks  map[string][]string

	now func() time.Time
}

func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{
		boards:       make(map[string]Board),
		columns:      make(map[string]Column),
		tasks:        make(map[string]Task),
		ownerBoards:  make(map[string][]string),
		boardColumns: make(map[string][]string),
		columnTasks:  make(map[string][]string),
		now:          time.Now,
	}
}

func (r *MemoryRepository) ListBoardsByOwner(_ context.Context, ownerUserID string) ([]Board, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	ids := r.ownerBoards[ownerUserID]
	out := make([]Board, 0, len(ids))
	for _, id := range ids {
		board, ok := r.boards[id]
		if ok && !board.IsArchived {
			out = append(out, board)
		}
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].UpdatedAt.After(out[j].UpdatedAt)
	})
	return out, nil
}

func (r *MemoryRepository) ListArchivedBoardsByOwner(_ context.Context, ownerUserID string) ([]Board, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	ids := r.ownerBoards[ownerUserID]
	out := make([]Board, 0, len(ids))
	for _, id := range ids {
		board, ok := r.boards[id]
		if ok && board.IsArchived {
			out = append(out, board)
		}
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].UpdatedAt.After(out[j].UpdatedAt)
	})
	return out, nil
}

func (r *MemoryRepository) GetBoard(_ context.Context, ownerUserID, boardID string) (BoardDetails, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return BoardDetails{}, err
	}

	columnIDs := r.boardColumns[boardID]
	columns := make([]Column, 0, len(columnIDs))
	tasks := make([]Task, 0)
	for _, columnID := range columnIDs {
		column, ok := r.columns[columnID]
		if !ok {
			continue
		}
		columns = append(columns, column)
		for _, taskID := range r.columnTasks[columnID] {
			task, ok := r.tasks[taskID]
			if ok {
				tasks = append(tasks, task)
			}
		}
	}

	return BoardDetails{Board: board, Columns: columns, Tasks: tasks}, nil
}

func (r *MemoryRepository) CreateBoard(_ context.Context, ownerUserID, title string) (Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.createBoardLocked(ownerUserID, title), nil
}

func (r *MemoryRepository) createBoardLocked(ownerUserID, title string) Board {
	now := r.now().UTC()
	board := Board{
		ID:           uuid.NewString(),
		OwnerUserID:  ownerUserID,
		Title:        title,
		BoardVersion: 1,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	r.boards[board.ID] = board
	r.ownerBoards[ownerUserID] = append(r.ownerBoards[ownerUserID], board.ID)
	r.boardColumns[board.ID] = nil
	return board
}

func (r *MemoryRepository) UpdateBoardTitle(_ context.Context, ownerUserID, boardID, title string) (Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	board.Title = title
	board = bumpBoard(board)
	r.boards[board.ID] = board
	return board, nil
}

func (r *MemoryRepository) DeleteBoard(_ context.Context, ownerUserID, boardID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return err
	}

	for _, columnID := range r.boardColumns[board.ID] {
		for _, taskID := range r.columnTasks[columnID] {
			delete(r.tasks, taskID)
		}
		delete(r.columnTasks, columnID)
		delete(r.columns, columnID)
	}
	delete(r.boardColumns, board.ID)
	delete(r.boards, board.ID)
	r.ownerBoards[ownerUserID] = sliceutil.RemoveString(r.ownerBoards[ownerUserID], board.ID)
	return nil
}

func (r *MemoryRepository) ArchiveBoard(_ context.Context, ownerUserID, boardID string) (Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}
	if board.IsArchived {
		return board, nil
	}

	board.IsArchived = true
	board.ArchivedOriginalTitle = board.Title
	board.Title = ArchivedBoardTitle(board.Title, r.now())
	board = bumpBoard(board)
	r.boards[board.ID] = board
	return board, nil
}

func (r *MemoryRepository) RestoreBoard(_ context.Context, ownerUserID, boardID string, mode RestoreBoardTitleMode) (Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}
	if !board.IsArchived {
		return board, nil
	}
	desiredTitle := board.Title
	if mode == RestoreBoardTitleModeOriginal && board.ArchivedOriginalTitle != "" {
		desiredTitle = board.ArchivedOriginalTitle
	}
	if mode == RestoreBoardTitleModeOriginal && r.hasActiveBoardWithTitle(ownerUserID, board.ID, desiredTitle) {
		return Board{}, NewConflictError(ConflictBoardTitleExists, "board title already exists")
	}

	board.IsArchived = false
	board.Title = desiredTitle
	board.ArchivedOriginalTitle = ""
	board = bumpBoard(board)
	r.boards[board.ID] = board
	return board, nil
}

func (r *MemoryRepository) hasActiveBoardWithTitle(ownerUserID, ignoreBoardID, title string) bool {
	for _, id := range r.ownerBoards[ownerUserID] {
		if id == ignoreBoardID {
			continue
		}
		board, ok := r.boards[id]
		if !ok || board.IsArchived {
			continue
		}
		if board.Title == title {
			return true
		}
	}

	return false
}

func (r *MemoryRepository) DeleteArchivedBoard(ctx context.Context, ownerUserID, boardID string) error {
	r.mu.RLock()
	board, err := r.getOwnedBoard(ownerUserID, boardID)
	r.mu.RUnlock()
	if err != nil {
		return err
	}
	if !board.IsArchived {
		return ErrConflict
	}
	return r.DeleteBoard(ctx, ownerUserID, boardID)
}

func (r *MemoryRepository) CreateColumn(_ context.Context, ownerUserID, boardID, title string) (Column, Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Column{}, Board{}, err
	}

	position := len(r.boardColumns[board.ID])
	now := r.now().UTC()
	column := Column{
		ID:          uuid.NewString(),
		BoardID:     board.ID,
		OwnerUserID: ownerUserID,
		Title:       title,
		Position:    position,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	r.columns[column.ID] = column
	r.boardColumns[board.ID] = append(r.boardColumns[board.ID], column.ID)
	r.columnTasks[column.ID] = nil

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return column, board, nil
}

func (r *MemoryRepository) UpdateColumnTitle(_ context.Context, ownerUserID, boardID, columnID, title string) (Column, Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Column{}, Board{}, err
	}

	column, ok := r.columns[columnID]
	if !ok || column.BoardID != boardID {
		return Column{}, Board{}, ErrNotFound
	}
	if column.OwnerUserID != ownerUserID {
		return Column{}, Board{}, ErrForbidden
	}

	column.Title = title
	column.UpdatedAt = r.now().UTC()
	r.columns[column.ID] = column

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return column, board, nil
}

func (r *MemoryRepository) ReorderColumns(_ context.Context, ownerUserID, boardID string, orderedColumnIDs []string) (Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	currentIDs := r.boardColumns[boardID]
	if err := ValidateExactOrder(currentIDs, orderedColumnIDs); err != nil {
		return Board{}, err
	}

	r.boardColumns[boardID] = append([]string(nil), orderedColumnIDs...)
	r.reindexColumns(boardID)

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return board, nil
}

func (r *MemoryRepository) DeleteColumn(_ context.Context, ownerUserID, boardID, columnID string) (Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	column, ok := r.columns[columnID]
	if !ok || column.BoardID != boardID {
		return Board{}, ErrNotFound
	}
	if column.OwnerUserID != ownerUserID {
		return Board{}, ErrForbidden
	}

	for _, taskID := range r.columnTasks[columnID] {
		delete(r.tasks, taskID)
	}

	delete(r.columnTasks, columnID)
	delete(r.columns, columnID)
	r.boardColumns[boardID] = sliceutil.RemoveString(r.boardColumns[boardID], columnID)
	r.reindexColumns(boardID)

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return board, nil
}

func (r *MemoryRepository) CreateTask(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (Task, Board, error) {
	return r.CreateTaskWithArchivedAt(ctx, ownerUserID, boardID, columnID, title, description, nil)
}

func (r *MemoryRepository) CreateTaskWithArchivedAt(_ context.Context, ownerUserID, boardID, columnID, title, description string, archivedAt *time.Time) (Task, Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Task{}, Board{}, err
	}

	column, ok := r.columns[columnID]
	if !ok || column.BoardID != boardID {
		return Task{}, Board{}, ErrNotFound
	}

	position := len(r.columnTasks[columnID])
	isArchived := archivedAt != nil
	archivedTimestamp := time.Time{}
	if archivedAt != nil {
		archivedTimestamp = archivedAt.UTC().Truncate(time.Millisecond)
		position = r.nextArchivedPosition(columnID)
	}
	now := r.now().UTC()
	task := Task{
		ID:          uuid.NewString(),
		BoardID:     boardID,
		ColumnID:    columnID,
		OwnerUserID: ownerUserID,
		Title:       title,
		Description: description,
		IsArchived:  isArchived,
		ArchivedAt:  archivedTimestamp,
		Position:    position,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	r.tasks[task.ID] = task
	if !task.IsArchived {
		r.columnTasks[columnID] = append(r.columnTasks[columnID], task.ID)
	}

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return task, board, nil
}

func (r *MemoryRepository) ArchiveTasksInColumn(_ context.Context, ownerUserID, boardID, columnID string) (ColumnTaskArchiveResult, Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return ColumnTaskArchiveResult{}, Board{}, err
	}

	column, ok := r.columns[columnID]
	if !ok || column.BoardID != boardID {
		return ColumnTaskArchiveResult{}, Board{}, ErrNotFound
	}
	if column.OwnerUserID != ownerUserID {
		return ColumnTaskArchiveResult{}, Board{}, ErrForbidden
	}

	archivedAt := r.now().UTC().Truncate(time.Millisecond)
	archivedCount := 0
	for _, taskID := range r.columnTasks[columnID] {
		task, ok := r.tasks[taskID]
		if !ok || task.IsArchived {
			continue
		}
		task.IsArchived = true
		task.ArchivedAt = archivedAt
		task.UpdatedAt = archivedAt
		r.tasks[taskID] = task
		archivedCount++
	}
	r.columnTasks[columnID] = nil

	board = bumpBoard(board)
	r.boards[board.ID] = board

	return ColumnTaskArchiveResult{
		ArchivedTaskCount: archivedCount,
		ArchivedAt:        archivedAt,
	}, board, nil
}

func (r *MemoryRepository) ListArchivedTasksByBoard(_ context.Context, ownerUserID, boardID string) ([]Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if _, err := r.getOwnedBoard(ownerUserID, boardID); err != nil {
		return nil, err
	}

	columnPosition := make(map[string]int, len(r.boardColumns[boardID]))
	for position, id := range r.boardColumns[boardID] {
		columnPosition[id] = position
	}

	archived := make([]Task, 0)
	for _, task := range r.tasks {
		if task.BoardID != boardID || !task.IsArchived {
			continue
		}
		archived = append(archived, task)
	}

	sort.Slice(archived, func(i, j int) bool {
		leftColumn := columnPosition[archived[i].ColumnID]
		rightColumn := columnPosition[archived[j].ColumnID]
		if leftColumn != rightColumn {
			return leftColumn < rightColumn
		}
		if !archived[i].ArchivedAt.Equal(archived[j].ArchivedAt) {
			return archived[i].ArchivedAt.Before(archived[j].ArchivedAt)
		}
		if archived[i].Position != archived[j].Position {
			return archived[i].Position < archived[j].Position
		}
		return archived[i].ID < archived[j].ID
	})

	return archived, nil
}

func (r *MemoryRepository) RestoreArchivedTask(_ context.Context, ownerUserID, boardID, taskID string) (Task, Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Task{}, Board{}, err
	}

	task, ok := r.tasks[taskID]
	if !ok || task.BoardID != boardID {
		return Task{}, Board{}, ErrNotFound
	}
	if task.OwnerUserID != ownerUserID {
		return Task{}, Board{}, ErrForbidden
	}
	if !task.IsArchived {
		return Task{}, Board{}, ErrConflict
	}

	task.IsArchived = false
	task.ArchivedAt = time.Time{}
	task.Position = len(r.columnTasks[task.ColumnID])
	task.UpdatedAt = r.now().UTC()
	r.tasks[taskID] = task
	r.columnTasks[task.ColumnID] = append(r.columnTasks[task.ColumnID], taskID)

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return task, board, nil
}

func (r *MemoryRepository) DeleteArchivedTask(_ context.Context, ownerUserID, boardID, taskID string) (Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	task, ok := r.tasks[taskID]
	if !ok || task.BoardID != boardID {
		return Board{}, ErrNotFound
	}
	if task.OwnerUserID != ownerUserID {
		return Board{}, ErrForbidden
	}
	if !task.IsArchived {
		return Board{}, ErrConflict
	}

	delete(r.tasks, taskID)

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return board, nil
}

func (r *MemoryRepository) UpdateTask(_ context.Context, ownerUserID, boardID, taskID, title, description string) (Task, Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Task{}, Board{}, err
	}

	task, ok := r.tasks[taskID]
	if !ok || task.BoardID != boardID {
		return Task{}, Board{}, ErrNotFound
	}
	if task.IsArchived {
		return Task{}, Board{}, ErrNotFound
	}
	if task.OwnerUserID != ownerUserID {
		return Task{}, Board{}, ErrForbidden
	}

	task.Title = title
	task.Description = description
	task.UpdatedAt = r.now().UTC()
	r.tasks[task.ID] = task

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return task, board, nil
}

func (r *MemoryRepository) ReorderTasks(_ context.Context, ownerUserID, boardID string, orderedTasksByColumn []TaskColumnOrder) (Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	currentColumnIDs := r.boardColumns[boardID]
	candidateColumnIDs := make([]string, 0, len(orderedTasksByColumn))
	for _, columnOrder := range orderedTasksByColumn {
		candidateColumnIDs = append(candidateColumnIDs, columnOrder.ColumnID)
	}
	if err := ValidateExactOrder(currentColumnIDs, candidateColumnIDs); err != nil {
		return Board{}, err
	}

	currentTaskIDs := make([]string, 0)
	for _, columnID := range currentColumnIDs {
		currentTaskIDs = append(currentTaskIDs, r.columnTasks[columnID]...)
	}

	candidateTaskIDs := make([]string, 0)
	for _, columnOrder := range orderedTasksByColumn {
		for _, taskID := range columnOrder.TaskIDs {
			task, ok := r.tasks[taskID]
			if !ok || task.BoardID != boardID {
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
		r.columnTasks[columnOrder.ColumnID] = append([]string(nil), columnOrder.TaskIDs...)
		for position, taskID := range columnOrder.TaskIDs {
			task := r.tasks[taskID]
			task.ColumnID = columnOrder.ColumnID
			task.Position = position
			task.UpdatedAt = now
			r.tasks[taskID] = task
		}
	}

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return board, nil
}

func (r *MemoryRepository) DeleteTask(_ context.Context, ownerUserID, boardID, taskID string) (Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	task, ok := r.tasks[taskID]
	if !ok || task.BoardID != boardID {
		return Board{}, ErrNotFound
	}
	if task.IsArchived {
		return Board{}, ErrNotFound
	}
	if task.OwnerUserID != ownerUserID {
		return Board{}, ErrForbidden
	}

	delete(r.tasks, taskID)
	r.columnTasks[task.ColumnID] = sliceutil.RemoveString(r.columnTasks[task.ColumnID], taskID)
	r.reindexTasks(task.ColumnID)

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return board, nil
}

func (r *MemoryRepository) getOwnedBoard(ownerUserID, boardID string) (Board, error) {
	board, ok := r.boards[boardID]
	if !ok {
		return Board{}, ErrNotFound
	}
	if board.OwnerUserID != ownerUserID {
		return Board{}, ErrForbidden
	}
	return board, nil
}

func (r *MemoryRepository) reindexColumns(boardID string) {
	now := r.now().UTC()
	for i, id := range r.boardColumns[boardID] {
		column, ok := r.columns[id]
		if !ok {
			continue
		}
		column.Position = i
		column.UpdatedAt = now
		r.columns[id] = column
	}
}

func (r *MemoryRepository) reindexTasks(columnID string) {
	now := r.now().UTC()
	for i, id := range r.columnTasks[columnID] {
		task, ok := r.tasks[id]
		if !ok {
			continue
		}
		task.Position = i
		task.UpdatedAt = now
		r.tasks[id] = task
	}
}

func (r *MemoryRepository) nextArchivedPosition(columnID string) int {
	maxPosition := -1
	for _, task := range r.tasks {
		if task.ColumnID == columnID && task.IsArchived && task.Position > maxPosition {
			maxPosition = task.Position
		}
	}
	return maxPosition + 1
}

func bumpBoard(board Board) Board {
	board.BoardVersion++
	board.UpdatedAt = time.Now().UTC()
	return board
}
