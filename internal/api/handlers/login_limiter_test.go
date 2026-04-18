package handlers

import (
	"testing"
	"time"
)

func TestLoginRateLimiterBlocksAfterMaxFailures(t *testing.T) {
	limiter := NewLoginRateLimiter(2, time.Minute, time.Minute)
	now := time.Now()
	limiter.now = func() time.Time { return now }

	limiter.RegisterFailure("user|ip")
	allowed, _ := limiter.Allow("user|ip")
	if !allowed {
		t.Fatal("expected allowed after first failure")
	}

	limiter.RegisterFailure("user|ip")
	allowed, _ = limiter.Allow("user|ip")
	if allowed {
		t.Fatal("expected blocked after second failure")
	}
}

func TestLoginRateLimiterEvictsWhenMaxEntriesReached(t *testing.T) {
	limiter := NewLoginRateLimiter(5, time.Minute, time.Minute)
	limiter.maxEntries = 2
	now := time.Now()
	limiter.now = func() time.Time { return now }

	limiter.RegisterFailure("a|1")
	limiter.RegisterFailure("b|1")
	if len(limiter.attempts) != 2 {
		t.Fatalf("entries = %d, want %d", len(limiter.attempts), 2)
	}

	limiter.RegisterFailure("c|1")
	if len(limiter.attempts) != 2 {
		t.Fatalf("entries = %d, want %d", len(limiter.attempts), 2)
	}
}
