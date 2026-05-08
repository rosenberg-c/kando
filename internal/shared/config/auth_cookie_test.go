package config

import "testing"

func TestAuthRefreshCookiePathDefaultsToAuth(t *testing.T) {
	t.Setenv("AUTH_REFRESH_COOKIE_PATH", "")
	if got := AuthRefreshCookiePath(); got != "/auth" {
		t.Fatalf("AuthRefreshCookiePath()=%q, want /auth", got)
	}
}

func TestAuthRefreshCookiePathUsesConfiguredValue(t *testing.T) {
	t.Setenv("AUTH_REFRESH_COOKIE_PATH", "/api/auth")
	if got := AuthRefreshCookiePath(); got != "/api/auth" {
		t.Fatalf("AuthRefreshCookiePath()=%q, want /api/auth", got)
	}
}

func TestAuthRefreshCookiePathTrimsTrailingSlash(t *testing.T) {
	t.Setenv("AUTH_REFRESH_COOKIE_PATH", "/api/auth/")
	if got := AuthRefreshCookiePath(); got != "/api/auth" {
		t.Fatalf("AuthRefreshCookiePath()=%q, want /api/auth", got)
	}
}

func TestAuthRefreshCookiePathRejectsRelativeValue(t *testing.T) {
	t.Setenv("AUTH_REFRESH_COOKIE_PATH", "api/auth")
	if got := AuthRefreshCookiePath(); got != "/auth" {
		t.Fatalf("AuthRefreshCookiePath()=%q, want /auth", got)
	}
}
