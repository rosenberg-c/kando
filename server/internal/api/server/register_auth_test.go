package server

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"kando/server/internal/api/security"
	"kando/server/internal/auth"
)

type cleanupIssuer struct {
	sessionSecret string
	jwt           string
	expiresAt     time.Time
	deleteErr     error
	deletedSecret string
}

func (s *cleanupIssuer) CreateEmailPasswordSession(context.Context, string, string) (string, error) {
	return s.sessionSecret, nil
}

func (s *cleanupIssuer) CreateJWT(context.Context, string) (string, time.Time, error) {
	return s.jwt, s.expiresAt, nil
}

func (s *cleanupIssuer) DeleteSession(_ context.Context, sessionSecret string) error {
	s.deletedSecret = sessionSecret
	return s.deleteErr
}

func TestAuthErrorMappingNativeLoginMissingCredentialsReturnsBadRequest(t *testing.T) {
	// @req AUTH-001
	t.Parallel()

	issuer := &stubIssuer{sessionSecret: "session-1", jwt: "jwt-1", expiresAt: time.Now().Add(10 * time.Minute)}
	limiter := security.NewLoginRateLimiter(5, time.Minute, time.Minute)

	mux, api := NewAPI()
	Register(api, Dependencies{Issuer: issuer, LoginLimiter: limiter})

	body, _ := json.Marshal(map[string]string{"email": "", "password": ""})
	request := httptest.NewRequest(http.MethodPost, "/auth/native/login", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusBadRequest, recorder.Body.String())
	}
}

func TestAuthErrorMappingMeMissingBearerTokenReturnsUnauthorized(t *testing.T) {
	// @req MW-AUTH-001
	t.Parallel()

	mux, api := NewAPI()
	Register(api, Dependencies{Verifier: &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "user@example.com"}}})

	request := httptest.NewRequest(http.MethodGet, "/me", nil)
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusUnauthorized, recorder.Body.String())
	}
}

func TestAuthErrorMappingMeVerifierUnavailableReturnsServiceUnavailable(t *testing.T) {
	// @req MW-AUTH-008
	t.Parallel()

	mux, api := NewAPI()
	Register(api, Dependencies{Verifier: &stubVerifier{err: auth.ErrVerifierUnavailable}})

	request := httptest.NewRequest(http.MethodGet, "/me", nil)
	request.Header.Set("Authorization", "Bearer test-token")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusServiceUnavailable, recorder.Body.String())
	}
}

func TestAuthErrorMappingMeCookieAuthReturnsOK(t *testing.T) {
	// @req AUTH-002
	t.Parallel()

	issuer := &stubIssuer{jwt: "jwt-1", expiresAt: time.Now().Add(10 * time.Minute)}
	refreshStore := security.NewRefreshTokenStore(time.Hour)
	_ = issueRefreshTokenForTests(t, refreshStore, "session-1")
	verifier := &stubVerifier{identity: auth.Identity{UserID: "user-1", Email: "user@example.com"}}

	mux, api := NewAPI()
	Register(api, Dependencies{
		Issuer:       issuer,
		Verifier:     verifier,
		RefreshStore: refreshStore,
		LoginLimiter: security.NewLoginRateLimiter(5, time.Minute, time.Minute),
	})

	request := httptest.NewRequest(http.MethodGet, "/me", nil)
	request.Header.Set("Cookie", "__Secure-access_token=jwt-1")
	request.Header.Set("Sec-Fetch-Site", "same-origin")
	request.Header.Set("Origin", "http://localhost:5173")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusOK, recorder.Body.String())
	}
}

func TestAuthErrorMappingLoginRateLimitedReturnsTooManyRequests(t *testing.T) {
	// @req SEC-LOGIN-001
	t.Parallel()

	issuer := &stubIssuer{sessionSecret: "session-1", jwt: "jwt-1", expiresAt: time.Now().Add(10 * time.Minute)}
	limiter := security.NewLoginRateLimiter(1, time.Minute, 2*time.Minute)
	limiter.RegisterFailure(loginRateLimitAccountKey("user@example.com"))
	limiter.RegisterFailure(loginRateLimitIPKey("127.0.0.1:12345"))

	mux, api := NewAPI()
	Register(api, Dependencies{Issuer: issuer, LoginLimiter: limiter})

	body, _ := json.Marshal(map[string]string{"email": "user@example.com", "password": "secret"})
	request := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
	request.RemoteAddr = "127.0.0.1:12345"
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Sec-Fetch-Site", "same-origin")
	request.Header.Set("Origin", "http://localhost:5173")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusTooManyRequests {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusTooManyRequests, recorder.Body.String())
	}
	if got := recorder.Header().Get("Retry-After"); got == "" {
		t.Fatal("expected Retry-After header")
	}
}

