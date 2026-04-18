package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"go_macos_todo/internal/api/handlers"
	"go_macos_todo/internal/api/middleware"
	"go_macos_todo/internal/appwrite"
	"go_macos_todo/internal/config"
)

const (
	mb            int64 = 1024 * 1024
	defaultWarnMB int64 = 5
	defaultMaxMB  int64 = 10
)

func main() {
	if err := config.LoadDotEnvIfPresent(".env.server"); err != nil {
		log.Fatalf("load .env.server: %v", err)
	}

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

	appwriteEndpoint := os.Getenv("APPWRITE_ENDPOINT")
	appwriteProjectID := os.Getenv("APPWRITE_PROJECT_ID")
	appwriteAPIKey := os.Getenv("APPWRITE_AUTH_API_KEY")
	if appwriteEndpoint == "" || appwriteProjectID == "" {
		log.Println("auth disabled: set APPWRITE_ENDPOINT and APPWRITE_PROJECT_ID to enable auth routes")
	} else {
		appwriteClient := appwrite.NewClient(appwriteEndpoint, appwriteProjectID, appwriteAPIKey, nil)
		loginLimiter := handlers.NewLoginRateLimiter(5, 10*time.Minute, 15*time.Minute)
		mux.HandleFunc("/auth/login", handlers.AuthLogin(appwriteClient, loginLimiter))
		mux.HandleFunc("/auth/refresh", handlers.AuthRefresh(appwriteClient))
		mux.HandleFunc("/auth/logout", handlers.AuthLogout(appwriteClient))
		mux.Handle("/me", middleware.Auth(appwriteClient, http.HandlerFunc(handlers.Me)))
	}

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

	warnMB, err := readPositiveIntEnv("LOG_WARN_MB", defaultWarnMB)
	if err != nil {
		return nil, err
	}
	maxMB, err := readPositiveIntEnv("LOG_MAX_MB", defaultMaxMB)
	if err != nil {
		return nil, err
	}
	if warnMB > maxMB {
		return nil, fmt.Errorf("invalid log size settings: LOG_WARN_MB (%d) cannot exceed LOG_MAX_MB (%d)", warnMB, maxMB)
	}

	logPath := filepath.Join(logDir, "server.log")
	if info, statErr := os.Stat(logPath); statErr == nil {
		sizeBytes := info.Size()
		if warn, err := validateLogSize(sizeBytes, warnMB*mb, maxMB*mb); err != nil {
			return nil, fmt.Errorf("log file too large: %w", err)
		} else if warn {
			log.Printf("warning: %s is %.2f MB which exceeds LOG_WARN_MB=%d MB", logPath, float64(sizeBytes)/float64(mb), warnMB)
		}
	} else if !os.IsNotExist(statErr) {
		return nil, statErr
	}

	file, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return nil, err
	}

	log.SetOutput(io.MultiWriter(os.Stdout, file))
	log.SetFlags(log.Ldate | log.Ltime | log.Lmicroseconds | log.LUTC)

	return file, nil
}

func readPositiveIntEnv(name string, fallback int64) (int64, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback, nil
	}

	value, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || value <= 0 {
		return 0, fmt.Errorf("invalid %s=%q: must be a positive integer", name, raw)
	}

	return value, nil
}

func validateLogSize(sizeBytes, warnBytes, maxBytes int64) (bool, error) {
	if sizeBytes > maxBytes {
		return false, fmt.Errorf("size %.2f MB exceeds LOG_MAX_MB=%.2f MB", float64(sizeBytes)/float64(mb), float64(maxBytes)/float64(mb))
	}

	return sizeBytes > warnBytes, nil
}
