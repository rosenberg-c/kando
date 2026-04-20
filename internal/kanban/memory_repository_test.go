package kanban

import (
	"context"
	"errors"
	"testing"
)

func TestMemoryRepositoryCRUDAndReindex(t *testing.T) {
	// Requirements: COL-002, COL-004, TODO-002, TODO-003, TODO-004
	t.Parallel()

	ctx := context.Background()
	repo := NewMemoryRepository()

	board, err := repo.CreateBoard(ctx, "user-1", "Main")
	if err != nil {
		t.Fatalf("create board: %v", err)
	}

	if _, err := repo.CreateBoard(ctx, "user-1", "Second"); !errors.Is(err, ErrConflict) {
		t.Fatalf("create second board err = %v, want ErrConflict", err)
	}

	updatedBoard, err := repo.UpdateBoardTitle(ctx, "user-1", board.ID, "Main Updated")
	if err != nil {
		t.Fatalf("update board title: %v", err)
	}
	if updatedBoard.Title != "Main Updated" {
		t.Fatalf("board title = %q, want %q", updatedBoard.Title, "Main Updated")
	}

	columnA, _, err := repo.CreateColumn(ctx, "user-1", board.ID, "A")
	if err != nil {
		t.Fatalf("create column A: %v", err)
	}
	columnB, _, err := repo.CreateColumn(ctx, "user-1", board.ID, "B")
	if err != nil {
		t.Fatalf("create column B: %v", err)
	}

	if _, _, err := repo.UpdateColumnTitle(ctx, "user-1", board.ID, columnA.ID, "A Updated"); err != nil {
		t.Fatalf("update column title: %v", err)
	}

	todoA0, _, err := repo.CreateTodo(ctx, "user-1", board.ID, columnA.ID, "A0", "desc")
	if err != nil {
		t.Fatalf("create todo A0: %v", err)
	}
	todoA1, _, err := repo.CreateTodo(ctx, "user-1", board.ID, columnA.ID, "A1", "desc")
	if err != nil {
		t.Fatalf("create todo A1: %v", err)
	}

	if _, _, err := repo.UpdateTodo(ctx, "user-1", board.ID, todoA0.ID, "A0 Updated", "new"); err != nil {
		t.Fatalf("update todo: %v", err)
	}

	if _, err := repo.DeleteTodo(ctx, "user-1", board.ID, todoA0.ID); err != nil {
		t.Fatalf("delete todo A0: %v", err)
	}

	details, err := repo.GetBoard(ctx, "user-1", board.ID)
	if err != nil {
		t.Fatalf("get board after todo delete: %v", err)
	}

	var foundTodoA1 *Todo
	for i := range details.Todos {
		if details.Todos[i].ID == todoA1.ID {
			foundTodoA1 = &details.Todos[i]
			break
		}
	}
	if foundTodoA1 == nil {
		t.Fatalf("expected todo %q to remain", todoA1.ID)
	}
	if foundTodoA1.Position != 0 {
		t.Fatalf("todo position = %d, want 0 after reindex", foundTodoA1.Position)
	}

	if _, err := repo.DeleteTodo(ctx, "user-1", board.ID, todoA1.ID); err != nil {
		t.Fatalf("delete todo A1: %v", err)
	}

	if _, err := repo.DeleteColumn(ctx, "user-1", board.ID, columnA.ID); err != nil {
		t.Fatalf("delete column A: %v", err)
	}

	details, err = repo.GetBoard(ctx, "user-1", board.ID)
	if err != nil {
		t.Fatalf("get board after column delete: %v", err)
	}

	var foundColumnB *Column
	for i := range details.Columns {
		if details.Columns[i].ID == columnB.ID {
			foundColumnB = &details.Columns[i]
			break
		}
	}
	if foundColumnB == nil {
		t.Fatalf("expected column %q to remain", columnB.ID)
	}
	if foundColumnB.Position != 0 {
		t.Fatalf("column position = %d, want 0 after reindex", foundColumnB.Position)
	}

	if err := repo.DeleteBoard(ctx, "user-1", board.ID); err != nil {
		t.Fatalf("delete board: %v", err)
	}

	if _, err := repo.GetBoard(ctx, "user-1", board.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("get deleted board err = %v, want ErrNotFound", err)
	}
}

func TestMemoryRepositoryOwnershipEnforcement(t *testing.T) {
	// Requirement: API-003
	t.Parallel()

	ctx := context.Background()
	repo := NewMemoryRepository()

	board, err := repo.CreateBoard(ctx, "owner", "Main")
	if err != nil {
		t.Fatalf("create board: %v", err)
	}

	if _, err := repo.GetBoard(ctx, "intruder", board.ID); !errors.Is(err, ErrForbidden) {
		t.Fatalf("get board err = %v, want ErrForbidden", err)
	}

	column, _, err := repo.CreateColumn(ctx, "owner", board.ID, "Backlog")
	if err != nil {
		t.Fatalf("create column: %v", err)
	}

	if _, _, err := repo.UpdateColumnTitle(ctx, "intruder", board.ID, column.ID, "Oops"); !errors.Is(err, ErrForbidden) {
		t.Fatalf("update column err = %v, want ErrForbidden", err)
	}

	todo, _, err := repo.CreateTodo(ctx, "owner", board.ID, column.ID, "Task", "")
	if err != nil {
		t.Fatalf("create todo: %v", err)
	}

	if _, err := repo.DeleteTodo(ctx, "intruder", board.ID, todo.ID); !errors.Is(err, ErrForbidden) {
		t.Fatalf("delete todo err = %v, want ErrForbidden", err)
	}
}
