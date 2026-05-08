package middleware

import (
	"errors"
	"log"
	"net/http"
	"strings"

	"kando/server/internal/auth"
)

// Auth validates Appwrite JWT from Authorization header.
func Auth(verifier auth.Verifier, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token, ok := bearerToken(r.Header.Get("Authorization"))
		if !ok {
			log.Printf("auth_event=bearer_rejected reason=missing_or_invalid_authorization_header path=%q remote_addr=%q", r.URL.Path, r.RemoteAddr)
			http.Error(w, "missing bearer token", http.StatusUnauthorized)
			return
		}

		identity, err := verifier.VerifyJWT(r.Context(), token)
		if err != nil {
			if errors.Is(err, auth.ErrUnauthorized) {
				log.Printf("auth_event=bearer_rejected reason=unauthorized path=%q remote_addr=%q", r.URL.Path, r.RemoteAddr)
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}
			if errors.Is(err, auth.ErrVerifierUnavailable) {
				log.Printf("auth_event=bearer_rejected reason=verifier_unavailable path=%q remote_addr=%q", r.URL.Path, r.RemoteAddr)
				http.Error(w, "auth verifier unavailable", http.StatusServiceUnavailable)
				return
			}

			log.Printf("auth_event=bearer_rejected reason=verify_failed path=%q remote_addr=%q", r.URL.Path, r.RemoteAddr)
			http.Error(w, "failed to verify token", http.StatusUnauthorized)
			return
		}

		next.ServeHTTP(w, r.WithContext(auth.WithIdentity(r.Context(), identity)))
	})
}

func bearerToken(value string) (string, bool) {
	if value == "" {
		return "", false
	}

	parts := strings.SplitN(value, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return "", false
	}

	token := strings.TrimSpace(parts[1])
	if token == "" {
		return "", false
	}

	return token, true
}
