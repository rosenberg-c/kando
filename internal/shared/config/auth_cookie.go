package config

import (
	"os"
	"strings"
)

const defaultAuthRefreshCookiePath = "/auth"

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
