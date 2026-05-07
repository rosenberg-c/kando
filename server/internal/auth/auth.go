package auth

import (
	"context"
	"errors"
)

var ErrUnauthorized = errors.New("unauthorized")
var ErrVerifierUnavailable = errors.New("verifier unavailable")

// Identity is the authenticated Appwrite user mapped into the API context.
type Identity struct {
	UserID string
	Email  string
}

// Verifier validates JWTs and returns the authenticated identity.
type Verifier interface {
	VerifyJWT(ctx context.Context, token string) (Identity, error)
}

type identityContextKey struct{}

// WithIdentity stores an authenticated identity in context.
func WithIdentity(ctx context.Context, identity Identity) context.Context {
	return context.WithValue(ctx, identityContextKey{}, identity)
}

// GetIdentity returns identity from context.
func GetIdentity(ctx context.Context) (Identity, bool) {
	identity, ok := ctx.Value(identityContextKey{}).(Identity)
	return identity, ok
}
