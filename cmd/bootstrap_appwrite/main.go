package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"go_macos_todo/internal/appwrite"
	"go_macos_todo/internal/config"
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
		TodosCollectionID:   strings.TrimSpace(os.Getenv("APPWRITE_TODOS_COLLECTION_ID")),
	}

	if err := client.BootstrapKanbanSchema(context.Background(), cfg); err != nil {
		log.Fatalf("bootstrap appwrite schema: %v", err)
	}

	finalCfg := appwrite.SchemaConfig{
		DatabaseID:          cfg.DatabaseID,
		DatabaseName:        cfg.DatabaseName,
		BoardsCollectionID:  cfg.BoardsCollectionID,
		ColumnsCollectionID: cfg.ColumnsCollectionID,
		TodosCollectionID:   cfg.TodosCollectionID,
	}
	finalCfg = normalizeForOutput(finalCfg)

	fmt.Printf("appwrite schema ready (db=%s, collections=%s,%s,%s)\n", finalCfg.DatabaseID, finalCfg.BoardsCollectionID, finalCfg.ColumnsCollectionID, finalCfg.TodosCollectionID)
}

func normalizeForOutput(cfg appwrite.SchemaConfig) appwrite.SchemaConfig {
	if cfg.DatabaseID == "" {
		cfg.DatabaseID = "todo"
	}
	if cfg.DatabaseName == "" {
		cfg.DatabaseName = "Todo"
	}
	if cfg.BoardsCollectionID == "" {
		cfg.BoardsCollectionID = "boards"
	}
	if cfg.ColumnsCollectionID == "" {
		cfg.ColumnsCollectionID = "columns"
	}
	if cfg.TodosCollectionID == "" {
		cfg.TodosCollectionID = "todos"
	}

	return cfg
}
