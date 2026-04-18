package middleware

import (
	"errors"
	"net/http"
	"strings"

	"go_macos_todo/internal/auth"
)

// Auth validates Appwrite JWT from Authorization header.
func Auth(verifier auth.Verifier, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token, ok := bearerToken(r.Header.Get("Authorization"))
		if !ok {
			http.Error(w, "missing bearer token", http.StatusUnauthorized)
			return
		}

		identity, err := verifier.VerifyJWT(r.Context(), token)
		if err != nil {
			if errors.Is(err, auth.ErrUnauthorized) {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}

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
