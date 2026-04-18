package server

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"go_macos_todo/internal/api/security"
	"go_macos_todo/internal/auth"
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
