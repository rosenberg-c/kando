package kanban_test

import (
	"context"
	"errors"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"go_macos_todo/internal/appwrite"
	"go_macos_todo/internal/kanban"
	"go_macos_todo/internal/kanban/contracttest"
)

func requireAppwriteIntegrationConfig(t *testing.T) (string, string, string, string, string, string) {
	t.Helper()
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

	return endpoint, projectID, databaseID, boardsID, columnsID, tasksID
}

func requireVerifiedAppwriteSchema(t *testing.T, client *appwrite.Client, cfg appwrite.SchemaConfig) {
	t.Helper()
	report, err := client.VerifyKanbanSchema(context.Background(), cfg)
	if err != nil {
		t.Fatalf("verify appwrite schema: %v", err)
	}
	if report.HasDrift() {
		t.Fatalf("appwrite schema drift detected (missing columns=%v mismatched columns=%v unexpected columns=%v missing indexes=%v mismatched indexes=%v unexpected indexes=%v)", report.MissingColumns, report.MismatchedColumns, report.UnexpectedColumns, report.MissingIndexes, report.MismatchedIndexes, report.UnexpectedIndexes)
	}
}

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

func (r *trackedRepository) CreateBoard(ctx context.Context, ownerUserID, title string) (kanban.Board, error) {
	board, err := r.repo.CreateBoard(ctx, ownerUserID, title)
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
	// @req APPWRITE-001, APPWRITE-002, APPWRITE-003
	if strings.TrimSpace(os.Getenv("RUN_APPWRITE_INTEGRATION")) != "1" {
		t.Skip("set RUN_APPWRITE_INTEGRATION=1 to run Appwrite integration contract tests")
	}

	endpoint, projectID, databaseID, boardsID, columnsID, tasksID := requireAppwriteIntegrationConfig(t)
	apiKey := strings.TrimSpace(os.Getenv("APPWRITE_DB_API_KEY"))
	if apiKey == "" {
		apiKey = strings.TrimSpace(os.Getenv("APPWRITE_AUTH_API_KEY"))
	}

	contracttest.RunRepositoryContractTests(t, func() kanban.Repository {
		client := appwrite.NewClient(endpoint, projectID, apiKey, nil)
		schemaCfg := appwrite.SchemaConfig{
			DatabaseID:          databaseID,
			BoardsCollectionID:  boardsID,
			ColumnsCollectionID: columnsID,
			TasksCollectionID:   tasksID,
		}
		requireVerifiedAppwriteSchema(t, client, schemaCfg)
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

func TestAppwriteTaskMutationsDoNotReturnInvalidStructure(t *testing.T) {
	if strings.TrimSpace(os.Getenv("RUN_APPWRITE_INTEGRATION")) != "1" {
		t.Skip("set RUN_APPWRITE_INTEGRATION=1 to run Appwrite integration tests")
	}

	endpoint, projectID, databaseID, boardsID, columnsID, tasksID := requireAppwriteIntegrationConfig(t)
	apiKey := strings.TrimSpace(os.Getenv("APPWRITE_DB_API_KEY"))
	if apiKey == "" {
		apiKey = strings.TrimSpace(os.Getenv("APPWRITE_AUTH_API_KEY"))
	}

	client := appwrite.NewClient(endpoint, projectID, apiKey, nil)
	schemaCfg := appwrite.SchemaConfig{
		DatabaseID:          databaseID,
		BoardsCollectionID:  boardsID,
		ColumnsCollectionID: columnsID,
		TasksCollectionID:   tasksID,
	}
	requireVerifiedAppwriteSchema(t, client, schemaCfg)
	repo := kanban.NewService(appwrite.NewKanbanRepository(client, appwrite.KanbanRepositoryConfig{
		DatabaseID: databaseID,
		BoardsID:   boardsID,
		ColumnsID:  columnsID,
		TasksID:    tasksID,
	}))

	ctx := context.Background()
	ownerUserID := "user-" + strings.ReplaceAll(time.Now().UTC().Format("20060102150405.000000000"), ".", "")
	board, err := repo.CreateBoard(ctx, ownerUserID, "Task mutation board")
	if err != nil {
		t.Fatalf("create board: %v", err)
	}
	t.Cleanup(func() { _ = repo.DeleteBoard(context.Background(), ownerUserID, board.ID) })

	columnA, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "A")
	if err != nil {
		t.Fatalf("create column A: %v", err)
	}
	columnB, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "B")
	if err != nil {
		t.Fatalf("create column B: %v", err)
	}

	taskA, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, columnA.ID, "A", "")
	if err != nil {
		assertNotInvalidStructureError(t, "create task A", err)
		t.Fatalf("create task A: %v", err)
	}
	taskB, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, columnA.ID, "B", "")
	if err != nil {
		assertNotInvalidStructureError(t, "create task B", err)
		t.Fatalf("create task B: %v", err)
	}

	if _, _, err := repo.UpdateTask(ctx, ownerUserID, board.ID, taskA.ID, "A updated", "updated"); err != nil {
		assertNotInvalidStructureError(t, "update task", err)
		t.Fatalf("update task: %v", err)
	}

	if _, err := repo.ReorderTasks(ctx, ownerUserID, board.ID, []kanban.TaskColumnOrder{
		{ColumnID: columnA.ID, TaskIDs: []string{taskB.ID}},
		{ColumnID: columnB.ID, TaskIDs: []string{taskA.ID}},
	}); err != nil {
		assertNotInvalidStructureError(t, "reorder tasks", err)
		t.Fatalf("reorder tasks: %v", err)
	}

	if _, err := repo.DeleteTask(ctx, ownerUserID, board.ID, taskB.ID); err != nil {
		assertNotInvalidStructureError(t, "delete task", err)
		t.Fatalf("delete task: %v", err)
	}
}

