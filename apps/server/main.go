package main

import (
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"go_macos_todo/internal/api/handlers"
	"go_macos_todo/internal/api/middleware"
)

func main() {
	logFile, err := setupLogging()
	if err != nil {
		log.Fatalf("configure logging: %v", err)
	}
	defer func() {
		if closeErr := logFile.Close(); closeErr != nil {
			log.Printf("close log file: %v", closeErr)
		}
	}()

	mux := http.NewServeMux()
	mux.HandleFunc("/hello", handlers.HelloWorld)

	server := &http.Server{
		Addr:    ":8080",
		Handler: middleware.RequestID(middleware.RequestLogger(mux)),
	}

	log.Println("server listening on http://localhost:8080")
	if err = server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("server stopped: %v", err)
	}
}

func setupLogging() (*os.File, error) {
	logDir := filepath.Join("logs")
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		return nil, err
	}

	logPath := filepath.Join(logDir, "server.log")
	file, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return nil, err
	}

	log.SetOutput(io.MultiWriter(os.Stdout, file))
	log.SetFlags(log.Ldate | log.Ltime | log.Lmicroseconds | log.LUTC)

	return file, nil
}
