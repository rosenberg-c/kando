package main

import (
	"context"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	"go_macos_todo/apps/cli/ui"
	"go_macos_todo/apps/cli/internal/cli"
	"go_macos_todo/internal/config"
)

func main() {
	if err := config.LoadDotEnvIfPresent(".env.app"); err != nil {
		fmt.Fprintf(os.Stderr, ui.T("cli.env.load_error"), err)
		os.Exit(1)
	}

	configDir, err := os.UserConfigDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, ui.T("cli.config.user_dir_error"), err)
		os.Exit(1)
	}

	store := cli.NewSecureTokenStore(filepath.Join(configDir, "go_macos_todo", "auth.json"))
	apiBaseURL := os.Getenv("TODO_API_BASE_URL")
	if apiBaseURL == "" {
		apiBaseURL = "http://localhost:8080"
	}
	warnIfInsecureAPIBaseURL(apiBaseURL)

	apiClient, err := cli.NewHTTPAPIClient(apiBaseURL, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, ui.T("cli.api.init_error"), err)
		os.Exit(1)
	}

	service := cli.NewService(store, apiClient)

	ctx := context.Background()
	if len(os.Args) > 1 && os.Args[1] != "tui" {
		fmt.Fprintln(os.Stderr, ui.T("cli.tui.unsupported_args"))
		os.Exit(2)
	}
	if len(os.Args) > 2 {
		fmt.Fprintln(os.Stderr, ui.T("cli.tui.unsupported_args"))
		os.Exit(2)
	}

	if err := runTUI(ctx, service, store, os.Stdin, os.Stdout); err != nil {
		fmt.Fprintf(os.Stderr, ui.T("cli.tui.failed"), err)
		os.Exit(1)
	}
}

func warnIfInsecureAPIBaseURL(rawURL string) {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return
	}

	if !strings.EqualFold(parsed.Scheme, "http") {
		return
	}

	hostname := parsed.Hostname()
	if hostname == "localhost" || hostname == "127.0.0.1" || hostname == "::1" {
		return
	}

	if ip := net.ParseIP(hostname); ip != nil && ip.IsLoopback() {
		return
	}

	fmt.Fprintf(os.Stderr, ui.T("cli.warning.insecure_base_url"), rawURL)
}
