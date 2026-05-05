package server

import (
	"context"
	"net/http"
	"strconv"

	"github.com/danielgtaylor/huma/v2"

	"go_macos_todo/server/internal/api/contracts"
)

type loginInput struct {
	Body contracts.AuthLoginRequest
}

type authTokensOutput struct {
	Body contracts.AuthTokens
}

type refreshInput struct {
	Body contracts.AuthRefreshRequest
}

type logoutInput struct {
	Body contracts.AuthRefreshRequest
}

const authTag = "auth"

func registerAuth(api huma.API, deps Dependencies) {
	huma.Register(api, huma.Operation{
		OperationID: "login",
		Method:      http.MethodPost,
		Path:        "/auth/login",
		Summary:     "Authenticates a user and returns tokens",
		Tags:        []string{authTag},
	}, func(ctx context.Context, input *loginInput) (*authTokensOutput, error) {
		if deps.Issuer == nil || deps.LoginLimiter == nil {
			return nil, huma.Error500InternalServerError("auth dependencies are not configured")
		}

		if input.Body.Email == "" || input.Body.Password == "" {
			return nil, huma.Error400BadRequest("email and password are required")
		}

		loginKey := loginRateLimitKey(input.Body.Email, remoteAddrFromContext(ctx))
		if allowed, retryAfter := deps.LoginLimiter.Allow(loginKey); !allowed {
			headers := http.Header{}
			headers.Set("Retry-After", strconv.Itoa(int(retryAfter.Seconds())+1))
			return nil, huma.ErrorWithHeaders(huma.Error429TooManyRequests("too many login attempts"), headers)
		}

		sessionSecret, err := deps.Issuer.CreateEmailPasswordSession(ctx, input.Body.Email, input.Body.Password)
		if err != nil {
			deps.LoginLimiter.RegisterFailure(loginKey)
			return nil, huma.Error401Unauthorized("login failed")
		}

		jwt, expiresAt, err := deps.Issuer.CreateJWT(ctx, sessionSecret)
		if err != nil {
			deps.LoginLimiter.RegisterFailure(loginKey)
			return nil, huma.Error401Unauthorized("failed to create access token")
		}

		deps.LoginLimiter.RegisterSuccess(loginKey)

		return &authTokensOutput{Body: contracts.AuthTokens{
			AccessToken:          jwt,
			RefreshToken:         sessionSecret,
			AccessTokenExpiresAt: expiresAt,
		}}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "refreshAuth",
		Method:      http.MethodPost,
		Path:        "/auth/refresh",
		Summary:     "Refreshes an access token using refresh token",
		Tags:        []string{authTag},
	}, func(ctx context.Context, input *refreshInput) (*authTokensOutput, error) {
		if deps.Issuer == nil {
			return nil, huma.Error500InternalServerError("auth dependencies are not configured")
		}

		if input.Body.RefreshToken == "" {
			return nil, huma.Error400BadRequest("refreshToken is required")
		}

		jwt, expiresAt, err := deps.Issuer.CreateJWT(ctx, input.Body.RefreshToken)
		if err != nil {
			return nil, huma.Error401Unauthorized("refresh failed")
		}

		return &authTokensOutput{Body: contracts.AuthTokens{
			AccessToken:          jwt,
			RefreshToken:         input.Body.RefreshToken,
			AccessTokenExpiresAt: expiresAt,
		}}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID:   "logout",
		Method:        http.MethodPost,
		Path:          "/auth/logout",
		Summary:       "Revokes session and logs out user",
		DefaultStatus: http.StatusNoContent,
		Tags:          []string{authTag},
	}, func(ctx context.Context, input *logoutInput) (*struct{}, error) {
		if deps.Issuer == nil {
			return nil, huma.Error500InternalServerError("auth dependencies are not configured")
		}

		if input.Body.RefreshToken == "" {
			return nil, huma.Error400BadRequest("refreshToken is required")
		}

		if err := deps.Issuer.DeleteSession(ctx, input.Body.RefreshToken); err != nil {
			return nil, huma.Error401Unauthorized("logout failed")
		}

		return nil, nil
	})
}
