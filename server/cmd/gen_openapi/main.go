package main

import (
	"fmt"
	"os"
	"path/filepath"

	apiserver "kando/server/internal/api/server"
)

func main() {
	_, api := apiserver.NewAPI()
	apiserver.Register(api, apiserver.Dependencies{})

	payload, err := api.OpenAPI().DowngradeYAML()
	if err != nil {
		fmt.Fprintf(os.Stderr, "render openapi document: %v\n", err)
		os.Exit(1)
	}

	outputPath := filepath.Join("api", "openapi.yaml")
	if err := os.MkdirAll(filepath.Dir(outputPath), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "create api directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.WriteFile(outputPath, payload, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "write openapi spec: %v\n", err)
		os.Exit(1)
	}
}