func TestNativeLoginRefreshIssueFailureTriggersSessionCleanup(t *testing.T) {
	// @req AUTH-007
	t.Parallel()

	issuer := &cleanupIssuer{sessionSecret: "session-1", jwt: "jwt-1", expiresAt: time.Now().Add(10 * time.Minute)}
	store := security.NewRefreshTokenStore(time.Hour)
	for i := 0; i < 10000; i++ {
		if _, ok := store.Issue(fmt.Sprintf("seed-%d", i)); !ok {
			t.Fatalf("unexpected issue failure while seeding at %d", i)
		}
	}

	mux, api := NewAPI()
	Register(api, Dependencies{Issuer: issuer, LoginLimiter: security.NewLoginRateLimiter(5, time.Minute, time.Minute), RefreshStore: store})

	body, _ := json.Marshal(map[string]string{"email": "user@example.com", "password": "secret"})
	request := httptest.NewRequest(http.MethodPost, "/auth/native/login", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusInternalServerError, recorder.Body.String())
	}
	if issuer.deletedSecret != "session-1" {
		t.Fatalf("deleted secret = %q, want %q", issuer.deletedSecret, "session-1")
	}
}

func TestNativeLoginRefreshIssueFailureStillReturnsOriginalErrorWhenCleanupFails(t *testing.T) {
	// @req AUTH-007
	t.Parallel()

	issuer := &cleanupIssuer{sessionSecret: "session-1", jwt: "jwt-1", expiresAt: time.Now().Add(10 * time.Minute), deleteErr: errors.New("delete failed")}
	store := security.NewRefreshTokenStore(time.Hour)
	for i := 0; i < 10000; i++ {
		if _, ok := store.Issue(fmt.Sprintf("seed-%d", i)); !ok {
			t.Fatalf("unexpected issue failure while seeding at %d", i)
		}
	}

	mux, api := NewAPI()
	Register(api, Dependencies{Issuer: issuer, LoginLimiter: security.NewLoginRateLimiter(5, time.Minute, time.Minute), RefreshStore: store})

	body, _ := json.Marshal(map[string]string{"email": "user@example.com", "password": "secret"})
	request := httptest.NewRequest(http.MethodPost, "/auth/native/login", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusInternalServerError, recorder.Body.String())
	}
	if issuer.deletedSecret != "session-1" {
		t.Fatalf("deleted secret = %q, want %q", issuer.deletedSecret, "session-1")
	}
}

func TestAuthErrorMappingNativeRefreshRateLimitedReturnsTooManyRequests(t *testing.T) {
	// @req SEC-AUTH-001, SEC-AUTH-002
	t.Parallel()

	issuer := &stubIssuer{sessionSecret: "session-1", jwt: "jwt-1", expiresAt: time.Now().Add(10 * time.Minute)}
	authLimiter := security.NewLoginRateLimiter(1, time.Minute, 2*time.Minute)
	authLimiter.RegisterFailure("auth|native_refresh|ip|127.0.0.1")

	mux, api := NewAPI()
	Register(api, Dependencies{Issuer: issuer, LoginLimiter: security.NewLoginRateLimiter(5, time.Minute, time.Minute), AuthLimiter: authLimiter})

	body, _ := json.Marshal(map[string]string{"refreshToken": "refresh-1"})
	request := httptest.NewRequest(http.MethodPost, "/auth/native/refresh", bytes.NewReader(body))
	request.RemoteAddr = "127.0.0.1:12345"
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusTooManyRequests {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusTooManyRequests, recorder.Body.String())
	}
	if got := recorder.Header().Get("Retry-After"); got == "" {
		t.Fatal("expected Retry-After header")
	}
}

func TestAuthErrorMappingLogoutRateLimitedReturnsTooManyRequests(t *testing.T) {
	// @req SEC-AUTH-001, SEC-AUTH-002
	t.Parallel()

	issuer := &stubIssuer{sessionSecret: "session-1", jwt: "jwt-1", expiresAt: time.Now().Add(10 * time.Minute)}
	authLimiter := security.NewLoginRateLimiter(1, time.Minute, 2*time.Minute)
	authLimiter.RegisterFailure("auth|logout|ip|127.0.0.1")

	mux, api := NewAPI()
	Register(api, Dependencies{Issuer: issuer, LoginLimiter: security.NewLoginRateLimiter(5, time.Minute, time.Minute), AuthLimiter: authLimiter})

	request := httptest.NewRequest(http.MethodPost, "/auth/logout", nil)
	request.RemoteAddr = "127.0.0.1:12345"
	request.Header.Set("Sec-Fetch-Site", "same-origin")
	request.Header.Set("Origin", "http://localhost:5173")
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusTooManyRequests {
		t.Fatalf("status = %d, want %d body=%s", recorder.Code, http.StatusTooManyRequests, recorder.Body.String())
	}
	if got := recorder.Header().Get("Retry-After"); got == "" {
		t.Fatal("expected Retry-After header")
	}
}
