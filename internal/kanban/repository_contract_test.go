package kanban_test

import (
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
