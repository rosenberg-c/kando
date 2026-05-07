package appwrite

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"go_macos_todo/server/internal/auth"
)

const jwtTTL = 14 * time.Minute
const maxErrorDetailLen = 240

type Client struct {
	endpoint   string
	projectID  string
	apiKey     string
	httpClient *http.Client
	now        func() time.Time
}

func NewClient(endpoint, projectID, apiKey string, httpClient *http.Client) *Client {
	trimmedEndpoint := strings.TrimSuffix(endpoint, "/")
	if httpClient == nil {
		httpClient = http.DefaultClient
	}

	return &Client{
		endpoint:   trimmedEndpoint,
		projectID:  projectID,
		apiKey:     apiKey,
		httpClient: httpClient,
		now:        time.Now,
	}
}

type sessionResponse struct {
	Secret string `json:"secret"`
}

type jwtResponse struct {
	JWT string `json:"jwt"`
}

type accountResponse struct {
	ID    string `json:"$id"`
	Email string `json:"email"`
}

type transactionResponse struct {
	ID string `json:"$id"`
}

func (c *Client) CreateEmailPasswordSession(ctx context.Context, email, password string) (string, error) {
	payload := map[string]string{
		"email":    email,
		"password": password,
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal login payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint+"/account/sessions/email", bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("create login request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	c.setProjectHeader(req)
	c.setAPIKey(req)

	var response sessionResponse
	if err := c.do(req, &response); err != nil {
		return "", err
	}

	if response.Secret == "" {
		return "", fmt.Errorf("appwrite session secret missing (check APPWRITE_AUTH_API_KEY and sessions.write scope)")
	}

	return response.Secret, nil
}

func (c *Client) CreateJWT(ctx context.Context, sessionSecret string) (string, time.Time, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint+"/account/jwts", nil)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("create jwt request: %w", err)
	}

	c.setProjectHeader(req)
	req.Header.Set("X-Appwrite-Session", sessionSecret)

	var response jwtResponse
	if err := c.do(req, &response); err != nil {
		return "", time.Time{}, err
	}

	if response.JWT == "" {
		return "", time.Time{}, fmt.Errorf("appwrite jwt missing")
	}

	return response.JWT, c.now().Add(jwtTTL), nil
}

func (c *Client) DeleteSession(ctx context.Context, sessionSecret string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, c.endpoint+"/account/sessions/current", nil)
	if err != nil {
		return fmt.Errorf("create delete session request: %w", err)
	}

	c.setProjectHeader(req)
	req.Header.Set("X-Appwrite-Session", sessionSecret)

	if err := c.do(req, nil); err != nil {
		return err
	}

	return nil
}

func (c *Client) VerifyJWT(ctx context.Context, token string) (auth.Identity, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.endpoint+"/account", nil)
	if err != nil {
		return auth.Identity{}, fmt.Errorf("create account request: %w", err)
	}

	c.setProjectHeader(req)
	req.Header.Set("X-Appwrite-JWT", token)

	var response accountResponse
	if err := c.do(req, &response); err != nil {
		if errors.Is(err, auth.ErrUnauthorized) {
			return auth.Identity{}, err
		}

		return auth.Identity{}, fmt.Errorf("%w: %v", auth.ErrVerifierUnavailable, err)
	}

	if response.ID == "" {
		return auth.Identity{}, fmt.Errorf("appwrite account id missing")
	}

	return auth.Identity{UserID: response.ID, Email: response.Email}, nil
}

func (c *Client) createTransaction(ctx context.Context, ttlSeconds int) (string, error) {
	var response transactionResponse
	payload := map[string]any{"ttl": ttlSeconds}
	if err := c.doServerJSON(ctx, http.MethodPost, "/tablesdb/transactions", payload, &response); err != nil {
		return "", err
	}
	if strings.TrimSpace(response.ID) == "" {
		return "", fmt.Errorf("appwrite transaction id missing")
	}
	return response.ID, nil
}

func (c *Client) commitTransaction(ctx context.Context, transactionID string) error {
	payload := map[string]bool{"commit": true, "rollback": false}
	return c.doServerJSON(ctx, http.MethodPatch, "/tablesdb/transactions/"+transactionID, payload, nil)
}

func (c *Client) rollbackTransaction(ctx context.Context, transactionID string) error {
	payload := map[string]bool{"commit": false, "rollback": true}
	return c.doServerJSON(ctx, http.MethodPatch, "/tablesdb/transactions/"+transactionID, payload, nil)
}

func (c *Client) do(req *http.Request, out any) error {
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("appwrite request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized {
		body, _ := io.ReadAll(resp.Body)
		detail := summarizeExternalBody(body)
		if detail == "" {
			return auth.ErrUnauthorized
		}

		return fmt.Errorf("%w: appwrite unauthorized: %s", auth.ErrUnauthorized, detail)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		detail := summarizeExternalBody(body)
		if detail == "" {
			return fmt.Errorf("appwrite request failed: status=%d", resp.StatusCode)
		}

		return fmt.Errorf("appwrite request failed: status=%d detail=%s", resp.StatusCode, detail)
	}

	if out == nil {
		_, _ = io.Copy(io.Discard, resp.Body)
		return nil
	}

	if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
		return fmt.Errorf("decode appwrite response: %w", err)
	}

	return nil
}

func (c *Client) setProjectHeader(req *http.Request) {
	req.Header.Set("X-Appwrite-Project", c.projectID)
}

func (c *Client) setAPIKey(req *http.Request) {
	if c.apiKey != "" {
		req.Header.Set("X-Appwrite-Key", c.apiKey)
	}
}

func summarizeExternalBody(raw []byte) string {
	trimmed := strings.TrimSpace(string(raw))
	if trimmed == "" {
		return ""
	}

	redacted := redactSensitiveText(trimmed)
	if len(redacted) > maxErrorDetailLen {
		return redacted[:maxErrorDetailLen] + "..."
	}

	return redacted
}

func redactSensitiveText(input string) string {
	replacer := strings.NewReplacer(
		"token", "[redacted]",
		"Token", "[redacted]",
		"secret", "[redacted]",
		"Secret", "[redacted]",
		"password", "[redacted]",
		"Password", "[redacted]",
		"jwt", "[redacted]",
		"JWT", "[redacted]",
	)

	return replacer.Replace(input)
}
