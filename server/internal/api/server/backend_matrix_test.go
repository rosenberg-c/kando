package server

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"go_macos_todo/server/internal/appwrite"
	"go_macos_todo/server/internal/auth"
	"go_macos_todo/server/internal/kanban"
)

func TestKanbanAPIBackendMatrixBoardCreateAndList(t *testing.T) {
	backend := strings.ToLower(strings.TrimSpace(os.Getenv("API_TEST_BACKEND")))
	if backend == "" {
		t.Skip("set API_TEST_BACKEND to sqlite or appwrite")
	}

	ownerUserID := "api-matrix-" + strings.ReplaceAll(time.Now().UTC().Format("20060102150405.000000000"), ".", "")
	repo := newBackendMatrixRepository(t, backend)
	mux, api := NewAPI()
	Register(api, Dependencies{
		KanbanRepo: repo,
		Verifier:   &stubVerifier{identity: auth.Identity{UserID: ownerUserID}},
	})

	createdBoardIDs := make([]string, 0, 2)
	t.Cleanup(func() {
		for _, boardID := range createdBoardIDs {
			_ = repo.DeleteBoard(context.Background(), ownerUserID, boardID)
		}
	})

	boardA := createBoardWithTitleForMatrix(t, mux, "Matrix A")
	boardB := createBoardWithTitleForMatrix(t, mux, "Matrix B")
	createdBoardIDs = append(createdBoardIDs, boardA, boardB)

	request := httptest.NewRequest(http.MethodGet, "/boards", nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("list boards status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}

	var response []struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode list boards response: %v", err)
	}

	foundA := false
	foundB := false
	for _, board := range response {
		if board.ID == boardA {
			foundA = true
		}
		if board.ID == boardB {
			foundB = true
		}
	}
	if !foundA || !foundB {
		t.Fatalf("expected both created boards in list; foundA=%v foundB=%v", foundA, foundB)
	}
}

func newBackendMatrixRepository(t *testing.T, backend string) kanban.Repository {
	t.Helper()

	switch backend {
	case "sqlite":
		repo, err := kanban.NewSQLiteRepository(filepath.Join(t.TempDir(), "api-matrix.sqlite"))
		if err != nil {
			t.Fatalf("create sqlite repository: %v", err)
		}
		t.Cleanup(func() {
			if err := repo.Close(); err != nil {
				t.Fatalf("close sqlite repository: %v", err)
			}
		})
		return kanban.NewService(repo)
	case "appwrite":
		endpoint := strings.TrimSpace(os.Getenv("APPWRITE_ENDPOINT"))
		projectID := strings.TrimSpace(os.Getenv("APPWRITE_PROJECT_ID"))
		apiKey := strings.TrimSpace(os.Getenv("APPWRITE_DB_API_KEY"))
		if apiKey == "" {
			apiKey = strings.TrimSpace(os.Getenv("APPWRITE_AUTH_API_KEY"))
		}
		if endpoint == "" || projectID == "" || apiKey == "" {
			t.Skip("missing APPWRITE_ENDPOINT/APPWRITE_PROJECT_ID/APPWRITE_DB_API_KEY for appwrite backend matrix test")
		}

		client := appwrite.NewClient(endpoint, projectID, apiKey, nil)
		report, err := client.VerifyKanbanSchema(context.Background(), appwrite.SchemaConfig{
			DatabaseID:          strings.TrimSpace(os.Getenv("APPWRITE_DB_ID")),
			DatabaseName:        strings.TrimSpace(os.Getenv("APPWRITE_DB_NAME")),
			BoardsCollectionID:  strings.TrimSpace(os.Getenv("APPWRITE_BOARDS_COLLECTION_ID")),
			ColumnsCollectionID: strings.TrimSpace(os.Getenv("APPWRITE_COLUMNS_COLLECTION_ID")),
			TasksCollectionID:   strings.TrimSpace(os.Getenv("APPWRITE_TASKS_COLLECTION_ID")),
		})
		if err != nil {
			t.Fatalf("verify appwrite schema: %v", err)
		}
		if report.HasDrift() {
			t.Fatalf("appwrite schema drift detected for api backend matrix test")
		}

		return kanban.NewService(appwrite.NewKanbanRepository(client, appwrite.KanbanRepositoryConfig{
			DatabaseID: strings.TrimSpace(os.Getenv("APPWRITE_DB_ID")),
			BoardsID:   strings.TrimSpace(os.Getenv("APPWRITE_BOARDS_COLLECTION_ID")),
			ColumnsID:  strings.TrimSpace(os.Getenv("APPWRITE_COLUMNS_COLLECTION_ID")),
			TasksID:    strings.TrimSpace(os.Getenv("APPWRITE_TASKS_COLLECTION_ID")),
		}))
	default:
		t.Fatalf("unsupported API_TEST_BACKEND=%q", backend)
		return nil
	}
}

func createBoardWithTitleForMatrix(t *testing.T, mux *http.ServeMux, title string) string {
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
		t.Fatalf("decode create board response: %v", err)
	}
	if strings.TrimSpace(response.ID) == "" {
		t.Fatal("expected board id")
	}
	return response.ID
}
