package server

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/danielgtaylor/huma/v2"

	sharedconfig "kando/internal/shared/config"
	"kando/server/internal/api/contracts"
	"kando/server/internal/api/security"
)

type loginInput struct {
	Body contracts.AuthLoginRequest
}

type browserLoginInput struct {
	Body         contracts.AuthLoginRequest
	SecFetchSite string `header:"Sec-Fetch-Site"`
	Origin       string `header:"Origin"`
}

type browserAuthTokensOutput struct {
	SetCookie    []string `header:"Set-Cookie"`
	CacheControl string `header:"Cache-Control"`
	Pragma       string `header:"Pragma"`
	Expires      string `header:"Expires"`
	Body         contracts.AuthBrowserTokens
}

type authTokensOutput struct {
	CacheControl string `header:"Cache-Control"`
	Pragma       string `header:"Pragma"`
	Expires      string `header:"Expires"`
	Body         contracts.AuthTokens
}

type browserRefreshInput struct {
	Cookie       string `header:"Cookie"`
	SecFetchSite string `header:"Sec-Fetch-Site"`
	Origin       string `header:"Origin"`
}

type browserLogoutInput struct {
	Cookie       string `header:"Cookie"`
	SecFetchSite string `header:"Sec-Fetch-Site"`
	Origin       string `header:"Origin"`
}

type logoutOutput struct {
	SetCookie    []string `header:"Set-Cookie"`
	CacheControl string `header:"Cache-Control"`
	Pragma       string `header:"Pragma"`
	Expires      string `header:"Expires"`
}

const authTag = "auth"
const refreshCookieName = "__Secure-refresh_token"
const accessCookieName = "__Secure-access_token"
const refreshCookieMaxAgeSeconds = 60 * 60 * 24 * 14
const accessCookieMaxAgeSeconds = 60 * 15
const noStoreCacheControl = "no-store"
const noCachePragma = "no-cache"
const expiresImmediately = "0"

type authErrorCode string

const (
	authErrorCodeLoginFailed                   authErrorCode = "login_failed"
	authErrorCodeRefreshFailed                 authErrorCode = "refresh_failed"
	authErrorCodeLogoutFailed                  authErrorCode = "logout_failed"
	authErrorCodeMissingBearerToken            authErrorCode = "missing_bearer_token"
	authErrorCodeVerifierUnavailable           authErrorCode = "verifier_unavailable"
	authErrorCodeUnauthorized                  authErrorCode = "unauthorized"
	authErrorCodeMissingEmailPassword          authErrorCode = "missing_email_password"
	authErrorCodeTooManyLoginAttempts          authErrorCode = "too_many_login_attempts"
	authErrorCodeTooManyAuthAttempts           authErrorCode = "too_many_auth_attempts"
	authErrorCodeRefreshIssueFailed            authErrorCode = "refresh_issue_failed"
	authErrorCodeAuthDependenciesNotConfigured authErrorCode = "auth_dependencies_not_configured"
)

func authAPIError(code authErrorCode) error {
	switch code {
	case authErrorCodeAuthDependenciesNotConfigured:
		return huma.Error500InternalServerError("auth dependencies are not configured")
	case authErrorCodeMissingEmailPassword:
		return huma.Error400BadRequest("email and password are required")
	case authErrorCodeTooManyLoginAttempts:
		return huma.Error429TooManyRequests("too many login attempts")
	case authErrorCodeTooManyAuthAttempts:
		return huma.Error429TooManyRequests("too many auth attempts")
	case authErrorCodeRefreshIssueFailed:
		return huma.Error500InternalServerError("failed to issue refresh token")
	case authErrorCodeVerifierUnavailable:
		return huma.Error503ServiceUnavailable("auth verifier unavailable")
	case authErrorCodeMissingBearerToken:
		return huma.Error401Unauthorized("missing bearer token")
	case authErrorCodeLoginFailed:
		return huma.Error401Unauthorized("login failed")
	case authErrorCodeRefreshFailed:
		return huma.Error401Unauthorized("refresh failed")
	case authErrorCodeLogoutFailed:
		return huma.Error401Unauthorized("logout failed")
	default:
		return huma.Error401Unauthorized("unauthorized")
	}
}

