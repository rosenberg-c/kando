package server

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"go_macos_todo/internal/api/security"
	"go_macos_todo/internal/auth"
	"go_macos_todo/internal/kanban"
)

type stubIssuer struct {
	sessionSecret string
	jwt           string
	expiresAt     time.Time
	err           error
}

func (s *stubIssuer) CreateEmailPasswordSession(context.Context, string, string) (string, error) {
	if s.err != nil {
		return "", s.err
	}

	return s.sessionSecret, nil
}

func (s *stubIssuer) CreateJWT(context.Context, string) (string, time.Time, error) {
	if s.err != nil {
		return "", time.Time{}, s.err
	}

	return s.jwt, s.expiresAt, nil
}

func (s *stubIssuer) DeleteSession(context.Context, string) error {
	return s.err
}

type stubVerifier struct {
	identity auth.Identity
	err      error
}

func (s *stubVerifier) VerifyJWT(context.Context, string) (auth.Identity, error) {
	if s.err != nil {
		return auth.Identity{}, s.err
	}

	return s.identity, nil
}

type failOnCreateTaskRepository struct {
	kanban.Repository
	failAfter int
	calls     int
}

func (r *failOnCreateTaskRepository) CreateTask(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (kanban.Task, kanban.Board, error) {
	r.calls++
	if r.calls > r.failAfter {
		return kanban.Task{}, kanban.Board{}, kanban.ErrInvalidInput
	}
	return r.Repository.CreateTask(ctx, ownerUserID, boardID, columnID, title, description)
}

type transactionalFailOnCreateTaskRepository struct {
	kanban.Repository
	failAfter             int
	calls                 int
	runInTransactionCalls int
	deleteTaskCalls       int
	deleteColumnCalls     int
}

func (r *transactionalFailOnCreateTaskRepository) RunInTransaction(_ context.Context, fn func(repo kanban.Repository) error) error {
	r.runInTransactionCalls++
	return fn(r)
}

func (r *transactionalFailOnCreateTaskRepository) CreateTask(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (kanban.Task, kanban.Board, error) {
	r.calls++
	if r.calls > r.failAfter {
		return kanban.Task{}, kanban.Board{}, kanban.ErrInvalidInput
	}
	return r.Repository.CreateTask(ctx, ownerUserID, boardID, columnID, title, description)
}

func (r *transactionalFailOnCreateTaskRepository) DeleteTask(_ context.Context, _ string, _ string, _ string) (kanban.Board, error) {
	r.deleteTaskCalls++
	return kanban.Board{}, kanban.ErrNotImplemented
}

func (r *transactionalFailOnCreateTaskRepository) DeleteColumn(_ context.Context, _ string, _ string, _ string) (kanban.Board, error) {
	r.deleteColumnCalls++
	return kanban.Board{}, kanban.ErrNotImplemented
}

func TestHelloReturnsTextPlain(t *testing.T) {
	// Requirement: PUBLIC-001
	t.Parallel()

	mux, api := NewAPI()
	Register(api, Dependencies{})

	request := httptest.NewRequest(http.MethodGet, "/hello", nil)
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusOK)
	}

	if got := recorder.Header().Get("Content-Type"); got != "text/plain" {
		t.Fatalf("content type = %q, want %q", got, "text/plain")
	}
}

func TestUnknownRouteReturnsProblemJSON(t *testing.T) {
	t.Parallel()

	mux, api := NewAPI()
	Register(api, Dependencies{})

	request := httptest.NewRequest(http.MethodGet, "/does-not-exist", nil)
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusNotFound)
	}

	if got := recorder.Header().Get("Content-Type"); got != "application/problem+json" {
		t.Fatalf("content type = %q, want %q", got, "application/problem+json")
	}

	var problem struct {
		Status int    `json:"status"`
		Title  string `json:"title"`
		Detail string `json:"detail"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &problem); err != nil {
		t.Fatalf("decode problem response: %v body=%s", err, recorder.Body.String())
	}

	if problem.Status != http.StatusNotFound {
		t.Fatalf("problem.status = %d, want %d", problem.Status, http.StatusNotFound)
	}
	if problem.Title != "Not Found" {
		t.Fatalf("problem.title = %q, want %q", problem.Title, "Not Found")
	}
	if strings.TrimSpace(problem.Detail) == "" {
		t.Fatalf("problem.detail = %q, want non-empty", problem.Detail)
	}
}

func TestLoginBlockedReturnsRetryAfter(t *testing.T) {
	// Requirement: SEC-LOGIN-001
	t.Parallel()

	issuer := &stubIssuer{sessionSecret: "session-1", jwt: "jwt-1", expiresAt: time.Now().Add(10 * time.Minute)}
	limiter := security.NewLoginRateLimiter(1, time.Minute, 2*time.Minute)
	limiter.RegisterFailure("user@example.com|127.0.0.1")

	mux, api := NewAPI()
	Register(api, Dependencies{Issuer: issuer, LoginLimiter: limiter})

	body, _ := json.Marshal(map[string]string{"email": "user@example.com", "password": "secret"})
	request := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
	request.RemoteAddr = "127.0.0.1:12345"
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusTooManyRequests {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusTooManyRequests)
	}

	if got := recorder.Header().Get("Retry-After"); got == "" {
		t.Fatal("expected Retry-After header")
	}
}

func TestLoginReturnsTokensOnSuccess(t *testing.T) {
	// Requirement: AUTH-001
	t.Parallel()

	expiresAt := time.Now().UTC().Add(15 * time.Minute).Round(0)
	issuer := &stubIssuer{sessionSecret: "session-1", jwt: "jwt-1", expiresAt: expiresAt}
	limiter := security.NewLoginRateLimiter(5, time.Minute, time.Minute)

	mux, api := NewAPI()
	Register(api, Dependencies{Issuer: issuer, LoginLimiter: limiter})

	body, _ := json.Marshal(map[string]string{"email": "user@example.com", "password": "secret"})
	request := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
	request.RemoteAddr = "127.0.0.1:12345"
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var response struct {
		AccessToken          string    `json:"accessToken"`
		RefreshToken         string    `json:"refreshToken"`
		AccessTokenExpiresAt time.Time `json:"accessTokenExpiresAt"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode login response: %v", err)
	}

	if response.AccessToken != "jwt-1" {
		t.Fatalf("accessToken = %q, want %q", response.AccessToken, "jwt-1")
	}
	if response.RefreshToken != "session-1" {
		t.Fatalf("refreshToken = %q, want %q", response.RefreshToken, "session-1")
	}
	if !response.AccessTokenExpiresAt.Equal(expiresAt) {
		t.Fatalf("accessTokenExpiresAt = %s, want %s", response.AccessTokenExpiresAt, expiresAt)
	}
}

func TestOpenAPIDefinesHelloAsTextPlain(t *testing.T) {
	// Requirement: PUBLIC-002
	t.Parallel()

	_, api := NewAPI()
	Register(api, Dependencies{})

	path := api.OpenAPI().Paths["/hello"]
	if path == nil || path.Get == nil {
		t.Fatal("missing /hello GET operation in OpenAPI")
	}

	response := path.Get.Responses["200"]
	if response == nil {
		t.Fatal("missing 200 response for /hello")
	}

	if _, ok := response.Content["text/plain"]; !ok {
		t.Fatal("expected text/plain content for /hello response")
	}
}

func TestKanbanRoutesRequireBearerToken(t *testing.T) {
	// Requirement: API-003
	t.Parallel()

	mux, api := NewAPI()
	Register(api, Dependencies{
		KanbanRepo: kanban.NewService(kanban.NewMemoryRepository()),
		Verifier:   &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "u@example.com"}},
	})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/boards", nil)
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusUnauthorized)
	}

	recorder = httptest.NewRecorder()
	request = httptest.NewRequest(http.MethodGet, "/boards", nil)
	request.Header.Set("Authorization", "Token abc")
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("invalid bearer status = %d, want %d", recorder.Code, http.StatusUnauthorized)
	}
}

func TestKanbanRouteReturnsForbiddenForOtherOwner(t *testing.T) {
	// Requirement: API-003
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	board, err := repo.CreateBoard(context.Background(), "owner-user", "Main")
	if err != nil {
		t.Fatalf("seed board: %v", err)
	}

	mux, api := NewAPI()
	Register(api, Dependencies{
		KanbanRepo: repo,
		Verifier:   &stubVerifier{identity: auth.Identity{UserID: "another-user", Email: "other@example.com"}},
	})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/boards/"+board.ID, nil)
	request.Header.Set("Authorization", "Bearer token")
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusForbidden)
	}
}

