package handlers

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"net/netip"
	"strconv"
	"strings"
	"time"

	"go_macos_todo/internal/api/middleware"
)

type TokenIssuer interface {
	CreateEmailPasswordSession(ctx context.Context, email, password string) (string, error)
	CreateJWT(ctx context.Context, sessionSecret string) (string, time.Time, error)
	DeleteSession(ctx context.Context, sessionSecret string) error
}

type authRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type refreshRequest struct {
	RefreshToken string `json:"refreshToken"`
}

type logoutRequest struct {
	RefreshToken string `json:"refreshToken"`
}

type authResponse struct {
	AccessToken          string    `json:"accessToken"`
	RefreshToken         string    `json:"refreshToken"`
	AccessTokenExpiresAt time.Time `json:"accessTokenExpiresAt"`
}

func AuthLogin(issuer TokenIssuer, limiter *LoginRateLimiter) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var input authRequest
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			http.Error(w, "invalid json body", http.StatusBadRequest)
			return
		}

		if input.Email == "" || input.Password == "" {
			http.Error(w, "email and password are required", http.StatusBadRequest)
			return
		}

		loginKey := buildLoginRateLimitKey(input.Email, r)
		if allowed, retryAfter := limiter.Allow(loginKey); !allowed {
			w.Header().Set("Retry-After", strconv.Itoa(int(retryAfter.Seconds())+1))
			http.Error(w, "too many login attempts", http.StatusTooManyRequests)
			return
		}

		sessionSecret, err := issuer.CreateEmailPasswordSession(r.Context(), input.Email, input.Password)
		if err != nil {
			limiter.RegisterFailure(loginKey)
			log.Printf("request_id=%s route=/auth/login error=%v", middleware.GetRequestID(r.Context()), err)
			http.Error(w, "login failed", http.StatusUnauthorized)
			return
		}

		jwt, expiresAt, err := issuer.CreateJWT(r.Context(), sessionSecret)
		if err != nil {
			limiter.RegisterFailure(loginKey)
			log.Printf("request_id=%s route=/auth/login token_issue_error=%v", middleware.GetRequestID(r.Context()), err)
			http.Error(w, "failed to create access token", http.StatusUnauthorized)
			return
		}

		limiter.RegisterSuccess(loginKey)

		writeAuthResponse(w, authResponse{
			AccessToken:          jwt,
			RefreshToken:         sessionSecret,
			AccessTokenExpiresAt: expiresAt,
		})
	}
}

func AuthLogout(issuer TokenIssuer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var input logoutRequest
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			http.Error(w, "invalid json body", http.StatusBadRequest)
			return
		}

		if input.RefreshToken == "" {
			http.Error(w, "refreshToken is required", http.StatusBadRequest)
			return
		}

		if err := issuer.DeleteSession(r.Context(), input.RefreshToken); err != nil {
			log.Printf("request_id=%s route=/auth/logout error=%v", middleware.GetRequestID(r.Context()), err)
			http.Error(w, "logout failed", http.StatusUnauthorized)
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func buildLoginRateLimitKey(email string, r *http.Request) string {
	return strings.ToLower(strings.TrimSpace(email)) + "|" + clientIP(r)
}

func clientIP(r *http.Request) string {
	forwardedFor := strings.TrimSpace(r.Header.Get("X-Forwarded-For"))
	if forwardedFor != "" {
		parts := strings.Split(forwardedFor, ",")
		if len(parts) > 0 {
			return strings.TrimSpace(parts[0])
		}
	}

	host := r.RemoteAddr
	if addr, err := netip.ParseAddrPort(r.RemoteAddr); err == nil {
		host = addr.Addr().String()
	}

	return host
}

func AuthRefresh(issuer TokenIssuer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var input refreshRequest
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			http.Error(w, "invalid json body", http.StatusBadRequest)
			return
		}

		if input.RefreshToken == "" {
			http.Error(w, "refreshToken is required", http.StatusBadRequest)
			return
		}

		jwt, expiresAt, err := issuer.CreateJWT(r.Context(), input.RefreshToken)
		if err != nil {
			log.Printf("request_id=%s route=/auth/refresh error=%v", middleware.GetRequestID(r.Context()), err)
			http.Error(w, "refresh failed", http.StatusUnauthorized)
			return
		}

		writeAuthResponse(w, authResponse{
			AccessToken:          jwt,
			RefreshToken:         input.RefreshToken,
			AccessTokenExpiresAt: expiresAt,
		})
	}
}

func writeAuthResponse(w http.ResponseWriter, payload authResponse) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(payload)
}
