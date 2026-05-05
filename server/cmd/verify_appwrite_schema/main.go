package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"go_macos_todo/server/internal/appwrite"
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
		TasksCollectionID:   strings.TrimSpace(os.Getenv("APPWRITE_TASKS_COLLECTION_ID")),
	}

	report, err := client.VerifyKanbanSchema(context.Background(), cfg)
	if err != nil {
		log.Fatalf("verify appwrite schema: %v", err)
	}

	if !report.HasDrift() {
		fmt.Println("appwrite schema verify: OK")
		return
	}

	fmt.Println("appwrite schema verify: drift detected")
	printSection("missing tables", report.MissingTables)
	printSection("missing columns", report.MissingColumns)
	printSection("missing indexes", report.MissingIndexes)
	printSection("mismatched columns", report.MismatchedColumns)
	printSection("mismatched indexes", report.MismatchedIndexes)
	printSection("unexpected tables", report.UnexpectedTables)
	printSection("unexpected columns", report.UnexpectedColumns)
	printSection("unexpected indexes", report.UnexpectedIndexes)
	fmt.Println("recommended: make appwrite-bootstrap && make appwrite-prune-apply && make verify-appwrite-schema")
	os.Exit(1)
}

func printSection(name string, values []string) {
	if len(values) == 0 {
		return
	}
	fmt.Printf("- %s:\n", name)
	for _, value := range values {
		fmt.Printf("  - %s\n", value)
	}
}
