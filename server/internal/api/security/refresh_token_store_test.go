package security

import (
	"testing"
	"time"
)

func TestRefreshTokenStoreRevokeRejectsExpiredToken(t *testing.T) {
	// @req SEC-AUTH-REFRESH-001
	store := NewRefreshTokenStore(time.Minute)
	now := time.Now()
	store.now = func() time.Time { return now }

	token, ok := store.Issue("session-1")
	if !ok {
		t.Fatal("expected refresh token issued")
	}

	store.now = func() time.Time { return now.Add(time.Minute) }

	if _, ok := store.Revoke(token); ok {
		t.Fatal("expected revoke to reject expired token")
	}

	if _, exists := store.tokens[token]; exists {
		t.Fatal("expected expired token removed from store")
	}
}

func TestRefreshTokenStoreResolveDoesNotRotateOrRevoke(t *testing.T) {
	// @req SEC-AUTH-REFRESH-001
	store := NewRefreshTokenStore(time.Minute)
	now := time.Now()
	store.now = func() time.Time { return now }

	token, ok := store.Issue("session-1")
	if !ok {
		t.Fatal("expected refresh token issued")
	}

	sessionSecret, ok := store.Resolve(token)
	if !ok {
		t.Fatal("expected resolve success")
	}
	if sessionSecret != "session-1" {
		t.Fatalf("resolved session secret = %q, want %q", sessionSecret, "session-1")
	}

	rotatedSessionSecret, _, ok := store.Rotate(token)
	if !ok {
		t.Fatal("expected rotate success after resolve")
	}
	if rotatedSessionSecret != "session-1" {
		t.Fatalf("rotated session secret = %q, want %q", rotatedSessionSecret, "session-1")
	}
}