func TestKanbanRouteReturnsNotFoundForMissingResources(t *testing.T) {
	// Requirement: API-003
	t.Parallel()

	mux, api := NewAPI()
	Register(api, Dependencies{
		KanbanRepo: kanban.NewService(kanban.NewMemoryRepository()),
		Verifier:   &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "u@example.com"}},
	})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/boards/not-found", nil)
	request.Header.Set("Authorization", "Bearer token")
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusNotFound)
	}

	recorder = httptest.NewRecorder()
	body := strings.NewReader(`{"title":"x","description":"","columnId":"11111111-1111-1111-1111-111111111111"}`)
	request = httptest.NewRequest(http.MethodPost, "/boards/not-found/tasks", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("task status = %d, want %d", recorder.Code, http.StatusNotFound)
	}
}

func TestKanbanValidationReturnsBadRequest(t *testing.T) {
	// Requirement: API-003
	t.Parallel()

	mux, api := NewAPI()
	Register(api, Dependencies{
		KanbanRepo: kanban.NewService(kanban.NewMemoryRepository()),
		Verifier:   &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "u@example.com"}},
	})

	recorder := httptest.NewRecorder()
	body := strings.NewReader(`{"title":"   "}`)
	request := httptest.NewRequest(http.MethodPost, "/boards", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}

	boardID := createBoard(t, mux)
	recorder = httptest.NewRecorder()
	body = strings.NewReader(`{"columnId":"11111111-1111-1111-1111-111111111111","title":"   ","description":""}`)
	request = httptest.NewRequest(http.MethodPost, "/boards/"+boardID+"/tasks", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("task bad request status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
}

func TestOpenAPIDefinesKanbanPaths(t *testing.T) {
	// Requirements: PUBLIC-003, PUBLIC-004, PUBLIC-005, PUBLIC-006, PUBLIC-007
	t.Parallel()

	_, api := NewAPI()
	Register(api, Dependencies{})

	assertPathMethod := func(path string, method string) {
		t.Helper()
		entry := api.OpenAPI().Paths[path]
		if entry == nil {
			t.Fatalf("missing path %s", path)
		}
		switch method {
		case http.MethodGet:
			if entry.Get == nil {
				t.Fatalf("missing GET %s", path)
			}
		case http.MethodPost:
			if entry.Post == nil {
				t.Fatalf("missing POST %s", path)
			}
		case http.MethodPatch:
			if entry.Patch == nil {
				t.Fatalf("missing PATCH %s", path)
			}
		case http.MethodPut:
			if entry.Put == nil {
				t.Fatalf("missing PUT %s", path)
			}
		case http.MethodDelete:
			if entry.Delete == nil {
				t.Fatalf("missing DELETE %s", path)
			}
		default:
			t.Fatalf("unsupported method check: %s", method)
		}
	}

	assertPathMethod("/boards", http.MethodGet)
	assertPathMethod("/boards", http.MethodPost)
	assertPathMethod("/boards/{boardId}", http.MethodGet)
	assertPathMethod("/boards/{boardId}", http.MethodPatch)
	assertPathMethod("/boards/{boardId}", http.MethodDelete)
	assertPathMethod("/boards/{boardId}/columns", http.MethodPost)
	assertPathMethod("/boards/{boardId}/columns/{columnId}", http.MethodPatch)
	assertPathMethod("/boards/{boardId}/columns/{columnId}", http.MethodDelete)
	assertPathMethod("/boards/{boardId}/columns/order", http.MethodPut)
	assertPathMethod("/boards/{boardId}/tasks", http.MethodPost)
	assertPathMethod("/boards/{boardId}/tasks/{taskId}", http.MethodPatch)
	assertPathMethod("/boards/{boardId}/tasks/{taskId}", http.MethodDelete)
	assertPathMethod("/boards/{boardId}/tasks/order", http.MethodPut)
	assertPathMethod("/boards/tasks/export", http.MethodPost)
	assertPathMethod("/boards/tasks/import", http.MethodPost)
}

func TestOpenAPIDefinesReorderColumnsContract(t *testing.T) {
	// Requirement: PUBLIC-005
	t.Parallel()

	_, api := NewAPI()
	Register(api, Dependencies{})

	path := api.OpenAPI().Paths["/boards/{boardId}/columns/order"]
	if path == nil || path.Put == nil {
		t.Fatal("missing PUT /boards/{boardId}/columns/order operation")
	}

	requestBody := path.Put.RequestBody
	if requestBody == nil {
		t.Fatal("missing request body for reorder columns operation")
	}
	mediaType, ok := requestBody.Content["application/json"]
	if !ok || mediaType == nil || mediaType.Schema == nil {
		t.Fatal("missing application/json schema for reorder columns operation")
	}
	if mediaType.Schema.Ref == "" {
		t.Fatal("expected reorder columns request schema ref")
	}

	response := path.Put.Responses["200"]
	if response == nil {
		t.Fatal("missing 200 response for reorder columns operation")
	}
	if _, ok := response.Content["application/json"]; !ok {
		t.Fatal("missing application/json response schema for reorder columns operation")
	}
}

func TestOpenAPIDefinesReorderTasksContract(t *testing.T) {
	// Requirement: PUBLIC-004
	t.Parallel()

	_, api := NewAPI()
	Register(api, Dependencies{})

	path := api.OpenAPI().Paths["/boards/{boardId}/tasks/order"]
	if path == nil || path.Put == nil {
		t.Fatal("missing PUT /boards/{boardId}/tasks/order operation")
	}

	requestBody := path.Put.RequestBody
	if requestBody == nil {
		t.Fatal("missing request body for reorder tasks operation")
	}
	mediaType, ok := requestBody.Content["application/json"]
	if !ok || mediaType == nil || mediaType.Schema == nil {
		t.Fatal("missing application/json schema for reorder tasks operation")
	}
	if mediaType.Schema.Ref == "" {
		t.Fatal("expected reorder tasks request schema ref")
	}

	response := path.Put.Responses["200"]
	if response == nil {
		t.Fatal("missing 200 response for reorder tasks operation")
	}
	if _, ok := response.Content["application/json"]; !ok {
		t.Fatal("missing application/json response schema for reorder tasks operation")
	}
}

func TestOpenAPIDefinesTaskExportContract(t *testing.T) {
	// Requirement: PUBLIC-006
	t.Parallel()

	requestRef, responseRef := requireOpenAPIPostJSONSchemaRefs(t, "/boards/tasks/export")
	if requestRef == "" {
		t.Fatal("expected export bundle request schema ref")
	}
	if responseRef == "" {
		t.Fatal("expected export bundle response schema ref")
	}
}

func TestOpenAPIDefinesTaskImportContract(t *testing.T) {
	// Requirement: PUBLIC-007
	t.Parallel()

	requestRef, responseRef := requireOpenAPIPostJSONSchemaRefs(t, "/boards/tasks/import")
	if requestRef == "" {
		t.Fatal("expected import tasks request schema ref")
	}
	if responseRef == "" {
		t.Fatal("expected import tasks response schema ref")
	}
}

func TestOpenAPIDefinesTaskBundleExportContract(t *testing.T) {
	// Requirement: PUBLIC-008
	t.Parallel()

	requestRef, responseRef := requireOpenAPIPostJSONSchemaRefs(t, "/boards/tasks/export")
	if requestRef != "#/components/schemas/TaskExportBundleRequest" {
		t.Fatalf("request schema ref = %q, want %q", requestRef, "#/components/schemas/TaskExportBundleRequest")
	}
	if responseRef != "#/components/schemas/TaskExportBundle" {
		t.Fatalf("response schema ref = %q, want %q", responseRef, "#/components/schemas/TaskExportBundle")
	}
}

func TestOpenAPIDefinesTaskBundleImportContract(t *testing.T) {
	// Requirement: PUBLIC-009
	t.Parallel()

	requestRef, responseRef := requireOpenAPIPostJSONSchemaRefs(t, "/boards/tasks/import")
	if requestRef != "#/components/schemas/TaskImportBundleRequest" {
		t.Fatalf("request schema ref = %q, want %q", requestRef, "#/components/schemas/TaskImportBundleRequest")
	}
	if responseRef != "#/components/schemas/TaskImportBundleResponse" {
		t.Fatalf("response schema ref = %q, want %q", responseRef, "#/components/schemas/TaskImportBundleResponse")
	}
}

func TestOpenAPIDefinesRestoreBoardTitleModeContract(t *testing.T) {
	// Requirement: PUBLIC-010
	t.Parallel()

	requestRef, responseRef := requireOpenAPIPostJSONSchemaRefs(t, "/boards/{boardId}/restore")
	if requestRef != "#/components/schemas/RestoreBoardRequest" {
		t.Fatalf("request schema ref = %q, want %q", requestRef, "#/components/schemas/RestoreBoardRequest")
	}
	if responseRef != "#/components/schemas/Board" {
		t.Fatalf("response schema ref = %q, want %q", responseRef, "#/components/schemas/Board")
	}
}

func requireOpenAPIPostJSONSchemaRefs(t *testing.T, pathKey string) (string, string) {
	t.Helper()

	_, api := NewAPI()
	Register(api, Dependencies{})

	path := api.OpenAPI().Paths[pathKey]
	if path == nil || path.Post == nil {
		t.Fatalf("missing POST %s operation", pathKey)
	}

	requestBody := path.Post.RequestBody
	if requestBody == nil {
		t.Fatalf("missing request body for POST %s", pathKey)
	}
	requestMediaType, ok := requestBody.Content["application/json"]
	if !ok || requestMediaType == nil || requestMediaType.Schema == nil {
		t.Fatalf("missing application/json request schema for POST %s", pathKey)
	}

	response := path.Post.Responses["200"]
	if response == nil {
		t.Fatalf("missing 200 response for POST %s", pathKey)
	}
	responseMediaType, ok := response.Content["application/json"]
	if !ok || responseMediaType == nil || responseMediaType.Schema == nil {
		t.Fatalf("missing application/json response schema for POST %s", pathKey)
	}

	return requestMediaType.Schema.Ref, responseMediaType.Schema.Ref
}

func TestKanbanBoardColumnTaskCRUD(t *testing.T) {
	// Requirements: API-001, BOARD-001, BOARD-002, COL-001, TASK-001
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	verifier := &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "user@example.com"}}
	mux, api := NewAPI()
	Register(api, Dependencies{KanbanRepo: repo, Verifier: verifier})

	boardID := createBoard(t, mux)
	columnID := createColumn(t, mux, boardID)
	taskID := createTask(t, mux, boardID, columnID)

	request := httptest.NewRequest(http.MethodGet, "/boards/"+boardID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusOK)
	}

	var response struct {
		Board struct {
			ID string `json:"id"`
		}
		Columns []struct {
			ID string `json:"id"`
		} `json:"columns"`
		Tasks []struct {
			ID string `json:"id"`
		} `json:"tasks"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode board response: %v", err)
	}

	if response.Board.ID != boardID {
		t.Fatalf("board.id = %q, want %q", response.Board.ID, boardID)
	}
	if len(response.Columns) != 1 || response.Columns[0].ID != columnID {
		t.Fatalf("columns = %+v, expected column %q", response.Columns, columnID)
	}
	if len(response.Tasks) != 1 || response.Tasks[0].ID != taskID {
		t.Fatalf("tasks = %+v, expected task %q", response.Tasks, taskID)
	}
}

func TestKanbanCreateAndListMultipleBoards(t *testing.T) {
	// Requirements: API-010, API-011
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	firstBoardID := createBoardWithTitle(t, mux, "Project Alpha")
	secondBoardID := createBoardWithTitle(t, mux, "Project Beta")

	renameBody := strings.NewReader(`{"title":"Project Alpha (Renamed)"}`)
	renameRequest := httptest.NewRequest(http.MethodPatch, "/boards/"+firstBoardID, renameBody)
	renameRequest.Header.Set("Content-Type", "application/json")
	renameRequest.Header.Set("Authorization", "Bearer token")
	renameRecorder := httptest.NewRecorder()
	mux.ServeHTTP(renameRecorder, renameRequest)

	if renameRecorder.Code != http.StatusOK {
		t.Fatalf("rename board status = %d, want %d body=%s", renameRecorder.Code, http.StatusOK, renameRecorder.Body.String())
	}

	request := httptest.NewRequest(http.MethodGet, "/boards", nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("list boards status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var response []struct {
		ID    string `json:"id"`
		Title string `json:"title"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode list boards response: %v", err)
	}

	if len(response) != 2 {
		t.Fatalf("board count = %d, want 2", len(response))
	}
	if response[0].ID != firstBoardID {
		t.Fatalf("first board id = %q, want %q", response[0].ID, firstBoardID)
	}
	if response[0].Title != "Project Alpha (Renamed)" {
		t.Fatalf("first board title = %q, want %q", response[0].Title, "Project Alpha (Renamed)")
	}
	if response[1].ID != secondBoardID {
		t.Fatalf("second board id = %q, want %q", response[1].ID, secondBoardID)
	}
}

