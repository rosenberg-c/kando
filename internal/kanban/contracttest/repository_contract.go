package contracttest

import (
	"context"
	"errors"
	"sync"
	"testing"

	"github.com/google/uuid"

	"go_macos_todo/internal/kanban"
)

// RunRepositoryContractTests verifies shared repository behavior for any implementation.
func RunRepositoryContractTests(t *testing.T, makeRepo func() kanban.Repository) {
	t.Helper()

	t.Run("CRUD", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		ownerUserID := "user-" + uuid.NewString()

		board, err := repo.CreateBoardIfAbsent(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}

		column, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "Backlog")
		if err != nil {
			t.Fatalf("create column: %v", err)
		}

		task, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, column.ID, "Task", "desc")
		if err != nil {
			t.Fatalf("create task: %v", err)
		}

		if _, err := repo.DeleteColumn(ctx, ownerUserID, board.ID, column.ID); !errors.Is(err, kanban.ErrConflict) {
			t.Fatalf("delete non-empty column err = %v, want ErrConflict", err)
		}

		if _, err := repo.DeleteTask(ctx, ownerUserID, board.ID, task.ID); err != nil {
			t.Fatalf("delete task: %v", err)
		}

		if _, err := repo.DeleteColumn(ctx, ownerUserID, board.ID, column.ID); err != nil {
			t.Fatalf("delete empty column: %v", err)
		}

		if err := repo.DeleteBoard(ctx, ownerUserID, board.ID); err != nil {
			t.Fatalf("delete board: %v", err)
		}

		if _, err := repo.GetBoard(ctx, ownerUserID, board.ID); !errors.Is(err, kanban.ErrNotFound) {
			t.Fatalf("get deleted board err = %v, want ErrNotFound", err)
		}
	})

	t.Run("Ownership", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		ownerUserID := "owner-" + uuid.NewString()
		intruderUserID := "intruder-" + uuid.NewString()

		board, err := repo.CreateBoardIfAbsent(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}

		if _, err := repo.GetBoard(ctx, intruderUserID, board.ID); !errors.Is(err, kanban.ErrForbidden) {
			t.Fatalf("get board err = %v, want ErrForbidden", err)
		}

		if err := repo.DeleteBoard(ctx, ownerUserID, board.ID); err != nil {
			t.Fatalf("cleanup board: %v", err)
		}
	})

	t.Run("ValidationAndConflict", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		ownerUserID := "user-" + uuid.NewString()

		if _, err := repo.CreateBoardIfAbsent(ctx, ownerUserID, "   "); !errors.Is(err, kanban.ErrInvalidInput) {
			t.Fatalf("create board err = %v, want ErrInvalidInput", err)
		}

		board, err := repo.CreateBoardIfAbsent(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}

		if _, err := repo.CreateBoardIfAbsent(ctx, ownerUserID, "Second"); !errors.Is(err, kanban.ErrConflict) {
			t.Fatalf("create second board err = %v, want ErrConflict", err)
		}

		column, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "Backlog")
		if err != nil {
			t.Fatalf("create column: %v", err)
		}

		if _, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, column.ID, "   ", "desc"); !errors.Is(err, kanban.ErrInvalidInput) {
			t.Fatalf("create task err = %v, want ErrInvalidInput", err)
		}

		if err := repo.DeleteBoard(ctx, ownerUserID, board.ID); err != nil {
			t.Fatalf("cleanup board: %v", err)
		}
	})

	t.Run("ReorderTasks", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		ownerUserID := "user-" + uuid.NewString()

		board, err := repo.CreateBoardIfAbsent(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}

		columnA, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "A")
		if err != nil {
			t.Fatalf("create column A: %v", err)
		}
		columnB, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "B")
		if err != nil {
			t.Fatalf("create column B: %v", err)
		}

		taskA0, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, columnA.ID, "A0", "")
		if err != nil {
			t.Fatalf("create task A0: %v", err)
		}
		taskA1, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, columnA.ID, "A1", "")
		if err != nil {
			t.Fatalf("create task A1: %v", err)
		}
		taskB0, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, columnB.ID, "B0", "")
		if err != nil {
			t.Fatalf("create task B0: %v", err)
		}

		if _, err := repo.ReorderTasks(ctx, ownerUserID, board.ID, []kanban.TaskColumnOrder{
			{ColumnID: columnA.ID, TaskIDs: []string{taskA1.ID}},
			{ColumnID: columnB.ID, TaskIDs: []string{taskB0.ID, taskA0.ID}},
		}); err != nil {
			t.Fatalf("reorder tasks: %v", err)
		}

		details, err := repo.GetBoard(ctx, ownerUserID, board.ID)
		if err != nil {
			t.Fatalf("get board after move: %v", err)
		}
		tasksByID := make(map[string]kanban.Task, len(details.Tasks))
		for _, task := range details.Tasks {
			tasksByID[task.ID] = task
		}
		if got := tasksByID[taskA1.ID]; got.ColumnID != columnA.ID || got.Position != 0 {
			t.Fatalf("task A1 = %+v, want column=%q position=0", got, columnA.ID)
		}
		if got := tasksByID[taskB0.ID]; got.ColumnID != columnB.ID || got.Position != 0 {
			t.Fatalf("task B0 = %+v, want column=%q position=0", got, columnB.ID)
		}
		if got := tasksByID[taskA0.ID]; got.ColumnID != columnB.ID || got.Position != 1 {
			t.Fatalf("task A0 = %+v, want column=%q position=1", got, columnB.ID)
		}

		if _, err := repo.ReorderTasks(ctx, ownerUserID, board.ID, []kanban.TaskColumnOrder{
			{ColumnID: columnA.ID, TaskIDs: []string{taskA1.ID}},
			{ColumnID: columnB.ID, TaskIDs: []string{taskA1.ID, taskB0.ID, taskA0.ID}},
		}); !errors.Is(err, kanban.ErrInvalidInput) {
			t.Fatalf("reorder tasks invalid payload err = %v, want ErrInvalidInput", err)
		}

		details, err = repo.GetBoard(ctx, ownerUserID, board.ID)
		if err != nil {
			t.Fatalf("get board after invalid move: %v", err)
		}
		tasksByID = make(map[string]kanban.Task, len(details.Tasks))
		for _, task := range details.Tasks {
			tasksByID[task.ID] = task
		}
		if got := tasksByID[taskA1.ID]; got.ColumnID != columnA.ID || got.Position != 0 {
			t.Fatalf("task A1 after invalid reorder = %+v, want column=%q position=0", got, columnA.ID)
		}

		if err := repo.DeleteBoard(ctx, ownerUserID, board.ID); err != nil {
			t.Fatalf("cleanup board: %v", err)
		}
	})

	t.Run("ReorderColumns", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		ownerUserID := "user-" + uuid.NewString()

		board, err := repo.CreateBoardIfAbsent(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}

		columnA, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "A")
		if err != nil {
			t.Fatalf("create column A: %v", err)
		}
		columnB, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "B")
		if err != nil {
			t.Fatalf("create column B: %v", err)
		}
		columnC, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "C")
		if err != nil {
			t.Fatalf("create column C: %v", err)
		}

		if _, err := repo.ReorderColumns(ctx, ownerUserID, board.ID, []string{columnC.ID, columnA.ID, columnB.ID}); err != nil {
			t.Fatalf("reorder columns: %v", err)
		}

		details, err := repo.GetBoard(ctx, ownerUserID, board.ID)
		if err != nil {
			t.Fatalf("get board after reorder: %v", err)
		}
		if len(details.Columns) != 3 {
			t.Fatalf("column count = %d, want 3", len(details.Columns))
		}
		wantIDs := []string{columnC.ID, columnA.ID, columnB.ID}
		for i := range wantIDs {
			if details.Columns[i].ID != wantIDs[i] {
				t.Fatalf("column order[%d] = %q, want %q", i, details.Columns[i].ID, wantIDs[i])
			}
			if details.Columns[i].Position != i {
				t.Fatalf("column position[%d] = %d, want %d", i, details.Columns[i].Position, i)
			}
		}

		if _, err := repo.ReorderColumns(ctx, ownerUserID, board.ID, []string{columnA.ID, columnA.ID, columnB.ID}); !errors.Is(err, kanban.ErrInvalidInput) {
			t.Fatalf("duplicate reorder err = %v, want ErrInvalidInput", err)
		}

		details, err = repo.GetBoard(ctx, ownerUserID, board.ID)
		if err != nil {
			t.Fatalf("get board after invalid reorder: %v", err)
		}
		for i := range wantIDs {
			if details.Columns[i].ID != wantIDs[i] {
				t.Fatalf("column order after invalid reorder[%d] = %q, want %q", i, details.Columns[i].ID, wantIDs[i])
			}
		}

		if err := repo.DeleteBoard(ctx, ownerUserID, board.ID); err != nil {
			t.Fatalf("cleanup board: %v", err)
		}
	})

	t.Run("ReorderColumnsConcurrentAllowsExpectedOutcome", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		ownerUserID := "user-" + uuid.NewString()

		board, err := repo.CreateBoardIfAbsent(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}

		columnA, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "A")
		if err != nil {
			t.Fatalf("create column A: %v", err)
		}
		columnB, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "B")
		if err != nil {
			t.Fatalf("create column B: %v", err)
		}
		columnC, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "C")
		if err != nil {
			t.Fatalf("create column C: %v", err)
		}
		columnD, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "D")
		if err != nil {
			t.Fatalf("create column D: %v", err)
		}

		for i := 0; i < 20; i++ {
			var wg sync.WaitGroup
			wg.Add(2)

			reorderErrs := make(chan error, 2)

			go func() {
				defer wg.Done()
				_, err := repo.ReorderColumns(ctx, ownerUserID, board.ID, []string{columnD.ID, columnA.ID, columnB.ID, columnC.ID})
				reorderErrs <- err
			}()
			go func() {
				defer wg.Done()
				_, err := repo.ReorderColumns(ctx, ownerUserID, board.ID, []string{columnB.ID, columnC.ID, columnD.ID, columnA.ID})
				reorderErrs <- err
			}()

			wg.Wait()
			close(reorderErrs)
			for reorderErr := range reorderErrs {
				if reorderErr != nil {
					t.Fatalf("concurrent reorder err = %v, want nil", reorderErr)
				}
			}

			details, getErr := repo.GetBoard(ctx, ownerUserID, board.ID)
			if getErr != nil {
				t.Fatalf("get board after concurrent reorders: %v", getErr)
			}
			if len(details.Columns) != 4 {
				t.Fatalf("column count = %d, want 4", len(details.Columns))
			}

			gotIDs := make([]string, 0, len(details.Columns))
			seenIDs := map[string]bool{}
			for pos, col := range details.Columns {
				gotIDs = append(gotIDs, col.ID)
				if col.Position != pos {
					t.Fatalf("column %q position = %d, want %d", col.ID, col.Position, pos)
				}
				if seenIDs[col.ID] {
					t.Fatalf("duplicate column id in ordering: %s", col.ID)
				}
				seenIDs[col.ID] = true
			}

			for _, id := range []string{columnA.ID, columnB.ID, columnC.ID, columnD.ID} {
				if !seenIDs[id] {
					t.Fatalf("missing column id after concurrent reorders: %s", id)
				}
			}

			allowedA := []string{columnD.ID, columnA.ID, columnB.ID, columnC.ID}
			allowedB := []string{columnB.ID, columnC.ID, columnD.ID, columnA.ID}
			matchesAllowedA := true
			for idx := range allowedA {
				if gotIDs[idx] != allowedA[idx] {
					matchesAllowedA = false
					break
				}
			}
			matchesAllowedB := true
			for idx := range allowedB {
				if gotIDs[idx] != allowedB[idx] {
					matchesAllowedB = false
					break
				}
			}
			if !matchesAllowedA && !matchesAllowedB {
				t.Fatalf("concurrent final order = %v, want one of %v or %v", gotIDs, allowedA, allowedB)
			}
		}

		if err := repo.DeleteBoard(ctx, ownerUserID, board.ID); err != nil {
			t.Fatalf("cleanup board: %v", err)
		}
	})
}
