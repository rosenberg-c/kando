package kanban_test

import (
	"path/filepath"
	"testing"

	"go_macos_todo/internal/kanban"
	"go_macos_todo/internal/kanban/contracttest"
)

func TestRepositoryContractMemoryService(t *testing.T) {
	// Requirements: API-001, API-005, API-006, API-020, API-021, API-022, API-023, API-024, BOARD-021, BOARD-022, BOARD-023, BOARD-024, COL-RULE-001, COL-001, COL-MOVE-001, COL-MOVE-002, COL-MOVE-003, COL-MOVE-004, COL-MOVE-006, COL-MOVE-010, COL-ARCH-001, COL-ARCH-002, COL-ARCH-003, COL-ARCH-005, TASK-001, TASK-005, TASK-006, TASK-007
	t.Parallel()
	contracttest.RunRepositoryContractTests(t, func() kanban.Repository {
		return kanban.NewService(kanban.NewMemoryRepository())
	})
}

func TestRepositoryContractSQLiteService(t *testing.T) {
	// Requirements: API-001, API-005, API-006, API-020, API-021, API-022, API-023, API-024, BOARD-021, BOARD-022, BOARD-023, BOARD-024, COL-RULE-001, COL-001, COL-MOVE-001, COL-MOVE-002, COL-MOVE-003, COL-MOVE-004, COL-MOVE-006, COL-MOVE-010, COL-ARCH-001, COL-ARCH-002, COL-ARCH-003, COL-ARCH-005, TASK-001, TASK-005, TASK-006, TASK-007
	t.Parallel()
	contracttest.RunRepositoryContractTests(t, func() kanban.Repository {
		repo, err := kanban.NewSQLiteRepository(filepath.Join(t.TempDir(), "contract.sqlite"))
		if err != nil {
			t.Fatalf("create sqlite repository: %v", err)
		}
		t.Cleanup(func() {
			if closeErr := repo.Close(); closeErr != nil {
				t.Fatalf("close sqlite repository: %v", closeErr)
			}
		})
		return kanban.NewService(repo)
	})
}
