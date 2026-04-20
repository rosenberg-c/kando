package cli

import (
	"context"
	"errors"
	"testing"
	"time"
)

type memoryStore struct {
	state TokenState
	has   bool
	err   error
}

func (s *memoryStore) Save(state TokenState) error {
	if s.err != nil {
		return s.err
	}

	s.state = state
	s.has = true
	return nil
}

func (s *memoryStore) Load() (TokenState, error) {
	if s.err != nil {
		return TokenState{}, s.err
	}
	if !s.has {
		return TokenState{}, ErrTokenStateNotFound
	}

	return s.state, nil
}

func (s *memoryStore) Clear() error {
	if s.err != nil {
		return s.err
	}
	s.state = TokenState{}
	s.has = false
	return nil
}

type stubAPI struct {
	statuses      []int
	body          []byte
	idx           int
	tokens        []string
	loginTokens   AuthTokens
	refreshTokens AuthTokens
	logoutStatus  int
}

func (s *stubAPI) Login(_ context.Context, _, _ string) (AuthTokens, []byte, int, error) {
	return s.loginTokens, nil, 200, nil
}

func (s *stubAPI) Refresh(_ context.Context, _ string) (AuthTokens, []byte, int, error) {
	return s.refreshTokens, nil, 200, nil
}

func (s *stubAPI) GetMe(_ context.Context, accessToken string) ([]byte, int, error) {
	s.tokens = append(s.tokens, accessToken)
	if s.idx >= len(s.statuses) {
		return nil, 0, errors.New("no status configured")
	}
	status := s.statuses[s.idx]
	s.idx++
	return s.body, status, nil
}

func (s *stubAPI) Logout(_ context.Context, _ string) ([]byte, int, error) {
	status := s.logoutStatus
	if status == 0 {
		status = 204
	}
	return nil, status, nil
}

func TestServiceLoginStoresTokens(t *testing.T) {
	// Requirement: CLI-009
	t.Parallel()

	api := &stubAPI{loginTokens: AuthTokens{AccessToken: "access-1", RefreshToken: "refresh-1", AccessTokenExpiresAt: time.Now().Add(10 * time.Minute)}}
	store := &memoryStore{}
	service := NewService(store, api)

	if err := service.Login(context.Background(), "email", "password"); err != nil {
		t.Fatalf("Login error: %v", err)
	}

	if !store.has {
		t.Fatal("expected store.Save to be called")
	}
	if store.state.RefreshToken != "refresh-1" || store.state.AccessToken != "access-1" {
		t.Fatalf("stored state = %+v", store.state)
	}
}

func TestServiceMeRefreshesOnUnauthorizedAndRetries(t *testing.T) {
	// Requirement: CLI-010
	t.Parallel()

	now := time.Now()
	store := &memoryStore{has: true, state: TokenState{RefreshToken: "refresh-1", AccessToken: "access-old", AccessTokenExpiresAt: now.Add(10 * time.Minute)}}
	api := &stubAPI{
		statuses:      []int{401, 200},
		body:          []byte(`{"userId":"u1"}`),
		refreshTokens: AuthTokens{AccessToken: "access-new", RefreshToken: "refresh-1", AccessTokenExpiresAt: now.Add(12 * time.Minute)},
	}

	service := NewService(store, api)

	body, err := service.Me(context.Background())
	if err != nil {
		t.Fatalf("Me error: %v", err)
	}
	if string(body) != `{"userId":"u1"}` {
		t.Fatalf("body = %s", string(body))
	}
	if len(api.tokens) != 2 {
		t.Fatalf("api calls = %d, want 2", len(api.tokens))
	}
	if api.tokens[0] != "access-old" || api.tokens[1] != "access-new" {
		t.Fatalf("tokens = %#v", api.tokens)
	}
}

func TestServiceLogoutClearsState(t *testing.T) {
	// Requirement: CLI-011
	t.Parallel()

	store := &memoryStore{has: true, state: TokenState{RefreshToken: "refresh-1"}}
	api := &stubAPI{logoutStatus: 204}
	service := NewService(store, api)

	if err := service.Logout(context.Background()); err != nil {
		t.Fatalf("Logout error: %v", err)
	}

	if store.has {
		t.Fatal("expected state to be cleared")
	}
}
