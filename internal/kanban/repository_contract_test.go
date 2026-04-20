package kanban_test

import (
	"testing"

	"go_macos_todo/internal/kanban"
	"go_macos_todo/internal/kanban/contracttest"
)

func TestRepositoryContractMemoryService(t *testing.T) {
	t.Parallel()
	contracttest.RunRepositoryContractTests(t, func() kanban.Repository {
		return kanban.NewService(kanban.NewMemoryRepository())
	})
}
