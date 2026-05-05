package contracttest

import (
	"context"
	"errors"
	"regexp"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"go_macos_todo/server/internal/kanban"
)

type archiveCapable interface {
	ArchiveBoard(ctx context.Context, ownerUserID, boardID string) (kanban.Board, error)
	RestoreBoard(ctx context.Context, ownerUserID, boardID string, mode kanban.RestoreBoardTitleMode) (kanban.Board, error)
	ListArchivedBoardsByOwner(ctx context.Context, ownerUserID string) ([]kanban.Board, error)
}

type taskArchiveCapable interface {
	ArchiveTasksInColumn(ctx context.Context, ownerUserID, boardID, columnID string) (kanban.ColumnTaskArchiveResult, kanban.Board, error)
	ListArchivedTasksByBoard(ctx context.Context, ownerUserID, boardID string) ([]kanban.Task, error)
	RestoreArchivedTask(ctx context.Context, ownerUserID, boardID, taskID string) (kanban.Task, kanban.Board, error)
	DeleteArchivedTask(ctx context.Context, ownerUserID, boardID, taskID string) (kanban.Board, error)
	CreateTaskWithArchivedAt(ctx context.Context, ownerUserID, boardID, columnID, title, description string, archivedAt *time.Time) (kanban.Task, kanban.Board, error)
}

