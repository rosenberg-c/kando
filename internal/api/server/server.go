package server

import (
	"context"
	"net/http"
	"net/netip"
	"strings"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humago"

	"go_macos_todo/internal/api/security"
	"go_macos_todo/internal/auth"
)

type TokenIssuer interface {
	CreateEmailPasswordSession(ctx context.Context, email, password string) (string, error)
	CreateJWT(ctx context.Context, sessionSecret string) (string, time.Time, error)
	DeleteSession(ctx context.Context, sessionSecret string) error
}

type Dependencies struct {
	Issuer       TokenIssuer
	Verifier     auth.Verifier
	LoginLimiter *security.LoginRateLimiter
}

// remoteAddrContextKey stores the request remote address for auth rate-limit keying.
type remoteAddrContextKey struct{}

func NewAPI() (*http.ServeMux, huma.API) {
	mux := http.NewServeMux()
	config := huma.DefaultConfig("Go MacOS Todo API", "0.1.0")
	config.OpenAPIPath = ""
	config.DocsPath = ""
	config.SchemasPath = ""
	if config.Components == nil {
		config.Components = &huma.Components{}
	}
	config.Components.SecuritySchemes = map[string]*huma.SecurityScheme{
		"bearerAuth": {
			Type:         "http",
			Scheme:       "bearer",
			BearerFormat: "JWT",
		},
	}

	api := humago.New(mux, config)
	api.UseMiddleware(func(ctx huma.Context, next func(huma.Context)) {
		next(huma.WithValue(ctx, remoteAddrContextKey{}, ctx.RemoteAddr()))
	})

	return mux, api
}

func Register(api huma.API, deps Dependencies) {
	registerPublic(api, deps)
	registerAuth(api, deps)
}

func loginRateLimitKey(email, remoteAddr string) string {
	return strings.ToLower(strings.TrimSpace(email)) + "|" + clientIP(remoteAddr)
}

func clientIP(remoteAddr string) string {
	if addr, err := netip.ParseAddrPort(remoteAddr); err == nil {
		return addr.Addr().String()
	}

	return strings.TrimSpace(remoteAddr)
}

func remoteAddrFromContext(ctx context.Context) string {
	value, _ := ctx.Value(remoteAddrContextKey{}).(string)
	return value
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