func TestAppwriteBatchDeleteFallbackCanBePartialOnFailure(t *testing.T) {
	// @req APPWRITE-004
	if strings.TrimSpace(os.Getenv("RUN_APPWRITE_INTEGRATION")) != "1" {
		t.Skip("set RUN_APPWRITE_INTEGRATION=1 to run Appwrite integration tests")
	}

	endpoint, projectID, databaseID, boardsID, columnsID, tasksID := requireAppwriteIntegrationConfig(t)
	apiKey := strings.TrimSpace(os.Getenv("APPWRITE_DB_API_KEY"))
	if apiKey == "" {
		apiKey = strings.TrimSpace(os.Getenv("APPWRITE_AUTH_API_KEY"))
	}

	client := appwrite.NewClient(endpoint, projectID, apiKey, nil)
	schemaCfg := appwrite.SchemaConfig{
		DatabaseID:          databaseID,
		BoardsCollectionID:  boardsID,
		ColumnsCollectionID: columnsID,
		TasksCollectionID:   tasksID,
	}
	requireVerifiedAppwriteSchema(t, client, schemaCfg)
	repo := kanban.NewService(appwrite.NewKanbanRepository(client, appwrite.KanbanRepositoryConfig{
		DatabaseID: databaseID,
		BoardsID:   boardsID,
		ColumnsID:  columnsID,
		TasksID:    tasksID,
	}))

	ctx := context.Background()
	ownerUserID := "user-" + strings.ReplaceAll(time.Now().UTC().Format("20060102150405.000000000"), ".", "")
	board, err := repo.CreateBoard(ctx, ownerUserID, "Batch delete fallback board")
	if err != nil {
		t.Fatalf("create board: %v", err)
	}
	t.Cleanup(func() { _ = repo.DeleteBoard(context.Background(), ownerUserID, board.ID) })

	column, _, err := repo.CreateColumn(ctx, ownerUserID, board.ID, "A")
	if err != nil {
		t.Fatalf("create column: %v", err)
	}
	taskA, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, column.ID, "A", "")
	if err != nil {
		t.Fatalf("create task A: %v", err)
	}
	taskB, _, err := repo.CreateTask(ctx, ownerUserID, board.ID, column.ID, "B", "")
	if err != nil {
		t.Fatalf("create task B: %v", err)
	}

	_, err = repo.ApplyTaskBatchMutation(ctx, ownerUserID, board.ID, kanban.TaskBatchMutationRequest{
		Action:  kanban.TaskBatchActionDelete,
		TaskIDs: []string{taskA.ID, "missing-task-id"},
	})
	if err == nil {
		t.Fatalf("apply batch mutation err = nil, want non-nil")
	}

	details, err := repo.GetBoard(ctx, ownerUserID, board.ID)
	if err != nil {
		t.Fatalf("get board: %v", err)
	}
	hasTaskA := false
	hasTaskB := false
	for _, task := range details.Tasks {
		if task.ID == taskA.ID {
			hasTaskA = true
		}
		if task.ID == taskB.ID {
			hasTaskB = true
		}
	}
	if hasTaskA {
		t.Fatalf("task A should be deleted before failure")
	}
	if !hasTaskB {
		t.Fatalf("task B should remain after failure")
	}
}

func assertNotInvalidStructureError(t *testing.T, operation string, err error) {
	t.Helper()
	if err == nil {
		return
	}
	if errors.Is(err, kanban.ErrInvalidInput) && strings.Contains(strings.ToLower(err.Error()), "row_invalid_structure") {
		t.Fatalf("%s returned Appwrite row_invalid_structure error: %v", operation, err)
	}
}