func TestKanbanDeleteColumnWithTasksReturnsConflict(t *testing.T) {
	// Requirements: API-003, API-004, COL-RULE-001, COL-RULE-002
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	verifier := &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "user@example.com"}}
	mux, api := NewAPI()
	Register(api, Dependencies{KanbanRepo: repo, Verifier: verifier})

	boardID := createBoard(t, mux)
	columnID := createColumn(t, mux, boardID)
	_ = createTask(t, mux, boardID, columnID)

	request := httptest.NewRequest(http.MethodDelete, "/boards/"+boardID+"/columns/"+columnID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusConflict {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusConflict, recorder.Body.String())
	}

	var problem struct {
		Status int    `json:"status"`
		Detail string `json:"detail"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &problem); err != nil {
		t.Fatalf("decode conflict response: %v body=%s", err, recorder.Body.String())
	}
	if problem.Status != http.StatusConflict {
		t.Fatalf("problem.status = %d, want %d", problem.Status, http.StatusConflict)
	}
	if strings.TrimSpace(problem.Detail) == "" {
		t.Fatalf("problem.detail = %q, want non-empty", problem.Detail)
	}
}

func TestKanbanDeleteBoardWithTasksReturnsConflict(t *testing.T) {
	// Requirements: API-003, API-004, API-013, BOARD-013
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	verifier := &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "user@example.com"}}
	mux, api := NewAPI()
	Register(api, Dependencies{KanbanRepo: repo, Verifier: verifier})

	boardID := createBoard(t, mux)
	columnID := createColumn(t, mux, boardID)
	_ = createTask(t, mux, boardID, columnID)

	request := httptest.NewRequest(http.MethodDelete, "/boards/"+boardID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusConflict {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusConflict, recorder.Body.String())
	}

	var problem struct {
		Status int    `json:"status"`
		Detail string `json:"detail"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &problem); err != nil {
		t.Fatalf("decode conflict response: %v body=%s", err, recorder.Body.String())
	}
	if problem.Status != http.StatusConflict {
		t.Fatalf("problem.status = %d, want %d", problem.Status, http.StatusConflict)
	}
	if strings.TrimSpace(problem.Detail) == "" {
		t.Fatalf("problem.detail = %q, want non-empty", problem.Detail)
	}
}

