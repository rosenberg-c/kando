package config

import (
	"fmt"
	"net"
	"net/url"
	"os"
	"strings"
)

const defaultWebOrigin = "http://localhost:5173"

func AllowedCORSOrigins() []string {
	raw := strings.TrimSpace(os.Getenv("CORS_ALLOWED_ORIGINS"))
	if raw == "" {
		return []string{defaultWebOrigin}
	}

	parts := strings.Split(raw, ",")
	origins := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed == "" {
			continue
		}
		origins = append(origins, trimmed)
	}

	if len(origins) == 0 {
		return []string{defaultWebOrigin}
	}

	return origins
}

func ValidateAllowedCORSOrigins(origins []string) error {
	for _, origin := range origins {
		trimmed := strings.TrimSpace(origin)
		if trimmed == "" {
			continue
		}
		if trimmed == "*" {
			return fmt.Errorf("CORS_ALLOWED_ORIGINS must not contain '*' when credentialed auth cookies are enabled")
		}

		parsed, err := url.Parse(trimmed)
		if err != nil {
			return fmt.Errorf("invalid CORS origin %q: %w", trimmed, err)
		}
		if parsed.Scheme == "" || parsed.Host == "" {
			return fmt.Errorf("invalid CORS origin %q: scheme and host are required", trimmed)
		}
		if parsed.Scheme != "http" && parsed.Scheme != "https" {
			return fmt.Errorf("invalid CORS origin %q: scheme must be http or https", trimmed)
		}

		if parsed.Scheme == "http" && !isLocalhostHost(parsed.Hostname()) {
			return fmt.Errorf("invalid CORS origin %q: non-localhost origins must use https", trimmed)
		}
	}

	return nil
}

func isLocalhostHost(host string) bool {
	if strings.EqualFold(host, "localhost") {
		return true
	}

	ip := net.ParseIP(host)
	if ip == nil {
		return false
	}

	return ip.IsLoopback()
}
