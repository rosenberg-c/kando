package kanban

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
	"time"
)

func TestSQLiteRepositoryCRUDAndReindex(t *testing.T) {
	// @req COL-002, COL-003, COL-004, TASK-002, TASK-003, TASK-004, TASK-005, TASK-006, TASK-007
	t.Parallel()

	ctx := context.Background()
	repo := newTestSQLiteRepository(t)

	board, err := repo.CreateBoard(ctx, "user-1", "Main")
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
		t.Fatalf("reorder tasks to move A0 to column B: %v", err)
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

func TestSQLiteRepositoryOwnershipEnforcement(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	repo := newTestSQLiteRepository(t)

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

	task, _, err := repo.CreateTask(ctx, "owner", board.ID, column.ID, "Task", "")
	if err != nil {
		t.Fatalf("create task: %v", err)
	}

	if _, err := repo.DeleteTask(ctx, "intruder", board.ID, task.ID); !errors.Is(err, ErrForbidden) {
		t.Fatalf("delete task err = %v, want ErrForbidden", err)
	}
}

func TestSQLiteRepositoryGetBoardTaskOrderFollowsColumnPosition(t *testing.T) {
	ctx := context.Background()
	repo := newTestSQLiteRepository(t)

	board, err := repo.CreateBoard(ctx, "owner", "Main")
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

	if _, _, err := repo.CreateTask(ctx, "owner", board.ID, columnB.ID, "B0", ""); err != nil {
		t.Fatalf("create task in column B: %v", err)
	}
	if _, _, err := repo.CreateTask(ctx, "owner", board.ID, columnA.ID, "A0", ""); err != nil {
		t.Fatalf("create task in column A: %v", err)
	}

	details, err := repo.GetBoard(ctx, "owner", board.ID)
	if err != nil {
		t.Fatalf("get board: %v", err)
	}

	if len(details.Tasks) != 2 {
		t.Fatalf("task count = %d, want 2", len(details.Tasks))
	}
	if details.Tasks[0].ColumnID != columnA.ID {
		t.Fatalf("first task column = %q, want %q", details.Tasks[0].ColumnID, columnA.ID)
	}
	if details.Tasks[1].ColumnID != columnB.ID {
		t.Fatalf("second task column = %q, want %q", details.Tasks[1].ColumnID, columnB.ID)
	}
}

func TestSQLiteRepositoryRunInTransactionRollsBackOnError(t *testing.T) {
	ctx := context.Background()
	repo := newTestSQLiteRepository(t)

	board, err := repo.CreateBoard(ctx, "owner", "Main")
	if err != nil {
		t.Fatalf("create board: %v", err)
	}

	err = repo.RunInTransaction(ctx, func(txRepo Repository) error {
		column, _, err := txRepo.CreateColumn(ctx, "owner", board.ID, "Backlog")
		if err != nil {
			return err
		}
		if _, _, err := txRepo.CreateTask(ctx, "owner", board.ID, column.ID, "Plan", ""); err != nil {
			return err
		}
		return ErrInvalidInput
	})
	if !errors.Is(err, ErrInvalidInput) {
		t.Fatalf("transaction err = %v, want ErrInvalidInput", err)
	}

	details, err := repo.GetBoard(ctx, "owner", board.ID)
	if err != nil {
		t.Fatalf("get board: %v", err)
	}
	if len(details.Columns) != 0 {
		t.Fatalf("column count = %d, want 0 after rollback", len(details.Columns))
	}
	if len(details.Tasks) != 0 {
		t.Fatalf("task count = %d, want 0 after rollback", len(details.Tasks))
	}
}

func TestSQLiteRepositoryArchiveTasksInColumn(t *testing.T) {
	// @req COL-ARCH-001, COL-ARCH-002, COL-ARCH-003, COL-ARCH-005
	t.Parallel()

	ctx := context.Background()
	repo := newTestSQLiteRepository(t)

	board, err := repo.CreateBoard(ctx, "user-1", "Main")
	if err != nil {
		t.Fatalf("create board: %v", err)
	}
	columnA, _, err := repo.CreateColumn(ctx, "user-1", board.ID, "A")
	if err != nil {
		t.Fatalf("create column A: %v", err)
	}
	columnB, _, err := repo.CreateColumn(ctx, "user-1", board.ID, "B")
	if err != nil {
		t.Fatalf("create column B: %v", err)
	}
	if _, _, err := repo.CreateTask(ctx, "user-1", board.ID, columnA.ID, "A-1", ""); err != nil {
		t.Fatalf("create task A-1: %v", err)
	}
	if _, _, err := repo.CreateTask(ctx, "user-1", board.ID, columnA.ID, "A-2", ""); err != nil {
		t.Fatalf("create task A-2: %v", err)
	}
	if _, _, err := repo.CreateTask(ctx, "user-1", board.ID, columnB.ID, "B-1", ""); err != nil {
		t.Fatalf("create task B-1: %v", err)
	}

	archiveResult, _, err := repo.ArchiveTasksInColumn(ctx, "user-1", board.ID, columnA.ID)
	if err != nil {
		t.Fatalf("archive tasks in column: %v", err)
	}
	if archiveResult.ArchivedTaskCount != 2 {
		t.Fatalf("archived task count = %d, want 2", archiveResult.ArchivedTaskCount)
	}

	details, err := repo.GetBoard(ctx, "user-1", board.ID)
	if err != nil {
		t.Fatalf("get board: %v", err)
	}
	if len(details.Tasks) != 1 || details.Tasks[0].Title != "B-1" {
		t.Fatalf("active tasks = %+v, want only B-1", details.Tasks)
	}

	archivedTasks, err := repo.ListArchivedTasksByBoard(ctx, "user-1", board.ID)
	if err != nil {
		t.Fatalf("list archived tasks: %v", err)
	}
	if len(archivedTasks) != 2 {
		t.Fatalf("archived task count = %d, want 2", len(archivedTasks))
	}
	for _, task := range archivedTasks {
		if task.ColumnID != columnA.ID {
			t.Fatalf("archived task column = %q, want %q", task.ColumnID, columnA.ID)
		}
		if !task.ArchivedAt.Equal(archiveResult.ArchivedAt) {
			t.Fatalf("archivedAt = %s, want %s", task.ArchivedAt, archiveResult.ArchivedAt)
		}
	}
}

func TestSQLiteRepositoryCreateTaskWithArchivedAtAppendsAfterArchivedDelete(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	repo := newTestSQLiteRepository(t)

	board, err := repo.CreateBoard(ctx, "user-1", "Main")
	if err != nil {
		t.Fatalf("create board: %v", err)
	}
	column, _, err := repo.CreateColumn(ctx, "user-1", board.ID, "A")
	if err != nil {
		t.Fatalf("create column: %v", err)
	}

	timestampA := time.Date(2026, 4, 20, 10, 0, 0, 0, time.UTC)
	timestampB := timestampA.Add(time.Minute)
	timestampC := timestampB.Add(time.Minute)

	archivedA, _, err := repo.CreateTaskWithArchivedAt(ctx, "user-1", board.ID, column.ID, "A", "", &timestampA)
	if err != nil {
		t.Fatalf("create archived task A: %v", err)
	}
	archivedB, _, err := repo.CreateTaskWithArchivedAt(ctx, "user-1", board.ID, column.ID, "B", "", &timestampB)
	if err != nil {
		t.Fatalf("create archived task B: %v", err)
	}

	if _, err := repo.DeleteArchivedTask(ctx, "user-1", board.ID, archivedA.ID); err != nil {
		t.Fatalf("delete archived task A: %v", err)
	}

	archivedC, _, err := repo.CreateTaskWithArchivedAt(ctx, "user-1", board.ID, column.ID, "C", "", &timestampC)
	if err != nil {
		t.Fatalf("create archived task C: %v", err)
	}

	archivedTasks, err := repo.ListArchivedTasksByBoard(ctx, "user-1", board.ID)
	if err != nil {
		t.Fatalf("list archived tasks: %v", err)
	}

	positionsByID := map[string]int{}
	for _, task := range archivedTasks {
		positionsByID[task.ID] = task.Position
	}
	if got := positionsByID[archivedB.ID]; got != 1 {
		t.Fatalf("archived task B position = %d, want 1", got)
	}
	if got := positionsByID[archivedC.ID]; got != 2 {
		t.Fatalf("archived task C position = %d, want 2", got)
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
