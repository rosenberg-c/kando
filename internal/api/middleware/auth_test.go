package middleware

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"go_macos_todo/internal/auth"
)

type stubVerifier struct {
	identity auth.Identity
	err      error
	lastJWT  string
}

func (s *stubVerifier) VerifyJWT(_ context.Context, token string) (auth.Identity, error) {
	s.lastJWT = token
	if s.err != nil {
		return auth.Identity{}, s.err
	}

	return s.identity, nil
}

func TestAuthRejectsMissingBearerToken(t *testing.T) {
	// Requirement: MW-AUTH-001
	verifier := &stubVerifier{}
	handler := Auth(verifier, http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("next handler should not be called")
	}))

	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestAuthPassesIdentityToContext(t *testing.T) {
	// Requirement: MW-AUTH-002
	verifier := &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "user@example.com"}}

	handler := Auth(verifier, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		identity, ok := auth.GetIdentity(r.Context())
		if !ok {
			t.Fatal("identity missing from context")
		}
		if identity.UserID != "user-1" {
			t.Fatalf("user id = %q, want %q", identity.UserID, "user-1")
		}
		w.WriteHeader(http.StatusNoContent)
	}))

	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	req.Header.Set("Authorization", "Bearer jwt-123")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if verifier.lastJWT != "jwt-123" {
		t.Fatalf("verifier jwt = %q, want %q", verifier.lastJWT, "jwt-123")
	}

	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusNoContent)
	}
}

func TestAuthRejectsUnauthorizedVerifierError(t *testing.T) {
	// Requirement: MW-AUTH-003
	verifier := &stubVerifier{err: auth.ErrUnauthorized}
	handler := Auth(verifier, http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("next handler should not be called")
	}))

	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	req.Header.Set("Authorization", "Bearer invalid")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestAuthRejectsVerifierErrors(t *testing.T) {
	// Requirement: MW-AUTH-004
	verifier := &stubVerifier{err: errors.New("network")}
	handler := Auth(verifier, http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("next handler should not be called")
	}))

	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	req.Header.Set("Authorization", "Bearer maybe")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}