func TestKanbanArchiveRestoreAndDeleteArchivedBoard(t *testing.T) {
	// Requirements: BOARD-014, BOARD-015, BOARD-016, BOARD-017, BOARD-021, BOARD-022, BOARD-023, API-014, API-015, API-016, API-020, API-021, API-022
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	verifier := &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "user@example.com"}}
	mux, api := NewAPI()
	Register(api, Dependencies{KanbanRepo: repo, Verifier: verifier})

	boardID := createBoard(t, mux)
	columnID := createColumn(t, mux, boardID)
	_ = createTask(t, mux, boardID, columnID)

	archiveReq := httptest.NewRequest(http.MethodPost, "/boards/"+boardID+"/archive", nil)
	archiveReq.Header.Set("Authorization", "Bearer token")
	archiveRec := httptest.NewRecorder()
	mux.ServeHTTP(archiveRec, archiveReq)
	if archiveRec.Code != http.StatusOK {
		t.Fatalf("archive status = %d, want %d body=%s", archiveRec.Code, http.StatusOK, archiveRec.Body.String())
	}
	var archivedBoard struct {
		Title string `json:"title"`
	}
	if err := json.Unmarshal(archiveRec.Body.Bytes(), &archivedBoard); err != nil {
		t.Fatalf("decode archive response: %v", err)
	}
	if !strings.HasPrefix(archivedBoard.Title, "Main Board (archived ") || !strings.HasSuffix(archivedBoard.Title, "Z)") {
		t.Fatalf("archived title = %q, want timestamped archive suffix", archivedBoard.Title)
	}

	listReq := httptest.NewRequest(http.MethodGet, "/boards", nil)
	listReq.Header.Set("Authorization", "Bearer token")
	listRec := httptest.NewRecorder()
	mux.ServeHTTP(listRec, listReq)
	if listRec.Code != http.StatusOK {
		t.Fatalf("list active status = %d, want %d body=%s", listRec.Code, http.StatusOK, listRec.Body.String())
	}
	var active []struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(listRec.Body.Bytes(), &active); err != nil {
		t.Fatalf("decode active boards: %v", err)
	}
	if len(active) != 0 {
		t.Fatalf("active board count = %d, want 0", len(active))
	}

	archivedReq := httptest.NewRequest(http.MethodGet, "/boards/archived", nil)
	archivedReq.Header.Set("Authorization", "Bearer token")
	archivedRec := httptest.NewRecorder()
	mux.ServeHTTP(archivedRec, archivedReq)
	if archivedRec.Code != http.StatusOK {
		t.Fatalf("list archived status = %d, want %d body=%s", archivedRec.Code, http.StatusOK, archivedRec.Body.String())
	}
	var archived []struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(archivedRec.Body.Bytes(), &archived); err != nil {
		t.Fatalf("decode archived boards: %v", err)
	}
	if len(archived) != 1 || archived[0].ID != boardID {
		t.Fatalf("archived boards = %+v, want [%s]", archived, boardID)
	}

	restoreReq := httptest.NewRequest(http.MethodPost, "/boards/"+boardID+"/restore", strings.NewReader(`{"titleMode":"archived"}`))
	restoreReq.Header.Set("Content-Type", "application/json")
	restoreReq.Header.Set("Authorization", "Bearer token")
	restoreRec := httptest.NewRecorder()
	mux.ServeHTTP(restoreRec, restoreReq)
	if restoreRec.Code != http.StatusOK {
		t.Fatalf("restore status = %d, want %d body=%s", restoreRec.Code, http.StatusOK, restoreRec.Body.String())
	}

	archiveReq = httptest.NewRequest(http.MethodPost, "/boards/"+boardID+"/archive", nil)
	archiveReq.Header.Set("Authorization", "Bearer token")
	archiveRec = httptest.NewRecorder()
	mux.ServeHTTP(archiveRec, archiveReq)
	if archiveRec.Code != http.StatusOK {
		t.Fatalf("archive again status = %d, want %d body=%s", archiveRec.Code, http.StatusOK, archiveRec.Body.String())
	}

	deleteArchivedReq := httptest.NewRequest(http.MethodDelete, "/boards/"+boardID+"/archive", nil)
	deleteArchivedReq.Header.Set("Authorization", "Bearer token")
	deleteArchivedRec := httptest.NewRecorder()
	mux.ServeHTTP(deleteArchivedRec, deleteArchivedReq)
	if deleteArchivedRec.Code != http.StatusNoContent {
		t.Fatalf("delete archived status = %d, want %d body=%s", deleteArchivedRec.Code, http.StatusNoContent, deleteArchivedRec.Body.String())
	}
}

func TestKanbanRestoreBoardOriginalTitleConflictReturns409(t *testing.T) {
	// Requirements: BOARD-024, API-023, PUBLIC-011
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	boardID := createBoard(t, mux)
	archiveReq := httptest.NewRequest(http.MethodPost, "/boards/"+boardID+"/archive", nil)
	archiveReq.Header.Set("Authorization", "Bearer token")
	archiveRec := httptest.NewRecorder()
	mux.ServeHTTP(archiveRec, archiveReq)
	if archiveRec.Code != http.StatusOK {
		t.Fatalf("archive status = %d, want %d body=%s", archiveRec.Code, http.StatusOK, archiveRec.Body.String())
	}

	_ = createBoard(t, mux)

	restoreReq := httptest.NewRequest(http.MethodPost, "/boards/"+boardID+"/restore", strings.NewReader(`{"titleMode":"original"}`))
	restoreReq.Header.Set("Authorization", "Bearer token")
	restoreReq.Header.Set("Content-Type", "application/json")
	restoreRec := httptest.NewRecorder()
	mux.ServeHTTP(restoreRec, restoreReq)

	if restoreRec.Code != http.StatusConflict {
		t.Fatalf("restore status = %d, want %d body=%s", restoreRec.Code, http.StatusConflict, restoreRec.Body.String())
	}

	var problem struct {
		Detail string `json:"detail"`
	}
	if err := json.Unmarshal(restoreRec.Body.Bytes(), &problem); err != nil {
		t.Fatalf("decode conflict response: %v", err)
	}
	if problem.Detail != "board title already exists" {
		t.Fatalf("problem detail = %q, want %q", problem.Detail, "board title already exists")
	}
}

