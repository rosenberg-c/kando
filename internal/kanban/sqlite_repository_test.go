package kanban

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
)

func TestSQLiteRepositoryCRUDAndReindex(t *testing.T) {
	// Requirements: COL-002, COL-004, TODO-002, TODO-003, TODO-004
	t.Parallel()

	ctx := context.Background()
	repo := newTestSQLiteRepository(t)

	board, err := repo.CreateBoardIfAbsent(ctx, "user-1", "Main")
	if err != nil {
		t.Fatalf("create board: %v", err)
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

func TestSQLiteRepositoryOwnershipEnforcement(t *testing.T) {
	// Requirement: API-003
	t.Parallel()

	ctx := context.Background()
	repo := newTestSQLiteRepository(t)

	board, err := repo.CreateBoardIfAbsent(ctx, "owner", "Main")
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

func TestSQLiteRepositoryGetBoardTodoOrderFollowsColumnPosition(t *testing.T) {
	ctx := context.Background()
	repo := newTestSQLiteRepository(t)

	board, err := repo.CreateBoardIfAbsent(ctx, "owner", "Main")
	if err != nil {
		t.Fatalf("create board: %v", err)
	}

	columnA, _, err := repo.CreateColumn(ctx, "owner", board.ID, "A")
	if err != nil {
		t.Fatalf("create column A: %v", err)
	}
	columnB, _, err := repo.CreateColumn(ctx, "owner", board.ID, "B")
	if err != nil {
		t.Fatalf("create column B: %v", err)
	}

	if _, _, err := repo.CreateTodo(ctx, "owner", board.ID, columnB.ID, "B0", ""); err != nil {
		t.Fatalf("create todo in column B: %v", err)
	}
	if _, _, err := repo.CreateTodo(ctx, "owner", board.ID, columnA.ID, "A0", ""); err != nil {
		t.Fatalf("create todo in column A: %v", err)
	}

	details, err := repo.GetBoard(ctx, "owner", board.ID)
	if err != nil {
		t.Fatalf("get board: %v", err)
	}

	if len(details.Todos) != 2 {
		t.Fatalf("todo count = %d, want 2", len(details.Todos))
	}
	if details.Todos[0].ColumnID != columnA.ID {
		t.Fatalf("first todo column = %q, want %q", details.Todos[0].ColumnID, columnA.ID)
	}
	if details.Todos[1].ColumnID != columnB.ID {
		t.Fatalf("second todo column = %q, want %q", details.Todos[1].ColumnID, columnB.ID)
	}
}

func newTestSQLiteRepository(t *testing.T) *SQLiteRepository {
	t.Helper()

	repo, err := NewSQLiteRepository(filepath.Join(t.TempDir(), "kanban-test.db"))
	if err != nil {
		t.Fatalf("new sqlite repository: %v", err)
	}
	t.Cleanup(func() {
		if closeErr := repo.Close(); closeErr != nil {
			t.Fatalf("close sqlite repository: %v", closeErr)
		}
	})

	return repo
}
