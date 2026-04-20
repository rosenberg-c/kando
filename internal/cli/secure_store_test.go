package cli

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

type memorySecretStore struct {
	secret  string
	saveErr error
	loadErr error
	delErr  error
}

func (s *memorySecretStore) Save(secret string) error {
	if s.saveErr != nil {
		return s.saveErr
	}
	s.secret = secret
	return nil
}

func (s *memorySecretStore) Load() (string, error) {
	if s.loadErr != nil {
		return "", s.loadErr
	}
	return s.secret, nil
}

func (s *memorySecretStore) Delete() error {
	if s.delErr != nil {
		return s.delErr
	}
	s.secret = ""
	return nil
}

func TestSecureTokenStoreKeepsRefreshTokenOutOfStateFile(t *testing.T) {
	// Requirement: CLI-003
	t.Parallel()

	tempDir := t.TempDir()
	statePath := filepath.Join(tempDir, "auth.json")
	store := NewSecureTokenStoreWithSecretStore(statePath, &memorySecretStore{})

	state := TokenState{
		RefreshToken:         "refresh-1",
		AccessToken:          "access-1",
		AccessTokenExpiresAt: time.Now().UTC().Round(0),
	}

	if err := store.Save(state); err != nil {
		t.Fatalf("Save error: %v", err)
	}

	loaded, err := store.Load()
	if err != nil {
		t.Fatalf("Load error: %v", err)
	}

	if loaded.RefreshToken != "refresh-1" {
		t.Fatalf("refresh token = %q, want %q", loaded.RefreshToken, "refresh-1")
	}

	var raw map[string]any
	content, err := os.ReadFile(statePath)
	if err != nil {
		t.Fatalf("Read state file error: %v", err)
	}
	if err := json.Unmarshal(content, &raw); err != nil {
		t.Fatalf("Unmarshal state file error: %v", err)
	}
	if value, ok := raw["refreshToken"].(string); ok && value != "" {
		t.Fatalf("refreshToken persisted in state file: %q", value)
	}
}

func TestSecureTokenStoreLoadFailsWhenSecretStoreFails(t *testing.T) {
	// Requirement: CLI-004
	t.Parallel()

	tempDir := t.TempDir()
	statePath := filepath.Join(tempDir, "auth.json")
	secretStore := &memorySecretStore{}
	store := NewSecureTokenStoreWithSecretStore(statePath, secretStore)

	if err := store.Save(TokenState{RefreshToken: "refresh-1", AccessToken: "access-1", AccessTokenExpiresAt: time.Now()}); err != nil {
		t.Fatalf("Save error: %v", err)
	}

	secretStore.loadErr = errors.New("keychain unavailable")
	if _, err := store.Load(); err == nil {
		t.Fatal("expected load to fail")
	}
}

func TestSecureTokenStoreClearDeletesKeychainBeforeStateFile(t *testing.T) {
	// Requirement: CLI-005
	t.Parallel()

	tempDir := t.TempDir()
	statePath := filepath.Join(tempDir, "auth.json")
	secretStore := &memorySecretStore{}
	store := NewSecureTokenStoreWithSecretStore(statePath, secretStore)

	if err := store.Save(TokenState{RefreshToken: "refresh-1", AccessToken: "access-1", AccessTokenExpiresAt: time.Now()}); err != nil {
		t.Fatalf("Save error: %v", err)
	}

	secretStore.delErr = errors.New("keychain unavailable")
	if err := store.Clear(); err == nil {
		t.Fatal("expected clear to fail")
	}

	if _, err := os.Stat(statePath); err != nil {
		t.Fatalf("expected state file to remain when keychain delete fails: %v", err)
	}
}
