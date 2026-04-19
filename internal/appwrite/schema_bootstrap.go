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
)

const (
	defaultBootstrapTimeout = 60 * time.Second
	defaultPollInterval     = 1 * time.Second
)

// SchemaConfig configures Appwrite resources for kanban persistence.
type SchemaConfig struct {
	DatabaseID          string
	DatabaseName        string
	BoardsCollectionID  string
	ColumnsCollectionID string
	TodosCollectionID   string
}

type appwriteAPIError struct {
	Status int
	Detail string
}

func (e *appwriteAPIError) Error() string {
	if e.Detail == "" {
		return fmt.Sprintf("appwrite api error: status=%d", e.Status)
	}

	return fmt.Sprintf("appwrite api error: status=%d detail=%s", e.Status, e.Detail)
}

type collectionSpec struct {
	ID      string
	Name    string
	Attrs   []attributeSpec
	Indexes []indexSpec
}

type attributeSpec struct {
	Kind    string
	Key     string
	Payload map[string]any
}

type indexSpec struct {
	Key        string
	Type       string
	Attributes []string
	Orders     []string
}

type statusResponse struct {
	Status string `json:"status"`
}

// BootstrapKanbanSchema ensures the kanban database schema exists.
// It is safe to run repeatedly.
func (c *Client) BootstrapKanbanSchema(ctx context.Context, cfg SchemaConfig) error {
	if strings.TrimSpace(c.apiKey) == "" {
		return fmt.Errorf("bootstrap schema requires server api key")
	}

	cfg = normalizeSchemaConfig(cfg)

	if err := c.ensureDatabase(ctx, cfg.DatabaseID, cfg.DatabaseName); err != nil {
		return fmt.Errorf("ensure database %q: %w", cfg.DatabaseID, err)
	}

	collections := []collectionSpec{
		{
			ID:   cfg.BoardsCollectionID,
			Name: "Boards",
			Attrs: []attributeSpec{
				varcharAttribute("ownerUserId", 64, true),
				varcharAttribute("title", 120, true),
				integerAttribute("boardVersion", true),
				datetimeAttribute("createdAt", true),
				datetimeAttribute("updatedAt", true),
			},
			Indexes: []indexSpec{
				{Key: "boards_owner_updated", Type: "key", Attributes: []string{"ownerUserId", "updatedAt"}, Orders: []string{"ASC", "DESC"}},
			},
		},
		{
			ID:   cfg.ColumnsCollectionID,
			Name: "Columns",
			Attrs: []attributeSpec{
				varcharAttribute("boardId", 64, true),
				varcharAttribute("ownerUserId", 64, true),
				varcharAttribute("title", 120, true),
				integerAttribute("position", true),
				datetimeAttribute("createdAt", true),
				datetimeAttribute("updatedAt", true),
			},
			Indexes: []indexSpec{
				{Key: "columns_board_position", Type: "key", Attributes: []string{"boardId", "position"}, Orders: []string{"ASC", "ASC"}},
			},
		},
		{
			ID:   cfg.TodosCollectionID,
			Name: "Todos",
			Attrs: []attributeSpec{
				varcharAttribute("boardId", 64, true),
				varcharAttribute("columnId", 64, true),
				varcharAttribute("ownerUserId", 64, true),
				varcharAttribute("title", 200, true),
				varcharAttribute("description", 4000, true),
				integerAttribute("position", true),
				datetimeAttribute("createdAt", true),
				datetimeAttribute("updatedAt", true),
			},
			Indexes: []indexSpec{
				{Key: "todos_board_column_position", Type: "key", Attributes: []string{"boardId", "columnId", "position"}, Orders: []string{"ASC", "ASC", "ASC"}},
			},
		},
	}

	for _, spec := range collections {
		if err := c.ensureCollection(ctx, cfg.DatabaseID, spec); err != nil {
			return fmt.Errorf("ensure collection %q: %w", spec.ID, err)
		}
	}

	return nil
}

func normalizeSchemaConfig(cfg SchemaConfig) SchemaConfig {
	if strings.TrimSpace(cfg.DatabaseID) == "" {
		cfg.DatabaseID = "todo"
	}
	if strings.TrimSpace(cfg.DatabaseName) == "" {
		cfg.DatabaseName = "Todo"
	}
	if strings.TrimSpace(cfg.BoardsCollectionID) == "" {
		cfg.BoardsCollectionID = "boards"
	}
	if strings.TrimSpace(cfg.ColumnsCollectionID) == "" {
		cfg.ColumnsCollectionID = "columns"
	}
	if strings.TrimSpace(cfg.TodosCollectionID) == "" {
		cfg.TodosCollectionID = "todos"
	}

	return cfg
}

func varcharAttribute(key string, size int, required bool) attributeSpec {
	return attributeSpec{
		Kind: "string",
		Key:  key,
		Payload: map[string]any{
			"key":      key,
			"size":     size,
			"required": required,
			"array":    false,
		},
	}
}

func integerAttribute(key string, required bool) attributeSpec {
	return attributeSpec{
		Kind: "integer",
		Key:  key,
		Payload: map[string]any{
			"key":      key,
			"required": required,
			"array":    false,
		},
	}
}

func datetimeAttribute(key string, required bool) attributeSpec {
	return attributeSpec{
		Kind: "datetime",
		Key:  key,
		Payload: map[string]any{
			"key":      key,
			"required": required,
			"array":    false,
		},
	}
}

