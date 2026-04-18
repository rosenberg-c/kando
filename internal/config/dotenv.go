package config

import (
	"bufio"
	"os"
	"strings"
)

// LoadDotEnvIfPresent loads KEY=VALUE pairs from a local .env file.
// Existing environment variables are not overridden.
func LoadDotEnvIfPresent(path string) error {
	file, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}

		return err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}

		key = strings.TrimSpace(key)
		if key == "" {
			continue
		}

		if _, exists := os.LookupEnv(key); exists {
			continue
		}

		value = strings.TrimSpace(value)
		value = strings.Trim(value, "\"")
		_ = os.Setenv(key, value)
	}

	return scanner.Err()
}
