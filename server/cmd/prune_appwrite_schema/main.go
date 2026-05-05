package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	"go_macos_todo/server/internal/appwrite"
	"go_macos_todo/internal/config"
)

func main() {
	apply := flag.Bool("apply", false, "apply destructive prune operations")
	flag.Parse()

	if *apply && strings.TrimSpace(os.Getenv("APPWRITE_PRUNE_CONFIRM")) != "YES" {
		log.Fatal("refusing destructive prune without APPWRITE_PRUNE_CONFIRM=YES")
	}

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

	report, err := client.PruneKanbanSchema(context.Background(), cfg, appwrite.PruneOptions{Apply: *apply})
	if err != nil {
		log.Fatalf("prune appwrite schema: %v", err)
	}

	if len(report.Planned) == 0 {
		fmt.Println("appwrite prune: nothing to remove")
		return
	}

	mode := "dry-run"
	if *apply {
		mode = "applied"
	}
	fmt.Printf("appwrite prune (%s):\n", mode)
	for _, step := range report.Planned {
		fmt.Printf("- %s\n", step)
	}

	if !*apply {
		fmt.Println("re-run with --apply to execute deletions")
	}
}