func registerAuth(api huma.API, deps Dependencies) {
	if deps.RefreshStore == nil {
		deps.RefreshStore = security.NewRefreshTokenStore(14 * 24 * time.Hour)
	}

	huma.Register(api, huma.Operation{
		OperationID: "nativeLogin",
		Method:      http.MethodPost,
		Path:        "/auth/native/login",
		Summary:     "Authenticates a native client and returns tokens",
		Tags:        []string{authTag},
	}, func(ctx context.Context, input *loginInput) (*authTokensOutput, error) {
		tokens, err := createAuthTokens(ctx, deps, input)
		if err != nil {
			return nil, err
		}

		return &authTokensOutput{Body: tokens, CacheControl: noStoreCacheControl, Pragma: noCachePragma, Expires: expiresImmediately}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "login",
		Method:      http.MethodPost,
		Path:        "/auth/login",
		Summary:     "Authenticates a user, returns tokens, and sets browser auth cookies",
		Tags:        []string{authTag},
	}, func(ctx context.Context, input *browserLoginInput) (*browserAuthTokensOutput, error) {
		if !isTrustedCSRFFetch(input.SecFetchSite) || !isTrustedOrigin(input.Origin) {
			log.Printf("auth_event=login_rejected reason=csrf_or_origin_check_failed remote_addr=%q", remoteAddrFromContext(ctx))
			return nil, huma.Error401Unauthorized("login failed")
		}

		nativeInput := &loginInput{Body: input.Body}

		tokens, err := createAuthTokens(ctx, deps, nativeInput)
		if err != nil {
			return nil, err
		}

		refreshCookie := newRefreshCookie(tokens.RefreshToken)
		accessCookie := newAccessCookie(tokens.AccessToken)

		return &browserAuthTokensOutput{Body: contracts.AuthBrowserTokens{
			AccessToken:          tokens.AccessToken,
			AccessTokenExpiresAt: tokens.AccessTokenExpiresAt,
		}, SetCookie: []string{refreshCookie.String(), accessCookie.String()}, CacheControl: noStoreCacheControl, Pragma: noCachePragma, Expires: expiresImmediately}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "nativeRefreshAuth",
		Method:      http.MethodPost,
		Path:        "/auth/native/refresh",
		Summary:     "Refreshes an access token for native client",
		Tags:        []string{authTag},
	}, func(ctx context.Context, input *struct{ Body contracts.AuthRefreshRequest }) (*authTokensOutput, error) {
		if deps.Issuer == nil {
			return nil, authAPIError(authErrorCodeAuthDependenciesNotConfigured)
		}

		if err := enforceAuthRateLimit(ctx, deps, "native_refresh", strings.TrimSpace(input.Body.RefreshToken)); err != nil {
			return nil, err
		}

		refreshToken := strings.TrimSpace(input.Body.RefreshToken)
		if refreshToken == "" {
			log.Printf("auth_event=native_refresh_rejected reason=missing_refresh_token")
			registerAuthRateLimitFailure(ctx, deps, "native_refresh", "")
			return nil, authAPIError(authErrorCodeRefreshFailed)
		}
		sessionSecret, ok := deps.RefreshStore.Resolve(refreshToken)
		if !ok {
			log.Printf("auth_event=native_refresh_rejected reason=refresh_token_invalid_or_expired")
			registerAuthRateLimitFailure(ctx, deps, "native_refresh", refreshToken)
			return nil, authAPIError(authErrorCodeRefreshFailed)
		}

		jwt, expiresAt, err := deps.Issuer.CreateJWT(ctx, sessionSecret)
		if err != nil {
			log.Printf("auth_event=native_refresh_rejected reason=issuer_create_jwt_failed")
			registerAuthRateLimitFailure(ctx, deps, "native_refresh", refreshToken)
			return nil, authAPIError(authErrorCodeRefreshFailed)
		}

		_, rotatedToken, ok := deps.RefreshStore.Rotate(refreshToken)
		if !ok {
			log.Printf("auth_event=native_refresh_rejected reason=refresh_token_rotation_failed")
			registerAuthRateLimitFailure(ctx, deps, "native_refresh", refreshToken)
			return nil, authAPIError(authErrorCodeRefreshFailed)
		}

		return &authTokensOutput{Body: contracts.AuthTokens{
			AccessToken:          jwt,
			RefreshToken:         rotatedToken,
			AccessTokenExpiresAt: expiresAt,
		}, CacheControl: noStoreCacheControl, Pragma: noCachePragma, Expires: expiresImmediately}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "refreshAuth",
		Method:      http.MethodPost,
		Path:        "/auth/refresh",
		Summary:     "Refreshes an access token using browser auth cookies",
		Tags:        []string{authTag},
	}, func(ctx context.Context, input *browserRefreshInput) (*browserAuthTokensOutput, error) {
		if deps.Issuer == nil {
			return nil, authAPIError(authErrorCodeAuthDependenciesNotConfigured)
		}

		if err := enforceAuthRateLimit(ctx, deps, "refresh", ""); err != nil {
			return nil, err
		}

		refreshCookie, err := readRefreshCookie(input.Cookie)
		if err != nil {
			log.Printf("auth_event=refresh_rejected reason=missing_refresh_cookie remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "refresh", "")
			return nil, authAPIError(authErrorCodeRefreshFailed)
		}
		if !isTrustedCSRFFetch(input.SecFetchSite) {
			log.Printf("auth_event=refresh_rejected reason=csrf_fetch_site_check_failed remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "refresh", "")
			return nil, authAPIError(authErrorCodeRefreshFailed)
		}
		if !isTrustedOrigin(input.Origin) {
			log.Printf("auth_event=refresh_rejected reason=origin_check_failed remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "refresh", "")
			return nil, authAPIError(authErrorCodeRefreshFailed)
		}
		if err := enforceAuthRateLimit(ctx, deps, "refresh", refreshCookie.Value); err != nil {
			return nil, err
		}
		sessionSecret, ok := deps.RefreshStore.Resolve(refreshCookie.Value)
		if !ok {
			log.Printf("auth_event=refresh_rejected reason=refresh_token_invalid_or_expired remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "refresh", refreshCookie.Value)
			return nil, authAPIError(authErrorCodeRefreshFailed)
		}

		jwt, expiresAt, err := deps.Issuer.CreateJWT(ctx, sessionSecret)
		if err != nil {
			log.Printf("auth_event=refresh_rejected reason=issuer_create_jwt_failed remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "refresh", refreshCookie.Value)
			return nil, authAPIError(authErrorCodeRefreshFailed)
		}

		_, rotatedToken, ok := deps.RefreshStore.Rotate(refreshCookie.Value)
		if !ok {
			log.Printf("auth_event=refresh_rejected reason=refresh_token_rotation_failed remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "refresh", refreshCookie.Value)
			return nil, authAPIError(authErrorCodeRefreshFailed)
		}

		return &browserAuthTokensOutput{Body: contracts.AuthBrowserTokens{
			AccessToken:          jwt,
			AccessTokenExpiresAt: expiresAt,
		}, SetCookie: []string{newRefreshCookie(rotatedToken).String(), newAccessCookie(jwt).String()}, CacheControl: noStoreCacheControl, Pragma: noCachePragma, Expires: expiresImmediately}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID:   "nativeLogout",
		Method:        http.MethodPost,
		Path:          "/auth/native/logout",
		Summary:       "Revokes session for native client",
		DefaultStatus: http.StatusNoContent,
		Tags:          []string{authTag},
	}, func(ctx context.Context, input *struct{ Body contracts.AuthRefreshRequest }) (*struct {
		CacheControl string `header:"Cache-Control"`
		Pragma       string `header:"Pragma"`
		Expires      string `header:"Expires"`
	}, error) {
		if deps.Issuer == nil {
			return nil, authAPIError(authErrorCodeAuthDependenciesNotConfigured)
		}

		if err := enforceAuthRateLimit(ctx, deps, "native_logout", strings.TrimSpace(input.Body.RefreshToken)); err != nil {
			return nil, err
		}

		refreshToken := strings.TrimSpace(input.Body.RefreshToken)
		if refreshToken == "" {
			log.Printf("auth_event=native_logout_rejected reason=missing_refresh_token")
			registerAuthRateLimitFailure(ctx, deps, "native_logout", "")
			return nil, authAPIError(authErrorCodeLogoutFailed)
		}

		sessionSecret, ok := deps.RefreshStore.Revoke(refreshToken)
		if !ok {
			log.Printf("auth_event=native_logout_rejected reason=refresh_token_invalid_or_expired")
			registerAuthRateLimitFailure(ctx, deps, "native_logout", refreshToken)
			return nil, authAPIError(authErrorCodeLogoutFailed)
		}
		if strings.TrimSpace(sessionSecret) == "" {
			log.Printf("auth_event=native_logout_rejected reason=session_secret_missing")
			registerAuthRateLimitFailure(ctx, deps, "native_logout", refreshToken)
			return nil, authAPIError(authErrorCodeLogoutFailed)
		}

		if err := deps.Issuer.DeleteSession(ctx, sessionSecret); err != nil {
			log.Printf("auth_event=native_logout_rejected reason=issuer_delete_session_failed")
			registerAuthRateLimitFailure(ctx, deps, "native_logout", refreshToken)
			return nil, authAPIError(authErrorCodeLogoutFailed)
		}

		return &struct {
			CacheControl string `header:"Cache-Control"`
			Pragma       string `header:"Pragma"`
			Expires      string `header:"Expires"`
		}{CacheControl: noStoreCacheControl, Pragma: noCachePragma, Expires: expiresImmediately}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID:   "logout",
		Method:        http.MethodPost,
		Path:          "/auth/logout",
		Summary:       "Revokes session and clears browser auth cookies",
		DefaultStatus: http.StatusNoContent,
		Tags:          []string{authTag},
	}, func(ctx context.Context, input *browserLogoutInput) (*logoutOutput, error) {
		if deps.Issuer == nil {
			return nil, authAPIError(authErrorCodeAuthDependenciesNotConfigured)
		}

		if err := enforceAuthRateLimit(ctx, deps, "logout", ""); err != nil {
			return nil, err
		}

		refreshCookie, err := readRefreshCookie(input.Cookie)
		if err != nil {
			log.Printf("auth_event=logout_rejected reason=missing_refresh_cookie remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "logout", "")
			return nil, authAPIError(authErrorCodeLogoutFailed)
		}
		if strings.TrimSpace(refreshCookie.Value) == "" {
			log.Printf("auth_event=logout_rejected reason=empty_refresh_cookie remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "logout", "")
			return nil, authAPIError(authErrorCodeLogoutFailed)
		}
		if !isTrustedCSRFFetch(input.SecFetchSite) {
			log.Printf("auth_event=logout_rejected reason=csrf_fetch_site_check_failed remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "logout", "")
			return nil, authAPIError(authErrorCodeLogoutFailed)
		}
		if !isTrustedOrigin(input.Origin) {
			log.Printf("auth_event=logout_rejected reason=origin_check_failed remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "logout", "")
			return nil, authAPIError(authErrorCodeLogoutFailed)
		}
		if err := enforceAuthRateLimit(ctx, deps, "logout", refreshCookie.Value); err != nil {
			return nil, err
		}

		sessionSecret, ok := deps.RefreshStore.Revoke(refreshCookie.Value)
		if !ok {
			log.Printf("auth_event=logout_rejected reason=refresh_token_invalid_or_expired remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "logout", refreshCookie.Value)
			return nil, authAPIError(authErrorCodeLogoutFailed)
		}
		if strings.TrimSpace(sessionSecret) == "" {
			log.Printf("auth_event=logout_rejected reason=session_secret_missing remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "logout", refreshCookie.Value)
			return nil, authAPIError(authErrorCodeLogoutFailed)
		}

		if err := deps.Issuer.DeleteSession(ctx, sessionSecret); err != nil {
			log.Printf("auth_event=logout_rejected reason=issuer_delete_session_failed remote_addr=%q", remoteAddrFromContext(ctx))
			registerAuthRateLimitFailure(ctx, deps, "logout", refreshCookie.Value)
			return nil, authAPIError(authErrorCodeLogoutFailed)
		}

		return &logoutOutput{SetCookie: []string{clearRefreshCookie().String(), clearAccessCookie().String()}, CacheControl: noStoreCacheControl, Pragma: noCachePragma, Expires: expiresImmediately}, nil
	})
}

func createAuthTokens(ctx context.Context, deps Dependencies, input *loginInput) (contracts.AuthTokens, error) {
	if deps.Issuer == nil || deps.LoginLimiter == nil || deps.RefreshStore == nil {
		return contracts.AuthTokens{}, authAPIError(authErrorCodeAuthDependenciesNotConfigured)
	}

	if input.Body.Email == "" || input.Body.Password == "" {
		return contracts.AuthTokens{}, authAPIError(authErrorCodeMissingEmailPassword)
	}

	accountKey := loginRateLimitAccountKey(input.Body.Email)
	ipKey := loginRateLimitIPKey(remoteAddrFromContext(ctx))
	if allowed, retryAfter := deps.LoginLimiter.Allow(accountKey); !allowed {
		log.Printf("auth_event=login_rate_limited scope=account remote_addr=%q", remoteAddrFromContext(ctx))
		headers := http.Header{}
		headers.Set("Retry-After", strconv.Itoa(int(retryAfter.Seconds())+1))
		return contracts.AuthTokens{}, huma.ErrorWithHeaders(authAPIError(authErrorCodeTooManyLoginAttempts), headers)
	}
	if allowed, retryAfter := deps.LoginLimiter.Allow(ipKey); !allowed {
		log.Printf("auth_event=login_rate_limited scope=ip remote_addr=%q", remoteAddrFromContext(ctx))
		headers := http.Header{}
		headers.Set("Retry-After", strconv.Itoa(int(retryAfter.Seconds())+1))
		return contracts.AuthTokens{}, huma.ErrorWithHeaders(authAPIError(authErrorCodeTooManyLoginAttempts), headers)
	}

	sessionSecret, err := deps.Issuer.CreateEmailPasswordSession(ctx, input.Body.Email, input.Body.Password)
	if err != nil {
		log.Printf("auth_event=login_rejected reason=issuer_create_session_failed remote_addr=%q", remoteAddrFromContext(ctx))
		deps.LoginLimiter.RegisterFailure(accountKey)
		deps.LoginLimiter.RegisterFailure(ipKey)
		return contracts.AuthTokens{}, authAPIError(authErrorCodeLoginFailed)
	}
	refreshToken, ok := deps.RefreshStore.Issue(sessionSecret)
	if !ok {
		log.Printf("auth_event=login_rejected reason=refresh_token_issue_failed remote_addr=%q", remoteAddrFromContext(ctx))
		if err := deps.Issuer.DeleteSession(ctx, sessionSecret); err != nil {
			log.Printf("auth_event=login_cleanup_failed reason=issuer_delete_session_failed remote_addr=%q", remoteAddrFromContext(ctx))
		}
		return contracts.AuthTokens{}, authAPIError(authErrorCodeRefreshIssueFailed)
	}

	jwt, expiresAt, err := deps.Issuer.CreateJWT(ctx, sessionSecret)
	if err != nil {
		log.Printf("auth_event=login_rejected reason=issuer_create_jwt_failed remote_addr=%q", remoteAddrFromContext(ctx))
		deps.LoginLimiter.RegisterFailure(accountKey)
		deps.LoginLimiter.RegisterFailure(ipKey)
		_, _ = deps.RefreshStore.Revoke(refreshToken)
		return contracts.AuthTokens{}, authAPIError(authErrorCodeLoginFailed)
	}

	deps.LoginLimiter.RegisterSuccess(accountKey)
	deps.LoginLimiter.RegisterSuccess(ipKey)

	return contracts.AuthTokens{AccessToken: jwt, RefreshToken: refreshToken, AccessTokenExpiresAt: expiresAt}, nil
}

func newRefreshCookie(refreshToken string) *http.Cookie {
	cookiePath := sharedconfig.AuthRefreshCookiePath()
	return &http.Cookie{
		Name:     refreshCookieName,
		Value:    refreshToken,
		Path:     cookiePath,
		MaxAge:   refreshCookieMaxAgeSeconds,
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
	}
}

func clearRefreshCookie() *http.Cookie {
	cookiePath := sharedconfig.AuthRefreshCookiePath()
	return &http.Cookie{
		Name:     refreshCookieName,
		Value:    "",
		Path:     cookiePath,
		MaxAge:   -1,
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
	}
}

func newAccessCookie(accessToken string) *http.Cookie {
	cookiePath := sharedconfig.AuthAccessCookiePath()
	return &http.Cookie{
		Name:     accessCookieName,
		Value:    accessToken,
		Path:     cookiePath,
		MaxAge:   accessCookieMaxAgeSeconds,
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
	}
}

func clearAccessCookie() *http.Cookie {
	cookiePath := sharedconfig.AuthAccessCookiePath()
	return &http.Cookie{
		Name:     accessCookieName,
		Value:    "",
		Path:     cookiePath,
		MaxAge:   -1,
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
	}
}

func readRefreshCookie(cookieHeader string) (*http.Cookie, error) {
	req := &http.Request{Header: make(http.Header)}
	req.Header.Set("Cookie", cookieHeader)
	cookie, err := req.Cookie(refreshCookieName)
	if err != nil {
		return nil, err
	}
	if strings.TrimSpace(cookie.Value) == "" {
		return nil, errors.New("missing refresh cookie value")
	}

	return cookie, nil
}

func readAccessCookie(cookieHeader string) (*http.Cookie, error) {
	req := &http.Request{Header: make(http.Header)}
	req.Header.Set("Cookie", cookieHeader)
	cookie, err := req.Cookie(accessCookieName)
	if err != nil {
		return nil, err
	}
	if strings.TrimSpace(cookie.Value) == "" {
		return nil, errors.New("missing access cookie value")
	}

	return cookie, nil
}

func isTrustedCSRFFetch(secFetchSiteHeader string) bool {
	site := strings.ToLower(strings.TrimSpace(secFetchSiteHeader))
	if site == "" {
		return false
	}

	return site == "same-origin" || site == "same-site"
}

func isTrustedOrigin(originHeader string) bool {
	origin := strings.TrimSpace(originHeader)
	if origin == "" {
		return false
	}

	parsed, err := url.Parse(origin)
	if err != nil {
		return false
	}

	if parsed.Scheme != "https" && parsed.Scheme != "http" {
		return false
	}

	normalizedOrigin := strings.ToLower(parsed.Scheme) + "://" + strings.ToLower(parsed.Host)

	for _, allowedOrigin := range sharedconfig.AllowedCORSOrigins() {
		allowed := strings.TrimSpace(allowedOrigin)
		if allowed == "" {
			continue
		}

		allowedParsed, parseErr := url.Parse(allowed)
		if parseErr != nil {
			continue
		}

		allowedNormalized := strings.ToLower(allowedParsed.Scheme) + "://" + strings.ToLower(allowedParsed.Host)
		if normalizedOrigin == allowedNormalized {
			return true
		}
	}

	return false
}

func enforceAuthRateLimit(ctx context.Context, deps Dependencies, action, refreshToken string) error {
	if deps.AuthLimiter == nil {
		return nil
	}

	ipKey := "auth|" + action + "|ip|" + clientIP(remoteAddrFromContext(ctx))
	if allowed, retryAfter := deps.AuthLimiter.Allow(ipKey); !allowed {
		log.Printf("auth_event=%s_rejected reason=rate_limited scope=ip remote_addr=%q", action, remoteAddrFromContext(ctx))
		headers := http.Header{}
		headers.Set("Retry-After", strconv.Itoa(int(retryAfter.Seconds())+1))
		return huma.ErrorWithHeaders(authAPIError(authErrorCodeTooManyAuthAttempts), headers)
	}

	if refreshToken == "" {
		return nil
	}

	tokenKey := "auth|" + action + "|token|" + refreshTokenHash(refreshToken)
	if allowed, retryAfter := deps.AuthLimiter.Allow(tokenKey); !allowed {
		log.Printf("auth_event=%s_rejected reason=rate_limited scope=token remote_addr=%q", action, remoteAddrFromContext(ctx))
		headers := http.Header{}
		headers.Set("Retry-After", strconv.Itoa(int(retryAfter.Seconds())+1))
		return huma.ErrorWithHeaders(authAPIError(authErrorCodeTooManyAuthAttempts), headers)
	}
	return nil
}

func registerAuthRateLimitFailure(ctx context.Context, deps Dependencies, action, refreshToken string) {
	if deps.AuthLimiter == nil {
		return
	}

	ipKey := "auth|" + action + "|ip|" + clientIP(remoteAddrFromContext(ctx))
	deps.AuthLimiter.RegisterFailure(ipKey)

	if refreshToken == "" {
		return
	}

	tokenKey := "auth|" + action + "|token|" + refreshTokenHash(refreshToken)
	deps.AuthLimiter.RegisterFailure(tokenKey)
}

func refreshTokenHash(refreshToken string) string {
	sum := sha256.Sum256([]byte(refreshToken))
	return hex.EncodeToString(sum[:8])
}
