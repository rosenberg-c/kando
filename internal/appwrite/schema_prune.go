package appwrite

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"go_macos_todo/internal/schema"
)

// PruneOptions controls whether planned prune operations are applied.
type PruneOptions struct {
	Apply bool
}

// PruneReport summarizes planned and applied prune operations.
type PruneReport struct {
	Planned []string
	Applied []string
}

type listTablesResponse struct {
	Total  int         `json:"total"`
	Tables []tableInfo `json:"tables"`
}

type tableInfo struct {
	ID string `json:"$id"`
}

type listColumnsResponse struct {
	Total   int          `json:"total"`
	Columns []columnInfo `json:"columns"`
}

type columnInfo struct {
	Key      string `json:"key"`
	Kind     string `json:"type"`
	Required bool   `json:"required"`
	Size     int    `json:"size"`
}

type listIndexesResponse struct {
	Total   int         `json:"total"`
	Indexes []indexInfo `json:"indexes"`
}

const pruneListPageLimit = 100

type indexInfo struct {
	Key     string   `json:"key"`
	Kind    string   `json:"type"`
	Columns []string `json:"columns"`
	Orders  []string `json:"orders"`
}

// PruneKanbanSchema removes unmanaged tables/columns/indexes from Appwrite.
// By default it performs a dry-run and only applies deletions when options.Apply is true.
func (c *Client) PruneKanbanSchema(ctx context.Context, cfg SchemaConfig, options PruneOptions) (PruneReport, error) {
	definition := schema.KanbanAppwriteDatabase()
	schema.ApplyAppwriteIDOverrides(&definition, schema.AppwriteIDOverrides{
		DatabaseID:     cfg.DatabaseID,
		DatabaseName:   cfg.DatabaseName,
		BoardsTableID:  cfg.BoardsCollectionID,
		ColumnsTableID: cfg.ColumnsCollectionID,
		TasksTableID:   cfg.TasksCollectionID,
	})

	managedTables := map[string]schema.AppwriteTable{}
	for _, table := range definition.Tables {
		managedTables[table.ID] = table
	}

	var report PruneReport

	tables, err := c.listAllTables(ctx, definition.ID)
	if err != nil {
		return report, err
	}

	for _, table := range tables {
		if _, ok := managedTables[table.ID]; !ok {
			report.Planned = append(report.Planned, fmt.Sprintf("delete table %s", table.ID))
			if options.Apply {
				if err := c.doServerJSON(ctx, "DELETE", fmt.Sprintf("/tablesdb/%s/tables/%s", definition.ID, table.ID), nil, nil); err != nil {
					return report, err
				}
				report.Applied = append(report.Applied, fmt.Sprintf("deleted table %s", table.ID))
			}
			continue
		}

		managed := managedTables[table.ID]
		if err := c.pruneTableIndexes(ctx, definition.ID, table.ID, managed, options, &report); err != nil {
			return report, err
		}
		if err := c.pruneTableColumns(ctx, definition.ID, table.ID, managed, options, &report); err != nil {
			return report, err
		}
	}

	sort.Strings(report.Planned)
	sort.Strings(report.Applied)
	return report, nil
}

func (c *Client) pruneTableColumns(ctx context.Context, databaseID, tableID string, managed schema.AppwriteTable, options PruneOptions, report *PruneReport) error {
	managedKeys := map[string]struct{}{}
	for _, column := range managed.Columns {
		managedKeys[column.Key] = struct{}{}
	}

	columns, err := c.listAllColumns(ctx, databaseID, tableID)
	if err != nil {
		return err
	}

	for _, column := range columns {
		if _, ok := managedKeys[column.Key]; ok {
			continue
		}
		report.Planned = append(report.Planned, fmt.Sprintf("delete column %s.%s", tableID, column.Key))
		if options.Apply {
			if err := c.doServerJSON(ctx, "DELETE", fmt.Sprintf("/tablesdb/%s/tables/%s/columns/%s", databaseID, tableID, column.Key), nil, nil); err != nil {
				return err
			}
			report.Applied = append(report.Applied, fmt.Sprintf("deleted column %s.%s", tableID, column.Key))
		}
	}

	return nil
}

