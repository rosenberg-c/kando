package appwrite

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"kando/server/internal/schema"
)

// SchemaVerifyReport summarizes schema drift between expected and live Appwrite resources.
type SchemaVerifyReport struct {
	MissingTables     []string
	MissingColumns    []string
	MissingIndexes    []string
	MismatchedColumns []string
	MismatchedIndexes []string
	UnexpectedTables  []string
	UnexpectedColumns []string
	UnexpectedIndexes []string
}

// HasDrift reports whether any expected-vs-live mismatch exists.
func (r SchemaVerifyReport) HasDrift() bool {
	return len(r.MissingTables) > 0 || len(r.MissingColumns) > 0 || len(r.MissingIndexes) > 0 || len(r.MismatchedColumns) > 0 || len(r.MismatchedIndexes) > 0 || len(r.UnexpectedTables) > 0 || len(r.UnexpectedColumns) > 0 || len(r.UnexpectedIndexes) > 0
}

// VerifyKanbanSchema compares live Appwrite schema resources with the managed kanban schema definition.
func (c *Client) VerifyKanbanSchema(ctx context.Context, cfg SchemaConfig) (SchemaVerifyReport, error) {
	definition := schema.KanbanAppwriteDatabase()
	schema.ApplyAppwriteIDOverrides(&definition, schema.AppwriteIDOverrides{
		DatabaseID:     cfg.DatabaseID,
		DatabaseName:   cfg.DatabaseName,
		BoardsTableID:  cfg.BoardsCollectionID,
		ColumnsTableID: cfg.ColumnsCollectionID,
		TasksTableID:   cfg.TasksCollectionID,
	})

	report := SchemaVerifyReport{}

	liveTables, err := c.listAllTables(ctx, definition.ID)
	if err != nil {
		return report, err
	}
	liveTableSet := map[string]struct{}{}
	for _, table := range liveTables {
		liveTableSet[table.ID] = struct{}{}
	}

	managedTableMap := map[string]schema.AppwriteTable{}
	for _, table := range definition.Tables {
		managedTableMap[table.ID] = table
		if _, ok := liveTableSet[table.ID]; !ok {
			report.MissingTables = append(report.MissingTables, table.ID)
		}
	}

	for liveTableID := range liveTableSet {
		if _, ok := managedTableMap[liveTableID]; !ok {
			report.UnexpectedTables = append(report.UnexpectedTables, liveTableID)
		}
	}

	for _, table := range definition.Tables {
		if _, ok := liveTableSet[table.ID]; !ok {
			continue
		}

		liveColumns, err := c.listAllColumns(ctx, definition.ID, table.ID)
		if err != nil {
			return report, err
		}
		liveColumnSet := map[string]columnInfo{}
		for _, column := range liveColumns {
			liveColumnSet[column.Key] = column
		}

		managedColumnSet := map[string]struct{}{}
		for _, column := range table.Columns {
			managedColumnSet[column.Key] = struct{}{}
			liveColumn, ok := liveColumnSet[column.Key]
			if !ok {
				report.MissingColumns = append(report.MissingColumns, fmt.Sprintf("%s.%s", table.ID, column.Key))
				continue
			}
			if !matchesColumnShape(liveColumn, column) {
				report.MismatchedColumns = append(report.MismatchedColumns, fmt.Sprintf("%s.%s", table.ID, column.Key))
			}
		}
		for liveColumnKey := range liveColumnSet {
			if _, ok := managedColumnSet[liveColumnKey]; !ok {
				report.UnexpectedColumns = append(report.UnexpectedColumns, fmt.Sprintf("%s.%s", table.ID, liveColumnKey))
			}
		}

		liveIndexes, err := c.listAllIndexes(ctx, definition.ID, table.ID)
		if err != nil {
			return report, err
		}
		liveIndexSet := map[string]indexInfo{}
		for _, index := range liveIndexes {
			if strings.HasPrefix(index.Key, "_") {
				continue
			}
			liveIndexSet[index.Key] = index
		}

		managedIndexSet := map[string]struct{}{}
		for _, index := range table.Indexes {
			managedIndexSet[index.Key] = struct{}{}
			liveIndex, ok := liveIndexSet[index.Key]
			if !ok {
				report.MissingIndexes = append(report.MissingIndexes, fmt.Sprintf("%s.%s", table.ID, index.Key))
				continue
			}
			if !matchesIndexShape(liveIndex, index) {
				report.MismatchedIndexes = append(report.MismatchedIndexes, fmt.Sprintf("%s.%s", table.ID, index.Key))
			}
		}
		for liveIndexKey := range liveIndexSet {
			if _, ok := managedIndexSet[liveIndexKey]; !ok {
				report.UnexpectedIndexes = append(report.UnexpectedIndexes, fmt.Sprintf("%s.%s", table.ID, liveIndexKey))
			}
		}
	}

	sort.Strings(report.MissingTables)
	sort.Strings(report.MissingColumns)
	sort.Strings(report.MissingIndexes)
	sort.Strings(report.MismatchedColumns)
	sort.Strings(report.MismatchedIndexes)
	sort.Strings(report.UnexpectedTables)
	sort.Strings(report.UnexpectedColumns)
	sort.Strings(report.UnexpectedIndexes)

	return report, nil
}

func matchesColumnShape(live columnInfo, managed schema.AppwriteColumn) bool {
	if !strings.EqualFold(strings.TrimSpace(live.Kind), strings.TrimSpace(managed.Kind)) {
		return false
	}
	if live.Required != managed.Required {
		return false
	}
	if managed.Size > 0 && live.Size != managed.Size {
		return false
	}
	return true
}

func matchesIndexShape(live indexInfo, managed schema.AppwriteIndex) bool {
	if !strings.EqualFold(strings.TrimSpace(live.Kind), strings.TrimSpace(managed.Type)) {
		return false
	}
	if len(live.Columns) != len(managed.Columns) {
		return false
	}
	for i := range managed.Columns {
		if live.Columns[i] != managed.Columns[i] {
			return false
		}
	}
	if len(live.Orders) != len(managed.Orders) {
		return false
	}
	for i := range managed.Orders {
		if !strings.EqualFold(live.Orders[i], managed.Orders[i]) {
			return false
		}
	}
	return true
}
