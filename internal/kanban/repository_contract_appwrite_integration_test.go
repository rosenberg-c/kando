package kanban_test

import (
	"context"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"go_macos_todo/internal/appwrite"
	"go_macos_todo/internal/kanban"
	"go_macos_todo/internal/kanban/contracttest"
)

type trackedRepository struct {
	repo kanban.Repository
	mu   sync.Mutex
	rows map[string]map[string]struct{}
}

func newTrackedRepository(repo kanban.Repository) *trackedRepository {
	return &trackedRepository{
		repo: repo,
		rows: make(map[string]map[string]struct{}),
	}
}

func (r *trackedRepository) ListBoardsByOwner(ctx context.Context, ownerUserID string) ([]kanban.Board, error) {
	return r.repo.ListBoardsByOwner(ctx, ownerUserID)
}

func (r *trackedRepository) GetBoard(ctx context.Context, ownerUserID, boardID string) (kanban.BoardDetails, error) {
	return r.repo.GetBoard(ctx, ownerUserID, boardID)
}

func (r *trackedRepository) CreateBoardIfAbsent(ctx context.Context, ownerUserID, title string) (kanban.Board, error) {
	board, err := r.repo.CreateBoardIfAbsent(ctx, ownerUserID, title)
	if err != nil {
		return kanban.Board{}, err
	}
	r.mu.Lock()
	if _, ok := r.rows[ownerUserID]; !ok {
		r.rows[ownerUserID] = make(map[string]struct{})
	}
	r.rows[ownerUserID][board.ID] = struct{}{}
	r.mu.Unlock()
	return board, nil
}

func (r *trackedRepository) UpdateBoardTitle(ctx context.Context, ownerUserID, boardID, title string) (kanban.Board, error) {
	return r.repo.UpdateBoardTitle(ctx, ownerUserID, boardID, title)
}

func (r *trackedRepository) DeleteBoard(ctx context.Context, ownerUserID, boardID string) error {
	err := r.repo.DeleteBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return err
	}
	r.mu.Lock()
	if byOwner, ok := r.rows[ownerUserID]; ok {
		delete(byOwner, boardID)
		if len(byOwner) == 0 {
			delete(r.rows, ownerUserID)
		}
	}
	r.mu.Unlock()
	return nil
}

func (r *trackedRepository) CreateColumn(ctx context.Context, ownerUserID, boardID, title string) (kanban.Column, kanban.Board, error) {
	return r.repo.CreateColumn(ctx, ownerUserID, boardID, title)
}

func (r *trackedRepository) UpdateColumnTitle(ctx context.Context, ownerUserID, boardID, columnID, title string) (kanban.Column, kanban.Board, error) {
	return r.repo.UpdateColumnTitle(ctx, ownerUserID, boardID, columnID, title)
}

func (r *trackedRepository) ReorderColumns(ctx context.Context, ownerUserID, boardID string, orderedColumnIDs []string) (kanban.Board, error) {
	return r.repo.ReorderColumns(ctx, ownerUserID, boardID, orderedColumnIDs)
}

func (r *trackedRepository) DeleteColumn(ctx context.Context, ownerUserID, boardID, columnID string) (kanban.Board, error) {
	return r.repo.DeleteColumn(ctx, ownerUserID, boardID, columnID)
}

func (r *trackedRepository) CreateTask(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (kanban.Task, kanban.Board, error) {
	return r.repo.CreateTask(ctx, ownerUserID, boardID, columnID, title, description)
}

func (r *trackedRepository) UpdateTask(ctx context.Context, ownerUserID, boardID, taskID, title, description string) (kanban.Task, kanban.Board, error) {
	return r.repo.UpdateTask(ctx, ownerUserID, boardID, taskID, title, description)
}

func (r *trackedRepository) ReorderTasks(ctx context.Context, ownerUserID, boardID string, orderedTasksByColumn []kanban.TaskColumnOrder) (kanban.Board, error) {
	return r.repo.ReorderTasks(ctx, ownerUserID, boardID, orderedTasksByColumn)
}

func (r *trackedRepository) DeleteTask(ctx context.Context, ownerUserID, boardID, taskID string) (kanban.Board, error) {
	return r.repo.DeleteTask(ctx, ownerUserID, boardID, taskID)
}

func (r *trackedRepository) cleanup(ctx context.Context) {
	r.mu.Lock()
	task := make(map[string][]string, len(r.rows))
	for ownerUserID, ids := range r.rows {
		boards := make([]string, 0, len(ids))
		for boardID := range ids {
			boards = append(boards, boardID)
		}
		task[ownerUserID] = boards
	}
	r.mu.Unlock()

	for ownerUserID, boardIDs := range task {
		for _, boardID := range boardIDs {
			_ = r.repo.DeleteBoard(ctx, ownerUserID, boardID)
		}
	}
}

func TestRepositoryContractAppwriteService(t *testing.T) {
	// Requirements: APPWRITE-001, APPWRITE-002, APPWRITE-003
	if strings.TrimSpace(os.Getenv("RUN_APPWRITE_INTEGRATION")) != "1" {
		t.Skip("set RUN_APPWRITE_INTEGRATION=1 to run Appwrite integration contract tests")
	}

	endpoint := strings.TrimSpace(os.Getenv("APPWRITE_ENDPOINT"))
	projectID := strings.TrimSpace(os.Getenv("APPWRITE_PROJECT_ID"))
	databaseID := strings.TrimSpace(os.Getenv("APPWRITE_DB_ID"))
	boardsID := strings.TrimSpace(os.Getenv("APPWRITE_BOARDS_COLLECTION_ID"))
	columnsID := strings.TrimSpace(os.Getenv("APPWRITE_COLUMNS_COLLECTION_ID"))
	tasksID := strings.TrimSpace(os.Getenv("APPWRITE_TASKS_COLLECTION_ID"))
	apiKey := strings.TrimSpace(os.Getenv("APPWRITE_DB_API_KEY"))
	if apiKey == "" {
		apiKey = strings.TrimSpace(os.Getenv("APPWRITE_AUTH_API_KEY"))
	}

	missing := make([]string, 0)
	if endpoint == "" {
		missing = append(missing, "APPWRITE_ENDPOINT")
	}
	if projectID == "" {
		missing = append(missing, "APPWRITE_PROJECT_ID")
	}
	if apiKey == "" {
		missing = append(missing, "APPWRITE_DB_API_KEY or APPWRITE_AUTH_API_KEY")
	}
	if databaseID == "" {
		missing = append(missing, "APPWRITE_DB_ID")
	}
	if boardsID == "" {
		missing = append(missing, "APPWRITE_BOARDS_COLLECTION_ID")
	}
	if columnsID == "" {
		missing = append(missing, "APPWRITE_COLUMNS_COLLECTION_ID")
	}
	if tasksID == "" {
		missing = append(missing, "APPWRITE_TASKS_COLLECTION_ID")
	}
	if len(missing) > 0 {
		t.Skip("missing required Appwrite integration env vars: " + strings.Join(missing, ", "))
	}

	contracttest.RunRepositoryContractTests(t, func() kanban.Repository {
		client := appwrite.NewClient(endpoint, projectID, apiKey, nil)
		repo := appwrite.NewKanbanRepository(client, appwrite.KanbanRepositoryConfig{
			DatabaseID: databaseID,
			BoardsID:   boardsID,
			ColumnsID:  columnsID,
			TasksID:    tasksID,
		})
		tracked := newTrackedRepository(kanban.NewService(repo))
		t.Cleanup(func() {
			cleanupCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			tracked.cleanup(cleanupCtx)
		})
		return tracked
	})
}
