package security

import (
	"sync"
	"time"
)

type loginAttempt struct {
	failures     int
	windowStart  time.Time
	blockedUntil time.Time
}

type LoginRateLimiter struct {
	mu          sync.Mutex
	maxFailures int
	window      time.Duration
	lockout     time.Duration
	maxEntries  int
	now         func() time.Time
	attempts    map[string]loginAttempt
}

func NewLoginRateLimiter(maxFailures int, window, lockout time.Duration) *LoginRateLimiter {
	return &LoginRateLimiter{
		maxFailures: maxFailures,
		window:      window,
		lockout:     lockout,
		maxEntries:  10000,
		now:         time.Now,
		attempts:    make(map[string]loginAttempt),
	}
}

func (l *LoginRateLimiter) Allow(key string) (bool, time.Duration) {
	if l == nil || key == "" {
		return true, 0
	}

	l.mu.Lock()
	defer l.mu.Unlock()

	entry, ok := l.attempts[key]
	if !ok {
		return true, 0
	}

	now := l.now()
	if now.Before(entry.blockedUntil) {
		return false, entry.blockedUntil.Sub(now)
	}

	return true, 0
}

func (l *LoginRateLimiter) RegisterFailure(key string) {
	if l == nil || key == "" {
		return
	}

	l.mu.Lock()
	defer l.mu.Unlock()

	now := l.now()
	entry := l.attempts[key]
	if _, exists := l.attempts[key]; !exists {
		l.evictIfNeeded(now)
	}

	if entry.windowStart.IsZero() || now.Sub(entry.windowStart) > l.window {
		entry.windowStart = now
		entry.failures = 0
	}

	entry.failures++
	if entry.failures >= l.maxFailures {
		entry.blockedUntil = now.Add(l.lockout)
		entry.failures = 0
		entry.windowStart = now
	}

	l.attempts[key] = entry
}

func (l *LoginRateLimiter) RegisterSuccess(key string) {
	if l == nil || key == "" {
		return
	}

	l.mu.Lock()
	defer l.mu.Unlock()

	delete(l.attempts, key)
}

func (l *LoginRateLimiter) evictIfNeeded(now time.Time) {
	if len(l.attempts) < l.maxEntries {
		return
	}

	for key, entry := range l.attempts {
		if now.After(entry.blockedUntil) && now.Sub(entry.windowStart) > l.window {
			delete(l.attempts, key)
			if len(l.attempts) < l.maxEntries {
				return
			}
		}
	}

	for key := range l.attempts {
		delete(l.attempts, key)
		break
	}
}
