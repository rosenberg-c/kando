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

func TestAuthAccessCookiePathDefaultsToRoot(t *testing.T) {
	t.Setenv("AUTH_ACCESS_COOKIE_PATH", "")
	if got := AuthAccessCookiePath(); got != "/" {
		t.Fatalf("AuthAccessCookiePath()=%q, want /", got)
	}
}

func TestAuthAccessCookiePathUsesConfiguredValue(t *testing.T) {
	t.Setenv("AUTH_ACCESS_COOKIE_PATH", "/api")
	if got := AuthAccessCookiePath(); got != "/api" {
		t.Fatalf("AuthAccessCookiePath()=%q, want /api", got)
	}
}