// RunRepositoryContractTests verifies shared repository behavior for any implementation.
func RunRepositoryContractTests(t *testing.T, makeRepo func() kanban.Repository) {
	t.Helper()

	t.Run("CRUD", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		ownerUserID := "user-" + uuid.NewString()

		board, err := repo.CreateBoard(ctx, ownerUserID, "Main")
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

		board, err := repo.CreateBoard(ctx, ownerUserID, "Main")
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

		if _, err := repo.CreateBoard(ctx, ownerUserID, "   "); !errors.Is(err, kanban.ErrInvalidInput) {
			t.Fatalf("create board err = %v, want ErrInvalidInput", err)
		}

		board, err := repo.CreateBoard(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}

		if _, err := repo.CreateBoard(ctx, ownerUserID, "Second"); err != nil {
			t.Fatalf("create second board: %v", err)
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

		board, err := repo.CreateBoard(ctx, ownerUserID, "Main")
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

		for _, task := range details.Tasks {
			if _, err := repo.DeleteTask(ctx, ownerUserID, board.ID, task.ID); err != nil {
				t.Fatalf("cleanup task %s: %v", task.ID, err)
			}
		}

		if err := repo.DeleteBoard(ctx, ownerUserID, board.ID); err != nil {
			t.Fatalf("cleanup board: %v", err)
		}
	})

	t.Run("ReorderColumns", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		ownerUserID := "user-" + uuid.NewString()

		board, err := repo.CreateBoard(ctx, ownerUserID, "Main")
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

		board, err := repo.CreateBoard(ctx, ownerUserID, "Main")
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

	t.Run("ArchiveColumnTasksUseSharedArchivedTimestamp", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		archiver, ok := repo.(taskArchiveCapable)
		if !ok {
			t.Skip("task archive operations not implemented")
		}

		ownerUserID := "user-" + uuid.NewString()
		board, err := repo.CreateBoard(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}
		columnA, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "Backlog")
		if err != nil {
			t.Fatalf("create column A: %v", err)
		}
		columnB, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "Done")
		if err != nil {
			t.Fatalf("create column B: %v", err)
		}
		if _, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, columnA.ID, "A-1", ""); err != nil {
			t.Fatalf("create task A-1: %v", err)
		}
		if _, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, columnA.ID, "A-2", ""); err != nil {
			t.Fatalf("create task A-2: %v", err)
		}
		if _, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, columnB.ID, "B-1", ""); err != nil {
			t.Fatalf("create task B-1: %v", err)
		}

		archiveResult, _, err := archiver.ArchiveTasksInColumn(ctx, ownerUserID, board.ID, columnA.ID)
		if err != nil {
			t.Fatalf("archive tasks in column: %v", err)
		}
		if archiveResult.ArchivedTaskCount != 2 {
			t.Fatalf("archived task count = %d, want 2", archiveResult.ArchivedTaskCount)
		}

		details, err := repo.GetBoard(ctx, ownerUserID, board.ID)
		if err != nil {
			t.Fatalf("get board: %v", err)
		}
		if len(details.Tasks) != 1 || details.Tasks[0].Title != "B-1" {
			t.Fatalf("active tasks after archive = %+v, want only B-1", details.Tasks)
		}

		archivedTasks, err := archiver.ListArchivedTasksByBoard(ctx, ownerUserID, board.ID)
		if err != nil {
			t.Fatalf("list archived tasks: %v", err)
		}
		if len(archivedTasks) != 2 {
			t.Fatalf("archived tasks count = %d, want 2", len(archivedTasks))
		}
		for _, task := range archivedTasks {
			if task.ColumnID != columnA.ID {
				t.Fatalf("task column = %q, want %q", task.ColumnID, columnA.ID)
			}
			if !task.ArchivedAt.Equal(archiveResult.ArchivedAt) {
				t.Fatalf("task archivedAt = %s, want %s", task.ArchivedAt, archiveResult.ArchivedAt)
			}
		}
	})

	t.Run("ArchivedTaskRestoreAndDelete", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		archiver, ok := repo.(taskArchiveCapable)
		if !ok {
			t.Skip("task archive operations not implemented")
		}

		ownerUserID := "user-" + uuid.NewString()
		board, err := repo.CreateBoard(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}
		column, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "Backlog")
		if err != nil {
			t.Fatalf("create column: %v", err)
		}
		task, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, column.ID, "Old", "")
		if err != nil {
			t.Fatalf("create task: %v", err)
		}
		if _, _, err := archiver.ArchiveTasksInColumn(ctx, ownerUserID, board.ID, column.ID); err != nil {
			t.Fatalf("archive tasks in column: %v", err)
		}

		restored, _, err := archiver.RestoreArchivedTask(ctx, ownerUserID, board.ID, task.ID)
		if err != nil {
			t.Fatalf("restore archived task: %v", err)
		}
		if restored.IsArchived {
			t.Fatalf("restored task isArchived = true, want false")
		}

		if _, _, err := archiver.ArchiveTasksInColumn(ctx, ownerUserID, board.ID, column.ID); err != nil {
			t.Fatalf("archive tasks in column again: %v", err)
		}
		if _, err := archiver.DeleteArchivedTask(ctx, ownerUserID, board.ID, task.ID); err != nil {
			t.Fatalf("delete archived task: %v", err)
		}
		archivedTasks, err := archiver.ListArchivedTasksByBoard(ctx, ownerUserID, board.ID)
		if err != nil {
			t.Fatalf("list archived tasks: %v", err)
		}
		if len(archivedTasks) != 0 {
			t.Fatalf("archived tasks count = %d, want 0", len(archivedTasks))
		}
	})

	t.Run("CreateArchivedTaskAppendsPositionAfterArchivedDelete", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		archiver, ok := repo.(taskArchiveCapable)
		if !ok {
			t.Skip("task archive operations not implemented")
		}

		ownerUserID := "user-" + uuid.NewString()
		board, err := repo.CreateBoard(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}
		column, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "Backlog")
		if err != nil {
			t.Fatalf("create column: %v", err)
		}

		timestampA := time.Date(2026, 4, 20, 10, 0, 0, 0, time.UTC)
		timestampB := timestampA.Add(time.Minute)
		timestampC := timestampB.Add(time.Minute)

		archivedA, _, err := archiver.CreateTaskWithArchivedAt(ctx, ownerUserID, board.ID, column.ID, "A", "", &timestampA)
		if err != nil {
			t.Fatalf("create archived task A: %v", err)
		}
		archivedB, _, err := archiver.CreateTaskWithArchivedAt(ctx, ownerUserID, board.ID, column.ID, "B", "", &timestampB)
		if err != nil {
			t.Fatalf("create archived task B: %v", err)
		}

		if _, err := archiver.DeleteArchivedTask(ctx, ownerUserID, board.ID, archivedA.ID); err != nil {
			t.Fatalf("delete archived task A: %v", err)
		}

		archivedC, _, err := archiver.CreateTaskWithArchivedAt(ctx, ownerUserID, board.ID, column.ID, "C", "", &timestampC)
		if err != nil {
			t.Fatalf("create archived task C: %v", err)
		}

		archivedTasks, err := archiver.ListArchivedTasksByBoard(ctx, ownerUserID, board.ID)
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
	})

	t.Run("ArchiveBoardAddsTimestampToTitle", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		archiver, ok := repo.(archiveCapable)
		if !ok {
			t.Skip("archive operations not implemented")
		}

		ownerUserID := "user-" + uuid.NewString()
		board, err := repo.CreateBoard(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}

		archived, err := archiver.ArchiveBoard(ctx, ownerUserID, board.ID)
		if err != nil {
			t.Fatalf("archive board: %v", err)
		}
		if !archived.IsArchived {
			t.Fatalf("isArchived = %v, want true", archived.IsArchived)
		}
		if archived.ArchivedOriginalTitle != "Main" {
			t.Fatalf("archived original title = %q, want %q", archived.ArchivedOriginalTitle, "Main")
		}

		pattern := regexp.MustCompile(`^Main \(archived \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}Z\)$`)
		if !pattern.MatchString(archived.Title) {
			t.Fatalf("archived title = %q, want timestamped archived suffix", archived.Title)
		}

		archivedBoards, err := archiver.ListArchivedBoardsByOwner(ctx, ownerUserID)
		if err != nil {
			t.Fatalf("list archived boards: %v", err)
		}
		if len(archivedBoards) != 1 {
			t.Fatalf("archived board count = %d, want 1", len(archivedBoards))
		}
		if archivedBoards[0].Title != archived.Title {
			t.Fatalf("archived list title = %q, want %q", archivedBoards[0].Title, archived.Title)
		}
		if archivedBoards[0].ArchivedOriginalTitle != "Main" {
			t.Fatalf("archived list original title = %q, want %q", archivedBoards[0].ArchivedOriginalTitle, "Main")
		}
	})

	t.Run("RestoreBoardOriginalModeUsesOriginalTitle", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		archiver, ok := repo.(archiveCapable)
		if !ok {
			t.Skip("archive operations not implemented")
		}

		ownerUserID := "user-" + uuid.NewString()
		board, err := repo.CreateBoard(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}
		if _, err := archiver.ArchiveBoard(ctx, ownerUserID, board.ID); err != nil {
			t.Fatalf("archive board: %v", err)
		}

		restored, err := archiver.RestoreBoard(ctx, ownerUserID, board.ID, kanban.RestoreBoardTitleModeOriginal)
		if err != nil {
			t.Fatalf("restore board: %v", err)
		}
		if restored.Title != "Main" {
			t.Fatalf("restored title = %q, want %q", restored.Title, "Main")
		}
		if restored.ArchivedOriginalTitle != "" {
			t.Fatalf("restored archived original title = %q, want empty", restored.ArchivedOriginalTitle)
		}
	})

	t.Run("RestoreBoardOriginalModeRejectsConflictingActiveTitle", func(t *testing.T) {
		ctx := context.Background()
		repo := makeRepo()
		archiver, ok := repo.(archiveCapable)
		if !ok {
			t.Skip("archive operations not implemented")
		}

		ownerUserID := "user-" + uuid.NewString()
		archivedBoard, err := repo.CreateBoard(ctx, ownerUserID, "Main")
		if err != nil {
			t.Fatalf("create board: %v", err)
		}
		if _, err := archiver.ArchiveBoard(ctx, ownerUserID, archivedBoard.ID); err != nil {
			t.Fatalf("archive board: %v", err)
		}
		if _, err := repo.CreateBoard(ctx, ownerUserID, "Main"); err != nil {
			t.Fatalf("create conflicting board: %v", err)
		}

		_, err = archiver.RestoreBoard(ctx, ownerUserID, archivedBoard.ID, kanban.RestoreBoardTitleModeOriginal)
		if !errors.Is(err, kanban.ErrConflict) {
			t.Fatalf("restore conflict error = %v, want %v", err, kanban.ErrConflict)
		}
	})
}
