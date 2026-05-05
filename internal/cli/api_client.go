package cli

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	generatedclient "go_macos_todo/generated/api/client"
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
	client *generatedclient.ClientWithResponses
}

func NewHTTPAPIClient(baseURL string, httpClient *http.Client) (*HTTPAPIClient, error) {
	trimmedBaseURL := strings.TrimSuffix(baseURL, "/")

	parsedURL, err := url.Parse(trimmedBaseURL)
	if err != nil || parsedURL.Scheme == "" || parsedURL.Host == "" {
		return nil, fmt.Errorf("invalid api base URL: %q", baseURL)
	}

	options := []generatedclient.ClientOption{}
	if httpClient != nil {
		options = append(options, generatedclient.WithHTTPClient(httpClient))
	}

	generated, err := generatedclient.NewClientWithResponses(parsedURL.String(), options...)
	if err != nil {
		return nil, fmt.Errorf("create generated api client: %w", err)
	}

	return &HTTPAPIClient{client: generated}, nil
}

func (c *HTTPAPIClient) Login(ctx context.Context, email, password string) (AuthTokens, []byte, int, error) {
	response, err := c.client.LoginWithResponse(ctx, generatedclient.LoginJSONRequestBody{
		Email:    email,
		Password: password,
	})
	if err != nil {
		return AuthTokens{}, nil, 0, fmt.Errorf("login request: %w", err)
	}

	tokens := AuthTokens{}
	if response.JSON200 != nil {
		tokens = mapAuthTokens(*response.JSON200)
	}

	return tokens, response.Body, response.StatusCode(), nil
}

func (c *HTTPAPIClient) Refresh(ctx context.Context, refreshToken string) (AuthTokens, []byte, int, error) {
	response, err := c.client.RefreshAuthWithResponse(ctx, generatedclient.RefreshAuthJSONRequestBody{RefreshToken: refreshToken})
	if err != nil {
		return AuthTokens{}, nil, 0, fmt.Errorf("refresh request: %w", err)
	}

	tokens := AuthTokens{}
	if response.JSON200 != nil {
		tokens = mapAuthTokens(*response.JSON200)
	}

	return tokens, response.Body, response.StatusCode(), nil
}

func (c *HTTPAPIClient) Logout(ctx context.Context, refreshToken string) ([]byte, int, error) {
	response, err := c.client.LogoutWithResponse(ctx, generatedclient.LogoutJSONRequestBody{RefreshToken: refreshToken})
	if err != nil {
		return nil, 0, fmt.Errorf("logout request: %w", err)
	}

	return response.Body, response.StatusCode(), nil
}

func (c *HTTPAPIClient) GetMe(ctx context.Context, accessToken string) ([]byte, int, error) {
	authorization := "Bearer " + accessToken
	response, err := c.client.GetMeWithResponse(ctx, &generatedclient.GetMeParams{
		Authorization: &authorization,
	})
	if err != nil {
		return nil, 0, fmt.Errorf("get /me request: %w", err)
	}

	return response.Body, response.StatusCode(), nil
}

func mapAuthTokens(tokens generatedclient.AuthTokens) AuthTokens {
	return AuthTokens{
		AccessToken:          tokens.AccessToken,
		RefreshToken:         tokens.RefreshToken,
		AccessTokenExpiresAt: tokens.AccessTokenExpiresAt,
	}
}
