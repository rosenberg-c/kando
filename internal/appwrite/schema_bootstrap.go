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

	"go_macos_todo/internal/schema"
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
	TasksCollectionID   string
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

	definition := schema.KanbanAppwriteDatabase()
	schema.ApplyAppwriteIDOverrides(&definition, schema.AppwriteIDOverrides{
		DatabaseID:     cfg.DatabaseID,
		DatabaseName:   cfg.DatabaseName,
		BoardsTableID:  cfg.BoardsCollectionID,
		ColumnsTableID: cfg.ColumnsCollectionID,
		TasksTableID:   cfg.TasksCollectionID,
	})

	if err := c.ensureDatabase(ctx, definition.ID, definition.Name); err != nil {
		return fmt.Errorf("ensure database %q: %w", definition.ID, err)
	}

	collections := make([]collectionSpec, 0, len(definition.Tables))
	for _, table := range definition.Tables {
		attrs := make([]attributeSpec, 0, len(table.Columns))
		for _, column := range table.Columns {
			attrs = append(attrs, attributeSpec{
				Kind: column.Kind,
				Key:  column.Key,
				Payload: map[string]any{
					"key":      column.Key,
					"required": column.Required,
					"array":    false,
				},
			})
			if column.Kind == "string" {
				attrs[len(attrs)-1].Payload["size"] = column.Size
			}
		}

		indexes := make([]indexSpec, 0, len(table.Indexes))
		for _, index := range table.Indexes {
			indexes = append(indexes, indexSpec{
				Key:        index.Key,
				Type:       index.Type,
				Attributes: index.Columns,
				Orders:     index.Orders,
			})
		}

		collections = append(collections, collectionSpec{
			ID:      table.ID,
			Name:    table.Name,
			Attrs:   attrs,
			Indexes: indexes,
		})
	}

	for _, spec := range collections {
		if err := c.ensureCollection(ctx, definition.ID, spec); err != nil {
			return fmt.Errorf("ensure collection %q: %w", spec.ID, err)
		}
	}

	return nil
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
		return explainIndexBootstrapError(err, collectionID, spec)
	}

	if err := c.waitUntilAvailable(ctx, fmt.Sprintf("/tablesdb/%s/tables/%s/indexes/%s", databaseID, collectionID, spec.Key)); err != nil {
		return err
	}

	return nil
}

func explainIndexBootstrapError(err error, collectionID string, spec indexSpec) error {
	var apiErr *appwriteAPIError
	if errors.As(err, &apiErr) {
		detail := strings.ToLower(strings.TrimSpace(apiErr.Detail))
		if spec.Type == "unique" && (strings.Contains(detail, "duplicate") || strings.Contains(detail, "already exists") || strings.Contains(detail, "unique")) {
			return fmt.Errorf("create unique index %s.%s failed: existing rows violate uniqueness; clean duplicate data and rerun bootstrap: %w", collectionID, spec.Key, err)
		}
	}

	return err
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