func (c *Client) ensureDatabase(ctx context.Context, databaseID, databaseName string) error {
	getPath := fmt.Sprintf("/tablesdb/%s", databaseID)
	if err := c.doServerJSON(ctx, http.MethodGet, getPath, nil, nil); err == nil {
		return nil
	} else if !isStatus(err, http.StatusNotFound) {
		return err
	}

	body := map[string]any{"databaseId": databaseID, "name": databaseName}
	if err := c.doServerJSON(ctx, http.MethodPost, "/tablesdb", body, nil); err != nil {
		if isAlreadyExists(err) {
			return nil
		}
		return err
	}

	return nil
}

func (c *Client) ensureCollection(ctx context.Context, databaseID string, spec collectionSpec) error {
	getPath := fmt.Sprintf("/tablesdb/%s/tables/%s", databaseID, spec.ID)
	if err := c.doServerJSON(ctx, http.MethodGet, getPath, nil, nil); err != nil {
		if !isStatus(err, http.StatusNotFound) {
			return err
		}

		createPath := fmt.Sprintf("/tablesdb/%s/tables", databaseID)
		payload := map[string]any{
			"tableId":     spec.ID,
			"name":        spec.Name,
			"permissions": []string{},
			"rowSecurity": false,
			"enabled":     true,
		}
		if err := c.doServerJSON(ctx, http.MethodPost, createPath, payload, nil); err != nil && !isAlreadyExists(err) {
			return err
		}
	}

	for _, attr := range spec.Attrs {
		if err := c.ensureAttribute(ctx, databaseID, spec.ID, attr); err != nil {
			return fmt.Errorf("ensure attribute %q: %w", attr.Key, err)
		}
	}

	for _, idx := range spec.Indexes {
		if err := c.ensureIndex(ctx, databaseID, spec.ID, idx); err != nil {
			return fmt.Errorf("ensure index %q: %w", idx.Key, err)
		}
	}

	return nil
}

func (c *Client) ensureAttribute(ctx context.Context, databaseID, collectionID string, spec attributeSpec) error {
	createPath := fmt.Sprintf("/tablesdb/%s/tables/%s/columns/%s", databaseID, collectionID, spec.Kind)
	err := c.doServerJSON(ctx, http.MethodPost, createPath, spec.Payload, nil)
	if err != nil && !isAlreadyExists(err) {
		return err
	}

	if err := c.waitUntilAvailable(ctx, fmt.Sprintf("/tablesdb/%s/tables/%s/columns/%s", databaseID, collectionID, spec.Key)); err != nil {
		return err
	}

	return nil
}

func (c *Client) ensureIndex(ctx context.Context, databaseID, collectionID string, spec indexSpec) error {
	createPath := fmt.Sprintf("/tablesdb/%s/tables/%s/indexes", databaseID, collectionID)
	payload := map[string]any{
		"key":     spec.Key,
		"type":    spec.Type,
		"columns": spec.Attributes,
		"orders":  spec.Orders,
	}
	err := c.doServerJSON(ctx, http.MethodPost, createPath, payload, nil)
	if err != nil && !isAlreadyExists(err) {
		return err
	}

	if err := c.waitUntilAvailable(ctx, fmt.Sprintf("/tablesdb/%s/tables/%s/indexes/%s", databaseID, collectionID, spec.Key)); err != nil {
		return err
	}

	return nil
}

func (c *Client) waitUntilAvailable(ctx context.Context, path string) error {
	deadline := time.Now().Add(defaultBootstrapTimeout)
	for {
		var response statusResponse
		err := c.doServerJSON(ctx, http.MethodGet, path, nil, &response)
		if err == nil {
			status := strings.ToLower(strings.TrimSpace(response.Status))
			if status == "" || status == "available" {
				return nil
			}
		}

		if time.Now().After(deadline) {
			if err != nil {
				return fmt.Errorf("resource %s not ready: %w", path, err)
			}
			return fmt.Errorf("resource %s not ready before timeout", path)
		}

		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(defaultPollInterval):
		}
	}
}

func (c *Client) doServerJSON(ctx context.Context, method, path string, in any, out any) error {
	var body io.Reader
	if in != nil {
		payload, err := json.Marshal(in)
		if err != nil {
			return fmt.Errorf("marshal request payload: %w", err)
		}
		body = bytes.NewReader(payload)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.endpoint+path, body)
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	c.setProjectHeader(req)
	c.setAPIKey(req)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("appwrite request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		raw, _ := io.ReadAll(resp.Body)
		return &appwriteAPIError{Status: resp.StatusCode, Detail: summarizeExternalBody(raw)}
	}

	if out == nil {
		_, _ = io.Copy(io.Discard, resp.Body)
		return nil
	}

	if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
		return fmt.Errorf("decode response: %w", err)
	}

	return nil
}

func isStatus(err error, status int) bool {
	var apiErr *appwriteAPIError
	if !errors.As(err, &apiErr) {
		return false
	}

	return apiErr.Status == status
}

func isAlreadyExists(err error) bool {
	if isStatus(err, http.StatusConflict) {
		return true
	}

	var apiErr *appwriteAPIError
	if !errors.As(err, &apiErr) {
		return false
	}

	detail := strings.ToLower(strings.TrimSpace(apiErr.Detail))
	return strings.Contains(detail, "already exists")
}
