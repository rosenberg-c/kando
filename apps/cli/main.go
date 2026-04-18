package main

import (
	"bufio"
	"context"
	"flag"
	"fmt"
	"net"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"go_macos_todo/internal/cli"
	"go_macos_todo/internal/config"
)

func main() {
	if err := config.LoadDotEnvIfPresent(".env.app"); err != nil {
		fmt.Fprintf(os.Stderr, "load .env.app: %v\n", err)
		os.Exit(1)
	}

	if len(os.Args) < 2 {
		printUsage()
		os.Exit(2)
	}

	configDir, err := os.UserConfigDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "resolve user config dir: %v\n", err)
		os.Exit(1)
	}

	store := cli.NewSecureTokenStore(filepath.Join(configDir, "go_macos_todo", "auth.json"))
	apiBaseURL := os.Getenv("TODO_API_BASE_URL")
	if apiBaseURL == "" {
		apiBaseURL = "http://localhost:8080"
	}
	warnIfInsecureAPIBaseURL(apiBaseURL)

	service := cli.NewService(store, cli.NewHTTPAPIClient(apiBaseURL, nil))

	ctx := context.Background()
	switch os.Args[1] {
	case "login":
		if err := runLogin(ctx, service, os.Args[2:]); err != nil {
			fmt.Fprintf(os.Stderr, "login failed: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("login successful")
	case "me":
		body, err := service.Me(ctx)
		if err != nil {
			fmt.Fprintf(os.Stderr, "me failed: %v\n", err)
			os.Exit(1)
		}
		fmt.Println(string(body))
	case "logout":
		if err := service.Logout(ctx); err != nil {
			fmt.Fprintf(os.Stderr, "logout failed: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("logout successful")
	default:
		printUsage()
		os.Exit(2)
	}
}

func runLogin(ctx context.Context, service *cli.Service, args []string) error {
	fs := flag.NewFlagSet("login", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)

	email := fs.String("email", "", "Appwrite account email")
	passwordStdin := fs.Bool("password-stdin", false, "Read password from stdin")

	if err := fs.Parse(args); err != nil {
		return err
	}

	if strings.TrimSpace(*email) == "" {
		return fmt.Errorf("email is required")
	}

	var password string
	if *passwordStdin {
		reader := bufio.NewReader(os.Stdin)
		line, err := reader.ReadString('\n')
		if err != nil {
			return fmt.Errorf("read password from stdin: %w", err)
		}
		password = strings.TrimSpace(line)
	} else {
		fmt.Fprint(os.Stderr, "Password: ")
		promptPassword, err := readPassword()
		fmt.Fprintln(os.Stderr)
		if err != nil {
			return fmt.Errorf("read password: %w", err)
		}

		password = promptPassword
	}

	if password == "" {
		return fmt.Errorf("password is required")
	}

	return service.Login(ctx, *email, password)
}

func readPassword() (string, error) {
	tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
	if err != nil {
		return "", fmt.Errorf("interactive password input requires tty; use --password-stdin")
	}
	defer tty.Close()

	disableEcho := exec.Command("stty", "-echo")
	disableEcho.Stdin = tty
	disableEcho.Stdout = tty
	disableEcho.Stderr = tty
	if err := disableEcho.Run(); err != nil {
		return "", err
	}
	defer func() {
		restoreEcho := exec.Command("stty", "echo")
		restoreEcho.Stdin = tty
		restoreEcho.Stdout = tty
		restoreEcho.Stderr = tty
		_ = restoreEcho.Run()
	}()

	reader := bufio.NewReader(tty)
	password, err := reader.ReadString('\n')
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(password), nil
}

func printUsage() {
	fmt.Println("Usage:")
	fmt.Println("  todo login --email <email>")
	fmt.Println("  todo me")
	fmt.Println("  todo logout")
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

	fmt.Fprintf(os.Stderr, "warning: TODO_API_BASE_URL uses insecure HTTP for non-localhost endpoint (%s); prefer HTTPS\n", rawURL)
}
