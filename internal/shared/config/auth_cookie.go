package config

import (
	"os"
	"strings"
)

const defaultAuthRefreshCookiePath = "/auth"
const defaultAuthAccessCookiePath = "/"

func AuthRefreshCookiePath() string {
	raw := strings.TrimSpace(os.Getenv("AUTH_REFRESH_COOKIE_PATH"))
	if raw == "" {
		return defaultAuthRefreshCookiePath
	}
	if !strings.HasPrefix(raw, "/") {
		return defaultAuthRefreshCookiePath
	}
	if len(raw) > 1 {
		raw = strings.TrimRight(raw, "/")
		if raw == "" {
			return defaultAuthRefreshCookiePath
		}
	}
	return raw
}

func AuthAccessCookiePath() string {
	raw := strings.TrimSpace(os.Getenv("AUTH_ACCESS_COOKIE_PATH"))
	if raw == "" {
		return defaultAuthAccessCookiePath
	}
	if !strings.HasPrefix(raw, "/") {
		return defaultAuthAccessCookiePath
	}
	if len(raw) > 1 {
		raw = strings.TrimRight(raw, "/")
		if raw == "" {
			return defaultAuthAccessCookiePath
		}
	}
	return raw
}
