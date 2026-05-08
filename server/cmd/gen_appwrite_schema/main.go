package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"kando/server/internal/schema"
)

func main() {
	definition := schema.KanbanAppwriteDatabase()

	payload, err := json.MarshalIndent(definition, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "marshal appwrite schema: %v\n", err)
		os.Exit(1)
	}
	payload = append(payload, '\n')

	outputPath := filepath.Join("api", "appwrite-schema.json")
	if err := os.MkdirAll(filepath.Dir(outputPath), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "create api directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.WriteFile(outputPath, payload, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "write appwrite schema: %v\n", err)
		os.Exit(1)
	}
}
