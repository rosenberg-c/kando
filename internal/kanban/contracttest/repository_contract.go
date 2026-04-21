package contracttest

import (
	"context"
	"errors"
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
}
