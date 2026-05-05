package cli

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestFileTokenStoreSaveAndLoad(t *testing.T) {
	// @req CLI-006
	t.Parallel()

	store := NewFileTokenStore(filepath.Join(t.TempDir(), "auth.json"))
	expected := TokenState{
		RefreshToken:         "refresh-1",
		AccessToken:          "access-1",
		AccessTokenExpiresAt: time.Now().UTC().Round(0),
	}

	if err := store.Save(expected); err != nil {
		t.Fatalf("Save error: %v", err)
	}

	actual, err := store.Load()
	if err != nil {
		t.Fatalf("Load error: %v", err)
	}

	if actual.RefreshToken != expected.RefreshToken || actual.AccessToken != expected.AccessToken || !actual.AccessTokenExpiresAt.Equal(expected.AccessTokenExpiresAt) {
		t.Fatalf("loaded state = %+v, want %+v", actual, expected)
	}
}

func TestFileTokenStoreLoadMissing(t *testing.T) {
	// @req CLI-007
	t.Parallel()

	store := NewFileTokenStore(filepath.Join(t.TempDir(), "missing.json"))
	_, err := store.Load()
	if !errors.Is(err, ErrTokenStateNotFound) {
		t.Fatalf("error = %v, want %v", err, ErrTokenStateNotFound)
	}
}

func TestFileTokenStoreClear(t *testing.T) {
	// @req CLI-008
	t.Parallel()

	path := filepath.Join(t.TempDir(), "auth.json")
	store := NewFileTokenStore(path)
	if err := store.Save(TokenState{AccessToken: "a", RefreshToken: "r", AccessTokenExpiresAt: time.Now()}); err != nil {
		t.Fatalf("Save error: %v", err)
	}

	if err := store.Clear(); err != nil {
		t.Fatalf("Clear error: %v", err)
	}

	if _, err := os.Stat(path); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("expected file removed, stat err=%v", err)
	}
}