func (c *Client) pruneTableIndexes(ctx context.Context, databaseID, tableID string, managed schema.AppwriteTable, options PruneOptions, report *PruneReport) error {
	managedKeys := map[string]struct{}{}
	for _, index := range managed.Indexes {
		managedKeys[index.Key] = struct{}{}
	}

	indexes, err := c.listAllIndexes(ctx, databaseID, tableID)
	if err != nil {
		return err
	}

	for _, index := range indexes {
		if strings.HasPrefix(index.Key, "_") {
			continue
		}
		if _, ok := managedKeys[index.Key]; ok {
			continue
		}
		report.Planned = append(report.Planned, fmt.Sprintf("delete index %s.%s", tableID, index.Key))
		if options.Apply {
			if err := c.doServerJSON(ctx, "DELETE", fmt.Sprintf("/tablesdb/%s/tables/%s/indexes/%s", databaseID, tableID, index.Key), nil, nil); err != nil {
				return err
			}
			report.Applied = append(report.Applied, fmt.Sprintf("deleted index %s.%s", tableID, index.Key))
		}
	}

	return nil
}

func (c *Client) listAllTables(ctx context.Context, databaseID string) ([]tableInfo, error) {
	all := make([]tableInfo, 0)
	for offset, page := 0, 0; ; offset, page = offset+pruneListPageLimit, page+1 {
		if page > 1000 {
			return nil, fmt.Errorf("list tables exceeded safety page limit")
		}

		var response listTablesResponse
		if err := c.doServerJSON(ctx, "GET", withListQueries(fmt.Sprintf("/tablesdb/%s/tables", databaseID), offset), nil, &response); err != nil {
			return nil, err
		}

		all = append(all, response.Tables...)
		if shouldStopPaging(len(response.Tables), len(all), response.Total) {
			return all, nil
		}
	}
}

func (c *Client) listAllColumns(ctx context.Context, databaseID, tableID string) ([]columnInfo, error) {
	all := make([]columnInfo, 0)
	for offset, page := 0, 0; ; offset, page = offset+pruneListPageLimit, page+1 {
		if page > 1000 {
			return nil, fmt.Errorf("list columns exceeded safety page limit")
		}

		var response listColumnsResponse
		if err := c.doServerJSON(ctx, "GET", withListQueries(fmt.Sprintf("/tablesdb/%s/tables/%s/columns", databaseID, tableID), offset), nil, &response); err != nil {
			return nil, err
		}

		all = append(all, response.Columns...)
		if shouldStopPaging(len(response.Columns), len(all), response.Total) {
			return all, nil
		}
	}
}

func (c *Client) listAllIndexes(ctx context.Context, databaseID, tableID string) ([]indexInfo, error) {
	all := make([]indexInfo, 0)
	for offset, page := 0, 0; ; offset, page = offset+pruneListPageLimit, page+1 {
		if page > 1000 {
			return nil, fmt.Errorf("list indexes exceeded safety page limit")
		}

		var response listIndexesResponse
		if err := c.doServerJSON(ctx, "GET", withListQueries(fmt.Sprintf("/tablesdb/%s/tables/%s/indexes", databaseID, tableID), offset), nil, &response); err != nil {
			return nil, err
		}

		all = append(all, response.Indexes...)
		if shouldStopPaging(len(response.Indexes), len(all), response.Total) {
			return all, nil
		}
	}
}

func withListQueries(path string, offset int) string {
	return withPagedQueries(path, pruneListPageLimit, offset)
}

func shouldStopPaging(pageCount, accumulatedCount, total int) bool {
	if pageCount < pruneListPageLimit {
		return true
	}
	if total > 0 && accumulatedCount >= total {
		return true
	}
	return false
}