func TestKanbanReorderColumnsAppliesOrderAtomically(t *testing.T) {
	// Requirements: COL-MOVE-001, COL-MOVE-002, COL-MOVE-003, COL-MOVE-004, COL-MOVE-007, COL-MOVE-011
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	boardID, columnAID, columnBID, columnCID := seedBoardABC(t, mux)

	body := strings.NewReader(`{"columnIds":["` + columnCID + `","` + columnAID + `","` + columnBID + `"]}`)
	request := httptest.NewRequest(http.MethodPut, "/boards/"+boardID+"/columns/order", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("reorder columns status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var reordered []struct {
		ID       string `json:"id"`
		Position int    `json:"position"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &reordered); err != nil {
		t.Fatalf("decode reorder columns response: %v", err)
	}
	if len(reordered) != 3 {
		t.Fatalf("reordered column count = %d, want 3", len(reordered))
	}

	for idx, id := range []string{columnCID, columnAID, columnBID} {
		if reordered[idx].ID != id {
			t.Fatalf("response order[%d] = %q, want %q", idx, reordered[idx].ID, id)
		}
		if reordered[idx].Position != idx {
			t.Fatalf("response position[%d] = %d, want %d", idx, reordered[idx].Position, idx)
		}
	}

	request = httptest.NewRequest(http.MethodGet, "/boards/"+boardID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("get board status = %d, want %d", recorder.Code, http.StatusOK)
	}

	var boardResponse struct {
		Columns []struct {
			ID       string `json:"id"`
			Position int    `json:"position"`
		} `json:"columns"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &boardResponse); err != nil {
		t.Fatalf("decode board response: %v", err)
	}
	for idx, id := range []string{columnCID, columnAID, columnBID} {
		if boardResponse.Columns[idx].ID != id {
			t.Fatalf("board order[%d] = %q, want %q", idx, boardResponse.Columns[idx].ID, id)
		}
	}
}

func TestKanbanReorderColumnsRejectsInvalidListWithoutApplying(t *testing.T) {
	// Requirements: COL-MOVE-003, COL-MOVE-006, COL-MOVE-011
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	boardID, columnAID, columnBID, columnCID := seedBoardABC(t, mux)

	body := strings.NewReader(`{"columnIds":["` + columnCID + `","` + columnAID + `"]}`)
	request := httptest.NewRequest(http.MethodPut, "/boards/"+boardID+"/columns/order", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusBadRequest, recorder.Body.String())
	}

	request = httptest.NewRequest(http.MethodGet, "/boards/"+boardID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("get board status = %d, want %d", recorder.Code, http.StatusOK)
	}

	var boardResponse struct {
		Columns []struct {
			ID string `json:"id"`
		} `json:"columns"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &boardResponse); err != nil {
		t.Fatalf("decode board response: %v", err)
	}
	wantIDs := []string{columnAID, columnBID, columnCID}
	for idx, id := range wantIDs {
		if boardResponse.Columns[idx].ID != id {
			t.Fatalf("board order after failed reorder[%d] = %q, want %q", idx, boardResponse.Columns[idx].ID, id)
		}
	}
}

func TestKanbanReorderColumnsRejectsEmptyOrNullList(t *testing.T) {
	// Requirements: COL-MOVE-006, COL-MOVE-011
	t.Parallel()

	testCases := []struct {
		name string
		body string
	}{
		{name: "empty list", body: `{"columnIds":[]}`},
		{name: "null list", body: `{"columnIds":null}`},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			repo := kanban.NewService(kanban.NewMemoryRepository())
			mux := newKanbanMuxForUser(repo, "user-1")

			boardID, columnAID, columnBID, columnCID := seedBoardABC(t, mux)

			request := httptest.NewRequest(http.MethodPut, "/boards/"+boardID+"/columns/order", strings.NewReader(tc.body))
			request.Header.Set("Content-Type", "application/json")
			request.Header.Set("Authorization", "Bearer token")
			recorder := httptest.NewRecorder()
			mux.ServeHTTP(recorder, request)

			if recorder.Code != http.StatusBadRequest && recorder.Code != http.StatusUnprocessableEntity {
				t.Fatalf("status = %d, want %d or %d body=%s", recorder.Code, http.StatusBadRequest, http.StatusUnprocessableEntity, recorder.Body.String())
			}

			request = httptest.NewRequest(http.MethodGet, "/boards/"+boardID, nil)
			request.Header.Set("Authorization", "Bearer token")
			recorder = httptest.NewRecorder()
			mux.ServeHTTP(recorder, request)

			if recorder.Code != http.StatusOK {
				t.Fatalf("get board status = %d, want %d", recorder.Code, http.StatusOK)
			}

			var boardResponse struct {
				Columns []struct {
					ID string `json:"id"`
				} `json:"columns"`
			}
			if err := json.Unmarshal(recorder.Body.Bytes(), &boardResponse); err != nil {
				t.Fatalf("decode board response: %v", err)
			}

			wantIDs := []string{columnAID, columnBID, columnCID}
			for idx, id := range wantIDs {
				if boardResponse.Columns[idx].ID != id {
					t.Fatalf("board order after failed reorder[%d] = %q, want %q", idx, boardResponse.Columns[idx].ID, id)
				}
			}
		})
	}
}

func TestKanbanReorderColumnsReturnsNotFoundForMissingBoard(t *testing.T) {
	// Requirements: COL-MOVE-006, API-003
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	body := strings.NewReader(`{"columnIds":["a"]}`)
	request := httptest.NewRequest(http.MethodPut, "/boards/00000000-0000-0000-0000-000000000123/columns/order", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusNotFound, recorder.Body.String())
	}
}

func TestKanbanReorderColumnsReturnsForbiddenForOtherOwner(t *testing.T) {
	// Requirements: COL-MOVE-005, COL-MOVE-006, API-003
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	muxOwner := newKanbanMuxForUser(repo, "owner")

	boardID, columnAID, columnBID, columnCID := seedBoardABC(t, muxOwner)

	muxIntruder := newKanbanMuxForUser(repo, "intruder")
	body := strings.NewReader(`{"columnIds":["` + columnCID + `","` + columnAID + `","` + columnBID + `"]}`)
	request := httptest.NewRequest(http.MethodPut, "/boards/"+boardID+"/columns/order", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	muxIntruder.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusForbidden, recorder.Body.String())
	}
}

func TestKanbanReorderTasksAppliesOrderAtomically(t *testing.T) {
	// Requirements: API-005, TASK-005, TASK-006, TASK-007
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	boardID := createBoard(t, mux)
	columnAID := createColumn(t, mux, boardID)
	columnBID := createColumn(t, mux, boardID)
	taskA0ID := createTask(t, mux, boardID, columnAID)
	taskA1ID := createTask(t, mux, boardID, columnAID)
	taskB0ID := createTask(t, mux, boardID, columnBID)

	body := strings.NewReader(`{"columns":[{"columnId":"` + columnAID + `","taskIds":["` + taskA1ID + `"]},{"columnId":"` + columnBID + `","taskIds":["` + taskB0ID + `","` + taskA0ID + `"]}]}`)
	request := httptest.NewRequest(http.MethodPut, "/boards/"+boardID+"/tasks/order", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("reorder tasks status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	request = httptest.NewRequest(http.MethodGet, "/boards/"+boardID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("get board status = %d, want %d", recorder.Code, http.StatusOK)
	}

	var boardResponse struct {
		Tasks []struct {
			ID       string `json:"id"`
			ColumnID string `json:"columnId"`
			Position int    `json:"position"`
		} `json:"tasks"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &boardResponse); err != nil {
		t.Fatalf("decode board response: %v", err)
	}

	tasksByID := make(map[string]struct {
		ColumnID string
		Position int
	}, len(boardResponse.Tasks))
	for _, task := range boardResponse.Tasks {
		tasksByID[task.ID] = struct {
			ColumnID string
			Position int
		}{ColumnID: task.ColumnID, Position: task.Position}
	}

	if got := tasksByID[taskA1ID]; got.ColumnID != columnAID || got.Position != 0 {
		t.Fatalf("task A1 = %+v, want column=%q position=0", got, columnAID)
	}
	if got := tasksByID[taskB0ID]; got.ColumnID != columnBID || got.Position != 0 {
		t.Fatalf("task B0 = %+v, want column=%q position=0", got, columnBID)
	}
	if got := tasksByID[taskA0ID]; got.ColumnID != columnBID || got.Position != 1 {
		t.Fatalf("task A0 = %+v, want column=%q position=1", got, columnBID)
	}
}

