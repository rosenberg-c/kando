package kanban

import (
	"context"
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"
)

// MemoryRepository is an in-memory repository suitable for local development.
type MemoryRepository struct {
	mu sync.RWMutex

	boards  map[string]Board
	columns map[string]Column
	todos   map[string]Todo

	ownerBoards  map[string][]string
	boardColumns map[string][]string
	columnTodos  map[string][]string

	now func() time.Time
}

func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{
		boards:       make(map[string]Board),
		columns:      make(map[string]Column),
		todos:        make(map[string]Todo),
		ownerBoards:  make(map[string][]string),
		boardColumns: make(map[string][]string),
		columnTodos:  make(map[string][]string),
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
		if ok {
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
	todos := make([]Todo, 0)
	for _, columnID := range columnIDs {
		column, ok := r.columns[columnID]
		if !ok {
			continue
		}
		columns = append(columns, column)
		for _, todoID := range r.columnTodos[columnID] {
			todo, ok := r.todos[todoID]
			if ok {
				todos = append(todos, todo)
			}
		}
	}

	return BoardDetails{Board: board, Columns: columns, Todos: todos}, nil
}

func (r *MemoryRepository) CreateBoardIfAbsent(_ context.Context, ownerUserID, title string) (Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if len(r.ownerBoards[ownerUserID]) > 0 {
		return Board{}, fmt.Errorf("single board per user: %w", ErrConflict)
	}
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
		for _, todoID := range r.columnTodos[columnID] {
			delete(r.todos, todoID)
		}
		delete(r.columnTodos, columnID)
		delete(r.columns, columnID)
	}
	delete(r.boardColumns, board.ID)
	delete(r.boards, board.ID)
	r.ownerBoards[ownerUserID] = removeID(r.ownerBoards[ownerUserID], board.ID)
	return nil
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
	r.columnTodos[column.ID] = nil

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

	for _, todoID := range r.columnTodos[columnID] {
		delete(r.todos, todoID)
	}

	delete(r.columnTodos, columnID)
	delete(r.columns, columnID)
	r.boardColumns[boardID] = removeID(r.boardColumns[boardID], columnID)
	r.reindexColumns(boardID)

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return board, nil
}

func (r *MemoryRepository) CreateTodo(_ context.Context, ownerUserID, boardID, columnID, title, description string) (Todo, Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Todo{}, Board{}, err
	}

	column, ok := r.columns[columnID]
	if !ok || column.BoardID != boardID {
		return Todo{}, Board{}, ErrNotFound
	}

	position := len(r.columnTodos[columnID])
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
	r.todos[todo.ID] = todo
	r.columnTodos[columnID] = append(r.columnTodos[columnID], todo.ID)

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return todo, board, nil
}

func (r *MemoryRepository) UpdateTodo(_ context.Context, ownerUserID, boardID, todoID, title, description string) (Todo, Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Todo{}, Board{}, err
	}

	todo, ok := r.todos[todoID]
	if !ok || todo.BoardID != boardID {
		return Todo{}, Board{}, ErrNotFound
	}
	if todo.OwnerUserID != ownerUserID {
		return Todo{}, Board{}, ErrForbidden
	}

	todo.Title = title
	todo.Description = description
	todo.UpdatedAt = r.now().UTC()
	r.todos[todo.ID] = todo

	board = bumpBoard(board)
	r.boards[board.ID] = board
	return todo, board, nil
}

func (r *MemoryRepository) DeleteTodo(_ context.Context, ownerUserID, boardID, todoID string) (Board, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	board, err := r.getOwnedBoard(ownerUserID, boardID)
	if err != nil {
		return Board{}, err
	}

	todo, ok := r.todos[todoID]
	if !ok || todo.BoardID != boardID {
		return Board{}, ErrNotFound
	}
	if todo.OwnerUserID != ownerUserID {
		return Board{}, ErrForbidden
	}

	delete(r.todos, todoID)
	r.columnTodos[todo.ColumnID] = removeID(r.columnTodos[todo.ColumnID], todoID)
	r.reindexTodos(todo.ColumnID)

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

func (r *MemoryRepository) reindexTodos(columnID string) {
	now := r.now().UTC()
	for i, id := range r.columnTodos[columnID] {
		todo, ok := r.todos[id]
		if !ok {
			continue
		}
		todo.Position = i
		todo.UpdatedAt = now
		r.todos[id] = todo
	}
}

func removeID(items []string, remove string) []string {
	for i, item := range items {
		if item == remove {
			return append(items[:i], items[i+1:]...)
		}
	}
	return items
}

func bumpBoard(board Board) Board {
	board.BoardVersion++
	board.UpdatedAt = time.Now().UTC()
	return board
}
