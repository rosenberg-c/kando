package cli

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestNewHTTPAPIClientRejectsInvalidBaseURL(t *testing.T) {
	// @req CLI-001
	t.Parallel()

	_, err := NewHTTPAPIClient("://bad-url", nil)
	if err == nil {
		t.Fatal("expected error for invalid base URL")
	}
}

func TestHTTPAPIClientLoginUsesTypedResponseParsing(t *testing.T) {
	// @req CLI-002
	t.Parallel()

	expiresAt := time.Now().UTC().Add(10 * time.Minute).Format(time.RFC3339)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/auth/login" || r.Method != http.MethodPost {
			http.NotFound(w, r)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"accessToken":"access-1","refreshToken":"refresh-1","accessTokenExpiresAt":"` + expiresAt + `"}`))
	}))
	defer server.Close()

	client, err := NewHTTPAPIClient(server.URL, nil)
	if err != nil {
		t.Fatalf("NewHTTPAPIClient error: %v", err)
	}

	tokens, _, statusCode, err := client.Login(context.Background(), "user@example.com", "secret")
	if err != nil {
		t.Fatalf("Login error: %v", err)
	}
	if statusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", statusCode, http.StatusOK)
	}
	if tokens.AccessToken != "access-1" || tokens.RefreshToken != "refresh-1" {
		t.Fatalf("tokens = %+v", tokens)
	}
}