func TestKanbanReorderTasksRejectsInvalidListWithoutApplying(t *testing.T) {
	// Requirement: API-005
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	boardID := createBoard(t, mux)
	columnAID := createColumn(t, mux, boardID)
	columnBID := createColumn(t, mux, boardID)
	taskA0ID := createTask(t, mux, boardID, columnAID)
	taskA1ID := createTask(t, mux, boardID, columnAID)
	taskB0ID := createTask(t, mux, boardID, columnBID)

	body := strings.NewReader(`{"columns":[{"columnId":"` + columnAID + `","taskIds":["` + taskA1ID + `"]},{"columnId":"` + columnBID + `","taskIds":["` + taskB0ID + `","` + taskA1ID + `"]}]}`)
	request := httptest.NewRequest(http.MethodPut, "/boards/"+boardID+"/tasks/order", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusBadRequest, recorder.Body.String())
	}

	request = httptest.NewRequest(http.MethodGet, "/boards/"+boardID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("get board status = %d, want %d", recorder.Code, http.StatusOK)
	}

	var boardResponse struct {
		Tasks []struct {
			ID       string `json:"id"`
			ColumnID string `json:"columnId"`
			Position int    `json:"position"`
		} `json:"tasks"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &boardResponse); err != nil {
		t.Fatalf("decode board response: %v", err)
	}

	tasksByID := make(map[string]struct {
		ColumnID string
		Position int
	}, len(boardResponse.Tasks))
	for _, task := range boardResponse.Tasks {
		tasksByID[task.ID] = struct {
			ColumnID string
			Position int
		}{ColumnID: task.ColumnID, Position: task.Position}
	}
	if got := tasksByID[taskA0ID]; got.ColumnID != columnAID || got.Position != 0 {
		t.Fatalf("task A0 after failed reorder = %+v, want column=%q position=0", got, columnAID)
	}
	if got := tasksByID[taskA1ID]; got.ColumnID != columnAID || got.Position != 1 {
		t.Fatalf("task A1 after failed reorder = %+v, want column=%q position=1", got, columnAID)
	}
	if got := tasksByID[taskB0ID]; got.ColumnID != columnBID || got.Position != 0 {
		t.Fatalf("task B0 after failed reorder = %+v, want column=%q position=0", got, columnBID)
	}
}

func TestKanbanReorderTasksReturnsNotFoundForMissingBoard(t *testing.T) {
	// Requirement: API-005
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	body := strings.NewReader(`{"columns":[{"columnId":"00000000-0000-0000-0000-000000000111","taskIds":[]}]}`)
	request := httptest.NewRequest(http.MethodPut, "/boards/00000000-0000-0000-0000-000000000123/tasks/order", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusNotFound, recorder.Body.String())
	}
}

func TestKanbanReorderTasksReturnsForbiddenForOtherOwner(t *testing.T) {
	// Requirement: API-005
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	muxOwner := newKanbanMuxForUser(repo, "owner")

	boardID := createBoard(t, muxOwner)
	columnAID := createColumn(t, muxOwner, boardID)
	columnBID := createColumn(t, muxOwner, boardID)
	taskA0ID := createTask(t, muxOwner, boardID, columnAID)
	taskA1ID := createTask(t, muxOwner, boardID, columnAID)
	taskB0ID := createTask(t, muxOwner, boardID, columnBID)

	muxIntruder := newKanbanMuxForUser(repo, "intruder")
	body := strings.NewReader(`{"columns":[{"columnId":"` + columnAID + `","taskIds":["` + taskA1ID + `"]},{"columnId":"` + columnBID + `","taskIds":["` + taskB0ID + `","` + taskA0ID + `"]}]}`)
	request := httptest.NewRequest(http.MethodPut, "/boards/"+boardID+"/tasks/order", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	muxIntruder.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusForbidden, recorder.Body.String())
	}
}

func TestKanbanExportTasksReturnsVersionedPayload(t *testing.T) {
	// Requirements: API-007, BOARD-005, BOARD-007
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	boardID := createBoard(t, mux)
	columnAID := createColumnWithTitle(t, mux, boardID, "Backlog")
	columnBID := createColumnWithTitle(t, mux, boardID, "Done")
	_ = createTaskWithTitle(t, mux, boardID, columnAID, "Plan", "notes")
	_ = createTaskWithTitle(t, mux, boardID, columnAID, "Build", "")
	_ = createTaskWithTitle(t, mux, boardID, columnBID, "Ship", "")

	requestBody, _ := json.Marshal(map[string]any{
		"boardIds": []string{boardID},
	})
	request := httptest.NewRequest(http.MethodPost, "/boards/tasks/export", bytes.NewReader(requestBody))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var bundle struct {
		FormatVersion int    `json:"formatVersion"`
		ExportedAt    string `json:"exportedAt"`
		Boards        []struct {
			SourceBoardID    string `json:"sourceBoardId"`
			SourceBoardTitle string `json:"sourceBoardTitle"`
			Payload          struct {
				FormatVersion int    `json:"formatVersion"`
				BoardTitle    string `json:"boardTitle"`
				ExportedAt    string `json:"exportedAt"`
				Columns       []struct {
					Title string `json:"title"`
					Tasks []struct {
						Title       string `json:"title"`
						Description string `json:"description"`
					} `json:"tasks"`
				} `json:"columns"`
			} `json:"payload"`
		} `json:"boards"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &bundle); err != nil {
		t.Fatalf("decode export response: %v", err)
	}

	if bundle.FormatVersion != 2 {
		t.Fatalf("bundle formatVersion = %d, want 2", bundle.FormatVersion)
	}
	if len(bundle.Boards) != 1 {
		t.Fatalf("bundle boards count = %d, want 1", len(bundle.Boards))
	}
	payload := bundle.Boards[0].Payload
	if payload.FormatVersion != 1 {
		t.Fatalf("formatVersion = %d, want 1", payload.FormatVersion)
	}
	if payload.BoardTitle != "Main Board" {
		t.Fatalf("boardTitle = %q, want %q", payload.BoardTitle, "Main Board")
	}
	if strings.TrimSpace(payload.ExportedAt) == "" {
		t.Fatal("expected exportedAt")
	}
	if len(payload.Columns) != 2 {
		t.Fatalf("column count = %d, want 2", len(payload.Columns))
	}
	if payload.Columns[0].Title != "Backlog" || payload.Columns[1].Title != "Done" {
		t.Fatalf("column order = [%q, %q], want [Backlog, Done]", payload.Columns[0].Title, payload.Columns[1].Title)
	}
	if len(payload.Columns[0].Tasks) != 2 || payload.Columns[0].Tasks[0].Title != "Plan" || payload.Columns[0].Tasks[1].Title != "Build" {
		t.Fatalf("backlog tasks = %+v, want [Plan, Build]", payload.Columns[0].Tasks)
	}
	if len(payload.Columns[1].Tasks) != 1 || payload.Columns[1].Tasks[0].Title != "Ship" {
		t.Fatalf("done tasks = %+v, want [Ship]", payload.Columns[1].Tasks)
	}
}

func TestKanbanExportTasksBundleReturnsSelectedBoardSnapshots(t *testing.T) {
	// Requirements: API-017, API-019
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	boardAID := createBoardWithTitle(t, mux, "Project A")
	boardBID := createBoardWithTitle(t, mux, "Project B")
	columnAID := createColumnWithTitle(t, mux, boardAID, "Backlog")
	columnBID := createColumnWithTitle(t, mux, boardBID, "Done")
	_ = createTaskWithTitle(t, mux, boardAID, columnAID, "Plan A", "")
	_ = createTaskWithTitle(t, mux, boardBID, columnBID, "Ship B", "")

	requestBody, _ := json.Marshal(map[string]any{
		"boardIds": []string{boardAID, boardBID},
	})
	request := httptest.NewRequest(http.MethodPost, "/boards/tasks/export", bytes.NewReader(requestBody))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var payload struct {
		FormatVersion int    `json:"formatVersion"`
		ExportedAt    string `json:"exportedAt"`
		Boards        []struct {
			SourceBoardID    string `json:"sourceBoardId"`
			SourceBoardTitle string `json:"sourceBoardTitle"`
			Payload          struct {
				FormatVersion int `json:"formatVersion"`
				Columns       []struct {
					Tasks []struct {
						Title string `json:"title"`
					} `json:"tasks"`
				} `json:"columns"`
			} `json:"payload"`
		} `json:"boards"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode bundle export response: %v", err)
	}

	if payload.FormatVersion != 2 {
		t.Fatalf("formatVersion = %d, want 2", payload.FormatVersion)
	}
	if strings.TrimSpace(payload.ExportedAt) == "" {
		t.Fatal("expected exportedAt")
	}
	if len(payload.Boards) != 2 {
		t.Fatalf("boards count = %d, want 2", len(payload.Boards))
	}
	if payload.Boards[0].SourceBoardID != boardAID || payload.Boards[0].SourceBoardTitle != "Project A" {
		t.Fatalf("first snapshot = %+v", payload.Boards[0])
	}
	if payload.Boards[1].SourceBoardID != boardBID || payload.Boards[1].SourceBoardTitle != "Project B" {
		t.Fatalf("second snapshot = %+v", payload.Boards[1])
	}
	if payload.Boards[0].Payload.FormatVersion != 1 || payload.Boards[1].Payload.FormatVersion != 1 {
		t.Fatalf("nested format versions = %d,%d, want 1,1", payload.Boards[0].Payload.FormatVersion, payload.Boards[1].Payload.FormatVersion)
	}
}

func TestKanbanExportTasksBundleRejectsInvalidBoardID(t *testing.T) {
	// Requirement: API-004
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	requestBody, _ := json.Marshal(map[string]any{
		"boardIds": []string{"not-a-uuid"},
	})
	request := httptest.NewRequest(http.MethodPost, "/boards/tasks/export", bytes.NewReader(requestBody))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusBadRequest, recorder.Body.String())
	}
}

func TestKanbanImportTasksBundleImportsOnlySelectedSnapshots(t *testing.T) {
	// Requirements: API-017, API-019
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	boardAID := createBoardWithTitle(t, mux, "Project A")
	boardBID := createBoardWithTitle(t, mux, "Project B")
	boardCID := createBoardWithTitle(t, mux, "Project C")

	bundle := map[string]any{
		"formatVersion": 2,
		"exportedAt":    "2026-04-24T00:00:00Z",
		"boards": []map[string]any{
			{
				"sourceBoardId":    boardAID,
				"sourceBoardTitle": "Project A",
				"payload": map[string]any{
					"formatVersion": 1,
					"boardTitle":    "Project A",
					"exportedAt":    "2026-04-24T00:00:00Z",
					"columns": []map[string]any{{
						"title": "Backlog",
						"tasks": []map[string]any{{"title": "Plan A", "description": ""}},
					}},
				},
			},
			{
				"sourceBoardId":    boardBID,
				"sourceBoardTitle": "Project B",
				"payload": map[string]any{
					"formatVersion": 1,
					"boardTitle":    "Project B",
					"exportedAt":    "2026-04-24T00:00:00Z",
					"columns": []map[string]any{{
						"title": "Done",
						"tasks": []map[string]any{{"title": "Ship B", "description": ""}},
					}},
				},
			},
			{
				"sourceBoardId":    boardCID,
				"sourceBoardTitle": "Project C",
				"payload": map[string]any{
					"formatVersion": 1,
					"boardTitle":    "Project C",
					"exportedAt":    "2026-04-24T00:00:00Z",
					"columns": []map[string]any{{
						"title": "Review",
						"tasks": []map[string]any{{"title": "Skip C", "description": ""}},
					}},
				},
			},
		},
	}
	requestBody, _ := json.Marshal(map[string]any{
		"sourceBoardIds": []string{boardAID, boardBID},
		"bundle":         bundle,
	})
	request := httptest.NewRequest(http.MethodPost, "/boards/tasks/import", bytes.NewReader(requestBody))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var response struct {
		Results []struct {
			SourceBoardID      string `json:"sourceBoardId"`
			DestinationBoardID string `json:"destinationBoardId"`
			ImportedTaskCount  int    `json:"importedTaskCount"`
		} `json:"results"`
		TotalImportedTaskCount int `json:"totalImportedTaskCount"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode bundle import response: %v", err)
	}
	if len(response.Results) != 2 {
		t.Fatalf("results count = %d, want 2", len(response.Results))
	}
	if response.TotalImportedTaskCount != 2 {
		t.Fatalf("totalImportedTaskCount = %d, want 2", response.TotalImportedTaskCount)
	}

	boardA := getBoardDetails(t, mux, boardAID)
	if !boardHasTaskTitle(boardA, "Plan A") {
		t.Fatalf("board A tasks = %+v, want Plan A", boardA.Tasks)
	}
	boardB := getBoardDetails(t, mux, boardBID)
	if !boardHasTaskTitle(boardB, "Ship B") {
		t.Fatalf("board B tasks = %+v, want Ship B", boardB.Tasks)
	}
	boardC := getBoardDetails(t, mux, boardCID)
	if boardHasTaskTitle(boardC, "Skip C") {
		t.Fatalf("board C tasks = %+v, did not expect Skip C", boardC.Tasks)
	}
}

