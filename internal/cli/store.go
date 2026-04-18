package cli

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

var ErrTokenStateNotFound = errors.New("token state not found")

type TokenState struct {
	RefreshToken         string    `json:"refreshToken"`
	AccessToken          string    `json:"accessToken"`
	AccessTokenExpiresAt time.Time `json:"accessTokenExpiresAt"`
}

type TokenStore interface {
	Save(TokenState) error
	Load() (TokenState, error)
	Clear() error
}

type FileTokenStore struct {
	path string
}

func NewFileTokenStore(path string) *FileTokenStore {
	return &FileTokenStore{path: path}
}

func (s *FileTokenStore) Save(state TokenState) error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o700); err != nil {
		return fmt.Errorf("create token dir: %w", err)
	}

	payload, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal token state: %w", err)
	}

	if err := os.WriteFile(s.path, payload, 0o600); err != nil {
		return fmt.Errorf("write token state: %w", err)
	}

	return nil
}

func (s *FileTokenStore) Load() (TokenState, error) {
	payload, err := os.ReadFile(s.path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return TokenState{}, ErrTokenStateNotFound
		}

		return TokenState{}, fmt.Errorf("read token state: %w", err)
	}

	var state TokenState
	if err := json.Unmarshal(payload, &state); err != nil {
		return TokenState{}, fmt.Errorf("unmarshal token state: %w", err)
	}

	return state, nil
}

func (s *FileTokenStore) Clear() error {
	if err := os.Remove(s.path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remove token state: %w", err)
	}

	return nil
}
