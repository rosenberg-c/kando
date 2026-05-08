package cli

import "fmt"

type SecretStore interface {
	Save(secret string) error
	Load() (string, error)
	Delete() error
}

type SecureTokenStore struct {
	stateStore  *FileTokenStore
	secretStore SecretStore
}

func NewSecureTokenStore(path string) TokenStore {
	secretStore, err := newSecretStore("kando.refresh_token")
	if err != nil {
		return NewFileTokenStore(path)
	}

	return &SecureTokenStore{stateStore: NewFileTokenStore(path), secretStore: secretStore}
}

func NewSecureTokenStoreWithSecretStore(path string, secretStore SecretStore) TokenStore {
	return &SecureTokenStore{stateStore: NewFileTokenStore(path), secretStore: secretStore}
}

func (s *SecureTokenStore) Save(state TokenState) error {
	if err := s.secretStore.Save(state.RefreshToken); err != nil {
		return fmt.Errorf("save refresh token: %w", err)
	}

	state.RefreshToken = ""
	if err := s.stateStore.Save(state); err != nil {
		return err
	}

	return nil
}

func (s *SecureTokenStore) Load() (TokenState, error) {
	state, err := s.stateStore.Load()
	if err != nil {
		return TokenState{}, err
	}

	refreshToken, err := s.secretStore.Load()
	if err != nil {
		return TokenState{}, fmt.Errorf("load refresh token: %w", err)
	}
	state.RefreshToken = refreshToken

	return state, nil
}

func (s *SecureTokenStore) Clear() error {
	if err := s.secretStore.Delete(); err != nil {
		return fmt.Errorf("delete refresh token: %w", err)
	}

	if err := s.stateStore.Clear(); err != nil {
		return err
	}

	return nil
}
