package appwrite

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"go_macos_todo/internal/auth"
)

func TestCreateEmailPasswordSession(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/account/sessions/email" {
			t.Fatalf("path = %q", r.URL.Path)
		}
		if got := r.Header.Get("X-Appwrite-Project"); got != "project-1" {
			t.Fatalf("project header = %q", got)
		}

		var payload map[string]string
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode payload: %v", err)
		}
		if payload["email"] != "a@b.com" {
			t.Fatalf("email = %q", payload["email"])
		}

		_ = json.NewEncoder(w).Encode(map[string]string{"secret": "session-1"})
	}))
	defer server.Close()

	client := NewClient(server.URL, "project-1", "api-key-1", server.Client())
	secret, err := client.CreateEmailPasswordSession(context.Background(), "a@b.com", "pass")
	if err != nil {
		t.Fatalf("CreateEmailPasswordSession error: %v", err)
	}
	if secret != "session-1" {
		t.Fatalf("secret = %q", secret)
	}
}

func TestCreateEmailPasswordSessionSendsAPIKeyHeader(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("X-Appwrite-Key"); got != "api-key-1" {
			t.Fatalf("api key header = %q, want %q", got, "api-key-1")
		}

		_ = json.NewEncoder(w).Encode(map[string]string{"secret": "session-1"})
	}))
	defer server.Close()

	client := NewClient(server.URL, "project-1", "api-key-1", server.Client())
	if _, err := client.CreateEmailPasswordSession(context.Background(), "a@b.com", "pass"); err != nil {
		t.Fatalf("CreateEmailPasswordSession error: %v", err)
	}
}

func TestCreateJWT(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/account/jwts" {
			t.Fatalf("path = %q", r.URL.Path)
		}
		if got := r.Header.Get("X-Appwrite-Session"); got != "session-1" {
			t.Fatalf("session header = %q", got)
		}
		_ = json.NewEncoder(w).Encode(map[string]string{"jwt": "jwt-1"})
	}))
	defer server.Close()

	client := NewClient(server.URL, "project-1", "", server.Client())
	jwt, expiresAt, err := client.CreateJWT(context.Background(), "session-1")
	if err != nil {
		t.Fatalf("CreateJWT error: %v", err)
	}
	if jwt != "jwt-1" {
		t.Fatalf("jwt = %q", jwt)
	}
	if expiresAt.IsZero() {
		t.Fatal("expiresAt is zero")
	}
}

func TestVerifyJWT(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/account" {
			t.Fatalf("path = %q", r.URL.Path)
		}
		if got := r.Header.Get("X-Appwrite-JWT"); got != "jwt-1" {
			t.Fatalf("jwt header = %q", got)
		}

		if got := r.Header.Get("X-Appwrite-Key"); got != "" {
			t.Fatalf("api key header = %q, want empty", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]string{"$id": "user-1", "email": "u@example.com"})
	}))
	defer server.Close()

	client := NewClient(server.URL, "project-1", "api-key-1", server.Client())
	identity, err := client.VerifyJWT(context.Background(), "jwt-1")
	if err != nil {
		t.Fatalf("VerifyJWT error: %v", err)
	}
	if identity.UserID != "user-1" || identity.Email != "u@example.com" {
		t.Fatalf("identity = %+v", identity)
	}
}

func TestVerifyJWTUnauthorized(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer server.Close()

	client := NewClient(server.URL, "project-1", "", server.Client())
	_, err := client.VerifyJWT(context.Background(), "jwt-1")
	if err == nil {
		t.Fatal("expected error")
	}
	if !errors.Is(err, auth.ErrUnauthorized) {
		t.Fatalf("error = %v, want %v", err, auth.ErrUnauthorized)
	}
}

func TestDeleteSession(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/account/sessions/current" {
			t.Fatalf("path = %q", r.URL.Path)
		}
		if r.Method != http.MethodDelete {
			t.Fatalf("method = %q", r.Method)
		}
		if got := r.Header.Get("X-Appwrite-Session"); got != "session-1" {
			t.Fatalf("session header = %q", got)
		}

		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	client := NewClient(server.URL, "project-1", "", server.Client())
	if err := client.DeleteSession(context.Background(), "session-1"); err != nil {
		t.Fatalf("DeleteSession error: %v", err)
	}
}

func TestSummarizeExternalBodyRedactsSensitiveTerms(t *testing.T) {
	t.Parallel()

	input := []byte(`{"message":"invalid token and jwt secret password"}`)
	result := summarizeExternalBody(input)

	for _, term := range []string{"token", "jwt", "secret", "password"} {
		if strings.Contains(strings.ToLower(result), term) {
			t.Fatalf("result contains sensitive term %q: %s", term, result)
		}
	}
}

func TestSummarizeExternalBodyTruncates(t *testing.T) {
	t.Parallel()

	input := []byte(strings.Repeat("a", maxErrorDetailLen+50))
	result := summarizeExternalBody(input)
	if !strings.HasSuffix(result, "...") {
		t.Fatalf("expected truncated suffix, got: %s", result)
	}
}
