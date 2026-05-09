package config

import (
	"os"
	"strings"
)

const defaultAuthRefreshCookiePath = "/auth"
const defaultAuthAccessCookiePath = "/"

func AuthRefreshCookiePath() string {
	return normalizeCookiePath(os.Getenv("AUTH_REFRESH_COOKIE_PATH"), defaultAuthRefreshCookiePath)
}

func AuthAccessCookiePath() string {
	return normalizeCookiePath(os.Getenv("AUTH_ACCESS_COOKIE_PATH"), defaultAuthAccessCookiePath)
}

func normalizeCookiePath(raw string, fallback string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return fallback
	}
	if !strings.HasPrefix(raw, "/") {
		return fallback
	}
	if len(raw) > 1 {
		raw = strings.TrimRight(raw, "/")
		if raw == "" {
			return fallback
		}
	}
	return raw
}
