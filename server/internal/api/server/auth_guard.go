package server

import (
	"context"
	"errors"
	"strings"

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

func requireVerifiedIdentityDual(
	ctx context.Context,
	deps Dependencies,
	authorization string,
	cookieHeader string,
	secFetchSite string,
	origin string,
) (auth.Identity, error) {
	if token, ok := bearerToken(authorization); ok {
		return verifyJWTIdentity(ctx, deps, token)
	}

	if strings.TrimSpace(cookieHeader) == "" {
		return auth.Identity{}, authAPIError(authErrorCodeMissingBearerToken)
	}

	if deps.Verifier == nil {
		return auth.Identity{}, authAPIError(authErrorCodeAuthDependenciesNotConfigured)
	}

	if !isTrustedCSRFFetch(secFetchSite) {
		return auth.Identity{}, authAPIError(authErrorCodeUnauthorized)
	}

	if !isTrustedOrigin(origin) {
		return auth.Identity{}, authAPIError(authErrorCodeUnauthorized)
	}

	accessCookie, err := readAccessCookie(cookieHeader)
	if err != nil {
		return auth.Identity{}, authAPIError(authErrorCodeUnauthorized)
	}
	return verifyJWTIdentity(ctx, deps, accessCookie.Value)
}

func verifyJWTIdentity(ctx context.Context, deps Dependencies, token string) (auth.Identity, error) {
	if deps.Verifier == nil {
		return auth.Identity{}, authAPIError(authErrorCodeAuthDependenciesNotConfigured)
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

func requestAuthHeadersFromContext(ctx context.Context) requestAuthHeaders {
	headers, _ := ctx.Value(requestAuthHeadersContextKey{}).(requestAuthHeaders)
	return headers
}
