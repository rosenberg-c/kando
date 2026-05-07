package config

import "testing"

func TestValidateAllowedCORSOriginsRejectsWildcard(t *testing.T) {
	t.Parallel()

	err := ValidateAllowedCORSOrigins([]string{"*"})
	if err == nil {
		t.Fatal("expected wildcard origin to be rejected")
	}
}

func TestValidateAllowedCORSOriginsRejectsNonLocalhostHTTP(t *testing.T) {
	t.Parallel()

	err := ValidateAllowedCORSOrigins([]string{"http://example.com"})
	if err == nil {
		t.Fatal("expected non-localhost http origin to be rejected")
	}
}

func TestValidateAllowedCORSOriginsAllowsLocalhostHTTP(t *testing.T) {
	t.Parallel()

	err := ValidateAllowedCORSOrigins([]string{"http://localhost:5173", "http://127.0.0.1:5173"})
	if err != nil {
		t.Fatalf("expected localhost origins to be allowed, got error: %v", err)
	}
}

func TestValidateAllowedCORSOriginsAllowsHTTPS(t *testing.T) {
	t.Parallel()

	err := ValidateAllowedCORSOrigins([]string{"https://app.example.com"})
	if err != nil {
		t.Fatalf("expected https origin to be allowed, got error: %v", err)
	}
}
