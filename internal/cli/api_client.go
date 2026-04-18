package cli

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type APIClient interface {
	Login(ctx context.Context, email, password string) (AuthTokens, []byte, int, error)
	Refresh(ctx context.Context, refreshToken string) (AuthTokens, []byte, int, error)
	Logout(ctx context.Context, refreshToken string) ([]byte, int, error)
	GetMe(ctx context.Context, accessToken string) ([]byte, int, error)
}

type AuthTokens struct {
	AccessToken          string    `json:"accessToken"`
	RefreshToken         string    `json:"refreshToken"`
	AccessTokenExpiresAt time.Time `json:"accessTokenExpiresAt"`
}

type HTTPAPIClient struct {
	baseURL    string
	httpClient *http.Client
}

func NewHTTPAPIClient(baseURL string, httpClient *http.Client) *HTTPAPIClient {
	if httpClient == nil {
		httpClient = http.DefaultClient
	}

	return &HTTPAPIClient{
		baseURL:    strings.TrimSuffix(baseURL, "/"),
		httpClient: httpClient,
	}
}

func (c *HTTPAPIClient) Login(ctx context.Context, email, password string) (AuthTokens, []byte, int, error) {
	payload := map[string]string{"email": email, "password": password}
	return c.authRequest(ctx, http.MethodPost, "/auth/login", payload)
}

func (c *HTTPAPIClient) Refresh(ctx context.Context, refreshToken string) (AuthTokens, []byte, int, error) {
	payload := map[string]string{"refreshToken": refreshToken}
	return c.authRequest(ctx, http.MethodPost, "/auth/refresh", payload)
}

func (c *HTTPAPIClient) Logout(ctx context.Context, refreshToken string) ([]byte, int, error) {
	payload := map[string]string{"refreshToken": refreshToken}
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, 0, fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/auth/logout", bytes.NewReader(body))
	if err != nil {
		return nil, 0, fmt.Errorf("create /auth/logout request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	return c.do(req)
}

func (c *HTTPAPIClient) GetMe(ctx context.Context, accessToken string) ([]byte, int, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/me", nil)
	if err != nil {
		return nil, 0, fmt.Errorf("create /me request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+accessToken)

	body, statusCode, err := c.do(req)
	if err != nil {
		return nil, 0, err
	}

	return body, statusCode, nil
}

func (c *HTTPAPIClient) authRequest(ctx context.Context, method, path string, payload map[string]string) (AuthTokens, []byte, int, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return AuthTokens{}, nil, 0, fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, bytes.NewReader(body))
	if err != nil {
		return AuthTokens{}, nil, 0, fmt.Errorf("create %s request: %w", path, err)
	}
	req.Header.Set("Content-Type", "application/json")

	respBody, statusCode, err := c.do(req)
	if err != nil {
		return AuthTokens{}, nil, 0, err
	}

	var tokens AuthTokens
	if statusCode >= 200 && statusCode < 300 {
		if err := json.Unmarshal(respBody, &tokens); err != nil {
			return AuthTokens{}, nil, 0, fmt.Errorf("decode %s response: %w", path, err)
		}
	}

	return tokens, respBody, statusCode, nil
}

func (c *HTTPAPIClient) do(req *http.Request) ([]byte, int, error) {
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, 0, fmt.Errorf("request %s: %w", req.URL.Path, err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, resp.StatusCode, fmt.Errorf("read %s response: %w", req.URL.Path, err)
	}

	return body, resp.StatusCode, nil
}