func TestKanbanImportTasksBundleRejectsInvalidSourceBoardID(t *testing.T) {
	// Requirement: API-004
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	boardID := createBoardWithTitle(t, mux, "Project A")

	requestBody, _ := json.Marshal(map[string]any{
		"sourceBoardIds": []string{"not-a-uuid"},
		"bundle": map[string]any{
			"formatVersion": 2,
			"exportedAt":    "2026-04-24T00:00:00Z",
			"boards": []map[string]any{
				{
					"sourceBoardId":    boardID,
					"sourceBoardTitle": "Project A",
					"payload": map[string]any{
						"formatVersion": 1,
						"boardTitle":    "Project A",
						"exportedAt":    "2026-04-24T00:00:00Z",
						"columns":       []map[string]any{},
					},
				},
			},
		},
	})
	request := httptest.NewRequest(http.MethodPost, "/boards/tasks/import", bytes.NewReader(requestBody))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusBadRequest, recorder.Body.String())
	}
}

func TestKanbanImportTasksBundleIsAtomicPerDestinationBoard(t *testing.T) {
	// Requirement: API-018
	t.Parallel()

	baseRepo := kanban.NewService(kanban.NewMemoryRepository())
	failingRepo := &failOnCreateTaskRepository{
		Repository: baseRepo,
		failAfter:  2,
	}
	mux := newKanbanMuxForUser(failingRepo, "user-1")

	boardAID := createBoardWithTitle(t, mux, "Project A")
	boardBID := createBoardWithTitle(t, mux, "Project B")

	requestBody, _ := json.Marshal(map[string]any{
		"sourceBoardIds": []string{boardAID, boardBID},
		"bundle": map[string]any{
			"formatVersion": 2,
			"exportedAt":    "2026-04-24T00:00:00Z",
			"boards": []map[string]any{
				{
					"sourceBoardId":    boardAID,
					"sourceBoardTitle": "Project A",
					"payload": map[string]any{
						"formatVersion": 1,
						"boardTitle":    "Project A",
						"exportedAt":    "2026-04-24T00:00:00Z",
						"columns": []map[string]any{{
							"title": "Backlog",
							"tasks": []map[string]any{{"title": "A-1", "description": ""}},
						}},
					},
				},
				{
					"sourceBoardId":    boardBID,
					"sourceBoardTitle": "Project B",
					"payload": map[string]any{
						"formatVersion": 1,
						"boardTitle":    "Project B",
						"exportedAt":    "2026-04-24T00:00:00Z",
						"columns": []map[string]any{{
							"title": "Done",
							"tasks": []map[string]any{{"title": "B-1", "description": ""}, {"title": "B-2", "description": ""}},
						}},
					},
				},
			},
		},
	})
	request := httptest.NewRequest(http.MethodPost, "/boards/tasks/import", bytes.NewReader(requestBody))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusBadRequest, recorder.Body.String())
	}

	boardA := getBoardDetails(t, mux, boardAID)
	if !boardHasTaskTitle(boardA, "A-1") {
		t.Fatalf("board A tasks = %+v, want A-1", boardA.Tasks)
	}
	boardB := getBoardDetails(t, mux, boardBID)
	if boardHasTaskTitle(boardB, "B-1") || boardHasTaskTitle(boardB, "B-2") {
		t.Fatalf("board B tasks = %+v, expected rollback", boardB.Tasks)
	}
}

