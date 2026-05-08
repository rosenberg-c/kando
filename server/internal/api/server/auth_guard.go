package server

import (
	"context"
	"errors"

	"kando/server/internal/auth"
)

func requireVerifiedIdentity(ctx context.Context, deps Dependencies, authorization string) (auth.Identity, error) {
	if deps.Verifier == nil {
		return auth.Identity{}, authAPIError(authErrorCodeAuthDependenciesNotConfigured)
	}

	token, ok := bearerToken(authorization)
	if !ok {
		return auth.Identity{}, authAPIError(authErrorCodeMissingBearerToken)
	}

	identity, err := deps.Verifier.VerifyJWT(ctx, token)
	if err != nil {
		if errors.Is(err, auth.ErrVerifierUnavailable) {
			return auth.Identity{}, authAPIError(authErrorCodeVerifierUnavailable)
		}
		return auth.Identity{}, authAPIError(authErrorCodeUnauthorized)
	}

	return identity, nil
}
