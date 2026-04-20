package kanban_test

import (
	"path/filepath"
	"testing"

	"go_macos_todo/internal/kanban"
	"go_macos_todo/internal/kanban/contracttest"
)

func TestRepositoryContractMemoryService(t *testing.T) {
	// Requirements: API-001, COL-RULE-001, COL-001, TODO-001
	t.Parallel()
	contracttest.RunRepositoryContractTests(t, func() kanban.Repository {
		return kanban.NewService(kanban.NewMemoryRepository())
	})
}

func TestRepositoryContractSQLiteService(t *testing.T) {
	// Requirements: API-001, COL-RULE-001, COL-001, TODO-001
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