func TestKanbanImportTasksCreatesColumnsAndTasks(t *testing.T) {
	// Requirements: API-007, API-008, BOARD-006, BOARD-008
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	boardID := createBoard(t, mux)
	_ = createColumnWithTitle(t, mux, boardID, "Backlog")

	requestPayload := map[string]any{
		"sourceBoardIds": []string{boardID},
		"bundle": map[string]any{
			"formatVersion": 2,
			"exportedAt":    "2026-04-24T00:00:00Z",
			"boards": []map[string]any{
				{
					"sourceBoardId":    boardID,
					"sourceBoardTitle": "Imported",
					"payload": map[string]any{
						"formatVersion": 1,
						"boardTitle":    "Imported",
						"exportedAt":    "2026-04-24T00:00:00Z",
						"columns": []map[string]any{
							{
								"title": "Backlog",
								"tasks": []map[string]any{
									{"title": "Plan", "description": "notes"},
									{"title": "   ", "description": "skip"},
								},
							},
							{
								"title": "Done",
								"tasks": []map[string]any{
									{"title": "Ship", "description": ""},
								},
							},
							{
								"title": "Done",
								"tasks": []map[string]any{
									{"title": "Celebrate", "description": ""},
								},
							},
						},
					},
				},
			},
		},
	}
	body, _ := json.Marshal(requestPayload)
	request := httptest.NewRequest(http.MethodPost, "/boards/tasks/import", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var response struct {
		Results []struct {
			CreatedColumnCount int `json:"createdColumnCount"`
			ImportedTaskCount  int `json:"importedTaskCount"`
		} `json:"results"`
		TotalCreatedColumnCount int `json:"totalCreatedColumnCount"`
		TotalImportedTaskCount  int `json:"totalImportedTaskCount"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode import response: %v", err)
	}
	if response.TotalCreatedColumnCount != 1 {
		t.Fatalf("totalCreatedColumnCount = %d, want 1", response.TotalCreatedColumnCount)
	}
	if response.TotalImportedTaskCount != 3 {
		t.Fatalf("totalImportedTaskCount = %d, want 3", response.TotalImportedTaskCount)
	}

	request = httptest.NewRequest(http.MethodGet, "/boards/"+boardID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("get board status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var boardResponse struct {
		Columns []struct {
			ID    string `json:"id"`
			Title string `json:"title"`
		} `json:"columns"`
		Tasks []struct {
			ColumnID string `json:"columnId"`
			Title    string `json:"title"`
		} `json:"tasks"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &boardResponse); err != nil {
		t.Fatalf("decode board response: %v", err)
	}

	columnIDByTitle := make(map[string]string, len(boardResponse.Columns))
	for _, column := range boardResponse.Columns {
		if _, exists := columnIDByTitle[column.Title]; !exists {
			columnIDByTitle[column.Title] = column.ID
		}
	}
	doneID, ok := columnIDByTitle["Done"]
	if !ok {
		t.Fatalf("missing imported Done column: %+v", boardResponse.Columns)
	}

	doneTaskTitles := make([]string, 0)
	for _, task := range boardResponse.Tasks {
		if task.ColumnID == doneID {
			doneTaskTitles = append(doneTaskTitles, task.Title)
		}
	}
	if len(doneTaskTitles) != 2 {
		t.Fatalf("done task count = %d, want 2 (tasks=%+v)", len(doneTaskTitles), boardResponse.Tasks)
	}
}

func TestKanbanImportTasksRollsBackOnFailure(t *testing.T) {
	// Requirement: API-009
	t.Parallel()

	baseRepo := kanban.NewService(kanban.NewMemoryRepository())
	failingRepo := &failOnCreateTaskRepository{
		Repository: baseRepo,
		failAfter:  1,
	}
	mux := newKanbanMuxForUser(failingRepo, "user-1")

	boardID := createBoard(t, mux)
	_ = createColumnWithTitle(t, mux, boardID, "Backlog")

	body, _ := json.Marshal(map[string]any{
		"sourceBoardIds": []string{boardID},
		"bundle": map[string]any{
			"formatVersion": 2,
			"exportedAt":    "2026-04-24T00:00:00Z",
			"boards": []map[string]any{
				{
					"sourceBoardId":    boardID,
					"sourceBoardTitle": "Imported",
					"payload": map[string]any{
						"formatVersion": 1,
						"boardTitle":    "Imported",
						"exportedAt":    "2026-04-24T00:00:00Z",
						"columns": []map[string]any{
							{
								"title": "Done",
								"tasks": []map[string]any{{"title": "First", "description": ""}, {"title": "Second", "description": ""}},
							},
						},
					},
				},
			},
		},
	})
	request := httptest.NewRequest(http.MethodPost, "/boards/tasks/import", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusBadRequest, recorder.Body.String())
	}

	request = httptest.NewRequest(http.MethodGet, "/boards/"+boardID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder = httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("get board status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var boardResponse struct {
		Columns []struct {
			Title string `json:"title"`
		} `json:"columns"`
		Tasks []struct {
			Title string `json:"title"`
		} `json:"tasks"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &boardResponse); err != nil {
		t.Fatalf("decode board response: %v", err)
	}

	if len(boardResponse.Columns) != 1 || boardResponse.Columns[0].Title != "Backlog" {
		t.Fatalf("columns after failed import = %+v, want only Backlog", boardResponse.Columns)
	}
	if len(boardResponse.Tasks) != 0 {
		t.Fatalf("tasks after failed import = %+v, want empty", boardResponse.Tasks)
	}
}

func TestKanbanImportTasksRejectsUnsupportedFormatVersion(t *testing.T) {
	// Requirement: API-008
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	mux := newKanbanMuxForUser(repo, "user-1")

	boardID := createBoard(t, mux)
	payload := `{"sourceBoardIds":["` + boardID + `"],"bundle":{"formatVersion":99,"exportedAt":"2026-04-24T00:00:00Z","boards":[{"sourceBoardId":"` + boardID + `","sourceBoardTitle":"Main","payload":{"formatVersion":1,"boardTitle":"Main","exportedAt":"2026-04-24T00:00:00Z","columns":[]}}]}}`
	request := httptest.NewRequest(http.MethodPost, "/boards/tasks/import", strings.NewReader(payload))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusBadRequest, recorder.Body.String())
	}
}

func TestKanbanImportTasksTransactionalFailureDoesNotFallbackToCompensation(t *testing.T) {
	// Requirement: API-009
	t.Parallel()

	baseRepo := kanban.NewService(kanban.NewMemoryRepository())
	repo := &transactionalFailOnCreateTaskRepository{
		Repository: baseRepo,
		failAfter:  1,
	}
	mux := newKanbanMuxForUser(repo, "user-1")

	boardID := createBoard(t, mux)
	_ = createColumnWithTitle(t, mux, boardID, "Backlog")

	body, _ := json.Marshal(map[string]any{
		"sourceBoardIds": []string{boardID},
		"bundle": map[string]any{
			"formatVersion": 2,
			"exportedAt":    "2026-04-24T00:00:00Z",
			"boards": []map[string]any{
				{
					"sourceBoardId":    boardID,
					"sourceBoardTitle": "Imported",
					"payload": map[string]any{
						"formatVersion": 1,
						"boardTitle":    "Imported",
						"exportedAt":    "2026-04-24T00:00:00Z",
						"columns": []map[string]any{
							{
								"title": "Backlog",
								"tasks": []map[string]any{{"title": "First", "description": ""}, {"title": "Second", "description": ""}},
							},
						},
					},
				},
			},
		},
	})
	request := httptest.NewRequest(http.MethodPost, "/boards/tasks/import", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusBadRequest, recorder.Body.String())
	}

	if repo.runInTransactionCalls != 1 {
		t.Fatalf("runInTransactionCalls = %d, want 1", repo.runInTransactionCalls)
	}
	if repo.deleteTaskCalls != 0 {
		t.Fatalf("deleteTaskCalls = %d, want 0", repo.deleteTaskCalls)
	}
	if repo.deleteColumnCalls != 0 {
		t.Fatalf("deleteColumnCalls = %d, want 0", repo.deleteColumnCalls)
	}
}

func newKanbanMuxForUser(repo kanban.Repository, userID string) *http.ServeMux {
	mux, api := NewAPI()
	Register(api, Dependencies{
		KanbanRepo: repo,
		Verifier: &stubVerifier{identity: auth.Identity{
			UserID: userID,
			Email:  userID + "@example.com",
		}},
	})
	return mux
}

func seedBoardABC(t *testing.T, mux *http.ServeMux) (string, string, string, string) {
	t.Helper()

	boardID := createBoard(t, mux)
	columnAID := createColumn(t, mux, boardID)
	columnBID := createColumn(t, mux, boardID)
	columnCID := createColumn(t, mux, boardID)
	return boardID, columnAID, columnBID, columnCID
}

func createBoard(t *testing.T, mux *http.ServeMux) string {
	t.Helper()
	return createBoardWithTitle(t, mux, "Main Board")
}

func createBoardWithTitle(t *testing.T, mux *http.ServeMux, title string) string {
	t.Helper()

	body, _ := json.Marshal(map[string]string{"title": title})
	request := httptest.NewRequest(http.MethodPost, "/boards", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("create board status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var response struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode board create response: %v", err)
	}

	if response.ID == "" {
		t.Fatal("expected board id")
	}

	return response.ID
}

func createColumn(t *testing.T, mux *http.ServeMux, boardID string) string {
	t.Helper()
	return createColumnWithTitle(t, mux, boardID, "Doing")
}

func createColumnWithTitle(t *testing.T, mux *http.ServeMux, boardID, title string) string {
	t.Helper()

	body, _ := json.Marshal(map[string]string{"title": title})
	request := httptest.NewRequest(http.MethodPost, "/boards/"+boardID+"/columns", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("create column status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var response struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode column create response: %v", err)
	}

	if response.ID == "" {
		t.Fatal("expected column id")
	}

	return response.ID
}

func createTask(t *testing.T, mux *http.ServeMux, boardID, columnID string) string {
	t.Helper()
	return createTaskWithTitle(t, mux, boardID, columnID, "Ship feature", "Backend first")
}

func createTaskWithTitle(t *testing.T, mux *http.ServeMux, boardID, columnID, title, description string) string {
	t.Helper()

	body, _ := json.Marshal(map[string]string{"columnId": columnID, "title": title, "description": description})
	request := httptest.NewRequest(http.MethodPost, "/boards/"+boardID+"/tasks", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("create task status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var response struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode task create response: %v", err)
	}

	if response.ID == "" {
		t.Fatal("expected task id")
	}

	return response.ID
}

type boardDetailsTestResponse struct {
	Columns []struct {
		ID    string `json:"id"`
		Title string `json:"title"`
	} `json:"columns"`
	Tasks []struct {
		ColumnID string `json:"columnId"`
		Title    string `json:"title"`
	} `json:"tasks"`
}

func getBoardDetails(t *testing.T, mux *http.ServeMux, boardID string) boardDetailsTestResponse {
	t.Helper()

	request := httptest.NewRequest(http.MethodGet, "/boards/"+boardID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("get board status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var response boardDetailsTestResponse
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode board response: %v", err)
	}

	return response
}

func boardHasTaskTitle(response boardDetailsTestResponse, title string) bool {
	for _, task := range response.Tasks {
		if task.Title == title {
			return true
		}
	}
	return false
}
