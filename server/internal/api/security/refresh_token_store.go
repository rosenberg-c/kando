package security

import (
	"crypto/rand"
	"encoding/base64"
	"sync"
	"time"
)

type refreshTokenEntry struct {
	sessionSecret string
	expiresAt     time.Time
}

type RefreshTokenStore struct {
	mu         sync.Mutex
	now        func() time.Time
	ttl        time.Duration
	maxEntries int
	tokens     map[string]refreshTokenEntry
}

func (s *RefreshTokenStore) Resolve(token string) (string, bool) {
	if s == nil || token == "" {
		return "", false
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.now()
	entry, ok := s.tokens[token]
	if !ok || !now.Before(entry.expiresAt) {
		delete(s.tokens, token)
		return "", false
	}

	return entry.sessionSecret, true
}

func NewRefreshTokenStore(ttl time.Duration) *RefreshTokenStore {
	return &RefreshTokenStore{
		now:        time.Now,
		ttl:        ttl,
		maxEntries: 10000,
		tokens:     make(map[string]refreshTokenEntry),
	}
}

func (s *RefreshTokenStore) Issue(sessionSecret string) (string, bool) {
	if s == nil || sessionSecret == "" {
		return "", false
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.now()
	s.evictExpired(now)
	if len(s.tokens) >= s.maxEntries {
		return "", false
	}

	token, ok := generateRefreshToken()
	if !ok {
		return "", false
	}

	s.tokens[token] = refreshTokenEntry{sessionSecret: sessionSecret, expiresAt: now.Add(s.ttl)}
	return token, true
}

func (s *RefreshTokenStore) Rotate(token string) (string, string, bool) {
	if s == nil || token == "" {
		return "", "", false
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.now()
	entry, ok := s.tokens[token]
	if !ok || !now.Before(entry.expiresAt) {
		delete(s.tokens, token)
		return "", "", false
	}

	newToken, created := generateRefreshToken()
	if !created {
		return "", "", false
	}

	delete(s.tokens, token)
	s.tokens[newToken] = refreshTokenEntry{sessionSecret: entry.sessionSecret, expiresAt: now.Add(s.ttl)}
	return entry.sessionSecret, newToken, true
}

func (s *RefreshTokenStore) Revoke(token string) (string, bool) {
	if s == nil || token == "" {
		return "", false
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	entry, ok := s.tokens[token]
	if !ok {
		return "", false
	}

	now := s.now()
	if !now.Before(entry.expiresAt) {
		delete(s.tokens, token)
		return "", false
	}

	delete(s.tokens, token)
	return entry.sessionSecret, true
}

func (s *RefreshTokenStore) evictExpired(now time.Time) {
	for token, entry := range s.tokens {
		if !now.Before(entry.expiresAt) {
			delete(s.tokens, token)
		}
	}
}

func generateRefreshToken() (string, bool) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", false
	}

	return base64.RawURLEncoding.EncodeToString(raw), true
}
