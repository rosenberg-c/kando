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

func TestHelloReturnsTextPlain(t *testing.T) {
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

func TestLoginBlockedReturnsRetryAfter(t *testing.T) {
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

func TestOpenAPIDefinesHelloAsTextPlain(t *testing.T) {
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
	request = httptest.NewRequest(http.MethodPost, "/boards/not-found/todos", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("todo status = %d, want %d", recorder.Code, http.StatusNotFound)
	}
}

func TestKanbanValidationReturnsBadRequest(t *testing.T) {
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
	request = httptest.NewRequest(http.MethodPost, "/boards/"+boardID+"/todos", body)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("todo bad request status = %d, want %d", recorder.Code, http.StatusBadRequest)
	}
}

func TestOpenAPIDefinesKanbanPaths(t *testing.T) {
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
	assertPathMethod("/boards/{boardId}/todos", http.MethodPost)
	assertPathMethod("/boards/{boardId}/todos/{todoId}", http.MethodPatch)
	assertPathMethod("/boards/{boardId}/todos/{todoId}", http.MethodDelete)
}

func TestKanbanBoardColumnTodoCRUD(t *testing.T) {
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	verifier := &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "user@example.com"}}
	mux, api := NewAPI()
	Register(api, Dependencies{KanbanRepo: repo, Verifier: verifier})

	boardID := createBoard(t, mux)
	columnID := createColumn(t, mux, boardID)
	todoID := createTodo(t, mux, boardID, columnID)

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
		Todos []struct {
			ID string `json:"id"`
		} `json:"todos"`
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
	if len(response.Todos) != 1 || response.Todos[0].ID != todoID {
		t.Fatalf("todos = %+v, expected todo %q", response.Todos, todoID)
	}
}

func TestKanbanDeleteColumnWithTodosReturnsConflict(t *testing.T) {
	t.Parallel()

	repo := kanban.NewService(kanban.NewMemoryRepository())
	verifier := &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "user@example.com"}}
	mux, api := NewAPI()
	Register(api, Dependencies{KanbanRepo: repo, Verifier: verifier})

	boardID := createBoard(t, mux)
	columnID := createColumn(t, mux, boardID)
	_ = createTodo(t, mux, boardID, columnID)

	request := httptest.NewRequest(http.MethodDelete, "/boards/"+boardID+"/columns/"+columnID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusConflict {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusConflict, recorder.Body.String())
	}
}

func createBoard(t *testing.T, mux *http.ServeMux) string {
	t.Helper()

	body, _ := json.Marshal(map[string]string{"title": "Main Board"})
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

	body, _ := json.Marshal(map[string]string{"title": "Doing"})
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

func createTodo(t *testing.T, mux *http.ServeMux, boardID, columnID string) string {
	t.Helper()

	body, _ := json.Marshal(map[string]string{"columnId": columnID, "title": "Ship feature", "description": "Backend first"})
	request := httptest.NewRequest(http.MethodPost, "/boards/"+boardID+"/todos", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("create todo status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var response struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode todo create response: %v", err)
	}

	if response.ID == "" {
		t.Fatal("expected todo id")
	}

	return response.ID
}
