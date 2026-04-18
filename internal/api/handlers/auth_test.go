package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

type stubTokenIssuer struct {
	sessionSecret string
	jwt           string
	expiresAt     time.Time
	err           error
	deleteErr     error
}

func (s *stubTokenIssuer) CreateEmailPasswordSession(_ context.Context, _, _ string) (string, error) {
	if s.err != nil {
		return "", s.err
	}
	return s.sessionSecret, nil
}

func (s *stubTokenIssuer) CreateJWT(_ context.Context, _ string) (string, time.Time, error) {
	if s.err != nil {
		return "", time.Time{}, s.err
	}
	return s.jwt, s.expiresAt, nil
}

func (s *stubTokenIssuer) DeleteSession(_ context.Context, _ string) error {
	if s.deleteErr != nil {
		return s.deleteErr
	}

	return nil
}

func TestAuthLoginReturnsTokens(t *testing.T) {
	issuer := &stubTokenIssuer{sessionSecret: "refresh-1", jwt: "access-1", expiresAt: time.Now().Add(10 * time.Minute)}
	handler := AuthLogin(issuer, nil)

	body := []byte(`{"email":"user@example.com","password":"secret"}`)
	req := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	var response authResponse
	if err := json.NewDecoder(rec.Body).Decode(&response); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if response.AccessToken != "access-1" || response.RefreshToken != "refresh-1" {
		t.Fatalf("response = %+v", response)
	}
}

func TestAuthLoginRateLimitBlocksAfterFailures(t *testing.T) {
	now := time.Now()
	limiter := NewLoginRateLimiter(1, time.Minute, 2*time.Minute)
	limiter.now = func() time.Time { return now }

	issuer := &stubTokenIssuer{err: errors.New("invalid")}
	handler := AuthLogin(issuer, limiter)

	body := []byte(`{"email":"user@example.com","password":"secret"}`)
	req1 := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
	rec1 := httptest.NewRecorder()
	handler.ServeHTTP(rec1, req1)
	if rec1.Code != http.StatusUnauthorized {
		t.Fatalf("first status = %d, want %d", rec1.Code, http.StatusUnauthorized)
	}

	req2 := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
	rec2 := httptest.NewRecorder()
	handler.ServeHTTP(rec2, req2)
	if rec2.Code != http.StatusTooManyRequests {
		t.Fatalf("second status = %d, want %d", rec2.Code, http.StatusTooManyRequests)
	}
}

func TestAuthRefreshRejectsInvalidToken(t *testing.T) {
	issuer := &stubTokenIssuer{err: errors.New("invalid")}
	handler := AuthRefresh(issuer)

	body := []byte(`{"refreshToken":"bad"}`)
	req := httptest.NewRequest(http.MethodPost, "/auth/refresh", bytes.NewReader(body))
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestAuthLogoutReturnsNoContent(t *testing.T) {
	issuer := &stubTokenIssuer{}
	handler := AuthLogout(issuer)

	body := []byte(`{"refreshToken":"refresh-1"}`)
	req := httptest.NewRequest(http.MethodPost, "/auth/logout", bytes.NewReader(body))
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusNoContent)
	}
}
