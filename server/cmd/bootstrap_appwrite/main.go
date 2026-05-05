package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"go_macos_todo/server/internal/appwrite"
	"go_macos_todo/internal/shared/config"
	"go_macos_todo/server/internal/schema"
)

func main() {
	if err := config.LoadDotEnvIfPresent(".env.server"); err != nil {
		log.Fatalf("load .env.server: %v", err)
	}

	endpoint := strings.TrimSpace(os.Getenv("APPWRITE_ENDPOINT"))
	projectID := strings.TrimSpace(os.Getenv("APPWRITE_PROJECT_ID"))
	apiKey := strings.TrimSpace(os.Getenv("APPWRITE_DB_API_KEY"))
	if apiKey == "" {
		apiKey = strings.TrimSpace(os.Getenv("APPWRITE_AUTH_API_KEY"))
	}

	if endpoint == "" || projectID == "" || apiKey == "" {
		log.Fatal("APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, and APPWRITE_DB_API_KEY (or APPWRITE_AUTH_API_KEY) are required")
	}

	client := appwrite.NewClient(endpoint, projectID, apiKey, nil)
	cfg := appwrite.SchemaConfig{
		DatabaseID:          strings.TrimSpace(os.Getenv("APPWRITE_DB_ID")),
		DatabaseName:        strings.TrimSpace(os.Getenv("APPWRITE_DB_NAME")),
		BoardsCollectionID:  strings.TrimSpace(os.Getenv("APPWRITE_BOARDS_COLLECTION_ID")),
		ColumnsCollectionID: strings.TrimSpace(os.Getenv("APPWRITE_COLUMNS_COLLECTION_ID")),
		TasksCollectionID:   strings.TrimSpace(os.Getenv("APPWRITE_TASKS_COLLECTION_ID")),
	}

	if err := client.BootstrapKanbanSchema(context.Background(), cfg); err != nil {
		log.Fatalf("bootstrap appwrite schema: %v", err)
	}

	definition := schema.KanbanAppwriteDatabase()
	schema.ApplyAppwriteIDOverrides(&definition, schema.AppwriteIDOverrides{
		DatabaseID:     cfg.DatabaseID,
		DatabaseName:   cfg.DatabaseName,
		BoardsTableID:  cfg.BoardsCollectionID,
		ColumnsTableID: cfg.ColumnsCollectionID,
		TasksTableID:   cfg.TasksCollectionID,
	})

	tableIDs := make([]string, 0, len(definition.Tables))
	for _, table := range definition.Tables {
		tableIDs = append(tableIDs, table.ID)
	}

	fmt.Printf("appwrite schema ready (db=%s, tables=%s)\n", definition.ID, strings.Join(tableIDs, ","))
}
