package cli

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"time"
)

var (
	// ErrUnauthorized indicates backend-authenticated requests were rejected as unauthorized.
	ErrUnauthorized = errors.New("unauthorized")
	// ErrSessionMissing indicates required local session state is missing.
	ErrSessionMissing = errors.New("session missing")
)

type Service struct {
	store TokenStore
	api   APIClient
	now   func() time.Time
}

func NewService(store TokenStore, api APIClient) *Service {
	return &Service{
		store: store,
		api:   api,
		now:   time.Now,
	}
}

func (s *Service) Login(ctx context.Context, email, password string) error {
	tokens, body, statusCode, err := s.api.Login(ctx, email, password)
	if err != nil {
		return err
	}

	if statusCode != http.StatusOK {
		return fmt.Errorf("/auth/login failed with status %d: %s", statusCode, string(body))
	}

	if tokens.AccessToken == "" || tokens.RefreshToken == "" {
		return fmt.Errorf("/auth/login response missing tokens")
	}

	return s.store.Save(TokenState{
		RefreshToken:         tokens.RefreshToken,
		AccessToken:          tokens.AccessToken,
		AccessTokenExpiresAt: tokens.AccessTokenExpiresAt,
	})
}

func (s *Service) Me(ctx context.Context) ([]byte, error) {
	state, err := s.store.Load()
	if err != nil {
		return nil, fmt.Errorf("load auth state: %w", err)
	}

	state, err = s.ensureAccessToken(ctx, state)
	if err != nil {
		return nil, err
	}

	body, statusCode, err := s.api.GetMe(ctx, state.AccessToken)
	if err != nil {
		return nil, err
	}

	if statusCode == http.StatusUnauthorized {
		state, err = s.refreshAccessToken(ctx, state)
		if err != nil {
			return nil, err
		}

		body, statusCode, err = s.api.GetMe(ctx, state.AccessToken)
		if err != nil {
			return nil, err
		}
	}

	if statusCode == http.StatusUnauthorized {
		return nil, fmt.Errorf("%w: /me failed with status %d: %s", ErrUnauthorized, statusCode, string(body))
	}

	if statusCode != http.StatusOK {
		return nil, fmt.Errorf("/me failed with status %d: %s", statusCode, string(body))
	}

	return body, nil
}

func (s *Service) ensureAccessToken(ctx context.Context, state TokenState) (TokenState, error) {
	if state.AccessToken == "" || state.AccessTokenExpiresAt.IsZero() || state.AccessTokenExpiresAt.Before(s.now().Add(1*time.Minute)) {
		return s.refreshAccessToken(ctx, state)
	}

	return state, nil
}

func (s *Service) refreshAccessToken(ctx context.Context, state TokenState) (TokenState, error) {
	if state.RefreshToken == "" {
		return TokenState{}, fmt.Errorf("%w: refresh token missing, run login", ErrSessionMissing)
	}

	tokens, body, statusCode, err := s.api.Refresh(ctx, state.RefreshToken)
	if err != nil {
		return TokenState{}, err
	}
	if statusCode == http.StatusUnauthorized {
		return TokenState{}, fmt.Errorf("%w: /auth/refresh failed with status %d: %s", ErrUnauthorized, statusCode, string(body))
	}
	if statusCode != http.StatusOK {
		return TokenState{}, fmt.Errorf("/auth/refresh failed with status %d: %s", statusCode, string(body))
	}

	state.AccessToken = tokens.AccessToken
	state.AccessTokenExpiresAt = tokens.AccessTokenExpiresAt
	if tokens.RefreshToken != "" {
		state.RefreshToken = tokens.RefreshToken
	}

	if err := s.store.Save(state); err != nil {
		return TokenState{}, fmt.Errorf("save refreshed auth state: %w", err)
	}

	return state, nil
}

func (s *Service) Logout(ctx context.Context) error {
	state, err := s.store.Load()
	if err != nil {
		return fmt.Errorf("load auth state: %w", err)
	}

	body, statusCode, err := s.api.Logout(ctx, state.RefreshToken)
	if err != nil {
		return err
	}

	if statusCode != http.StatusNoContent && statusCode != http.StatusUnauthorized {
		return fmt.Errorf("/auth/logout failed with status %d: %s", statusCode, string(body))
	}

	if err := s.store.Clear(); err != nil {
		return fmt.Errorf("clear auth state: %w", err)
	}

	return nil
}

// ValidateSession verifies whether the locally stored session can access protected API endpoints.
// It clears local token state and returns (false, nil) when the session is missing or unauthorized.
func (s *Service) ValidateSession(ctx context.Context) (bool, error) {
	_, err := s.Me(ctx)
	if err == nil {
		return true, nil
	}

	if errors.Is(err, ErrUnauthorized) || errors.Is(err, ErrSessionMissing) || errors.Is(err, ErrTokenStateNotFound) {
		_ = s.store.Clear()
		return false, nil
	}

	return false, err
}
