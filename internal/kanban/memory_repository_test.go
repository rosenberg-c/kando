package kanban

import (
	"context"
	"errors"
	"testing"
)

func TestMemoryRepositoryCRUDAndReindex(t *testing.T) {
	// Requirements: COL-002, COL-003, COL-004, TASK-002, TASK-003, TASK-004, TASK-005, TASK-006, TASK-007
	t.Parallel()

	ctx := context.Background()
	repo := NewMemoryRepository()

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

	taskA0, _, err := repo.CreateTask(ctx, "user-1", board.ID, columnA.ID, "A0", "desc")
	if err != nil {
		t.Fatalf("create task A0: %v", err)
	}
	taskA1, _, err := repo.CreateTask(ctx, "user-1", board.ID, columnA.ID, "A1", "desc")
	if err != nil {
		t.Fatalf("create task A1: %v", err)
	}
	taskB0, _, err := repo.CreateTask(ctx, "user-1", board.ID, columnB.ID, "B0", "desc")
	if err != nil {
		t.Fatalf("create task B0: %v", err)
	}

	if _, err := repo.ReorderTasks(ctx, "user-1", board.ID, []TaskColumnOrder{
		{ColumnID: columnA.ID, TaskIDs: []string{taskA1.ID}},
		{ColumnID: columnB.ID, TaskIDs: []string{taskB0.ID, taskA0.ID}},
	}); err != nil {
		t.Fatalf("reorder tasks to move A0 into column B: %v", err)
	}

	details, err := repo.GetBoard(ctx, "user-1", board.ID)
	if err != nil {
		t.Fatalf("get board after move: %v", err)
	}

	taskByID := make(map[string]Task, len(details.Tasks))
	for _, task := range details.Tasks {
		taskByID[task.ID] = task
	}
	if got := taskByID[taskA1.ID]; got.ColumnID != columnA.ID || got.Position != 0 {
		t.Fatalf("task A1 = %+v, want column=%q position=0", got, columnA.ID)
	}
	if got := taskByID[taskB0.ID]; got.ColumnID != columnB.ID || got.Position != 0 {
		t.Fatalf("task B0 = %+v, want column=%q position=0", got, columnB.ID)
	}
	if got := taskByID[taskA0.ID]; got.ColumnID != columnB.ID || got.Position != 1 {
		t.Fatalf("task A0 = %+v, want column=%q position=1", got, columnB.ID)
	}

	if _, _, err := repo.UpdateTask(ctx, "user-1", board.ID, taskA0.ID, "A0 Updated", "new"); err != nil {
		t.Fatalf("update task: %v", err)
	}

	if _, err := repo.DeleteTask(ctx, "user-1", board.ID, taskA0.ID); err != nil {
		t.Fatalf("delete task A0: %v", err)
	}

	details, err = repo.GetBoard(ctx, "user-1", board.ID)
	if err != nil {
		t.Fatalf("get board after task delete: %v", err)
	}

	var foundTaskA1 *Task
	for i := range details.Tasks {
		if details.Tasks[i].ID == taskA1.ID {
			foundTaskA1 = &details.Tasks[i]
			break
		}
	}
	if foundTaskA1 == nil {
		t.Fatalf("expected task %q to remain", taskA1.ID)
	}
	if foundTaskA1.Position != 0 {
		t.Fatalf("task position = %d, want 0 after reindex", foundTaskA1.Position)
	}

	if _, err := repo.DeleteTask(ctx, "user-1", board.ID, taskA1.ID); err != nil {
		t.Fatalf("delete task A1: %v", err)
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
	t.Parallel()

	ctx := context.Background()
	repo := NewMemoryRepository()

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

	task, _, err := repo.CreateTask(ctx, "owner", board.ID, column.ID, "Task", "")
	if err != nil {
		t.Fatalf("create task: %v", err)
	}

	if _, err := repo.DeleteTask(ctx, "intruder", board.ID, task.ID); !errors.Is(err, ErrForbidden) {
		t.Fatalf("delete task err = %v, want ErrForbidden", err)
	}
}
