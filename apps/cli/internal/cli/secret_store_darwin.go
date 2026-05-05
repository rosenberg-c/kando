//go:build darwin

package cli

import (
	"fmt"
	"os/exec"
	"os/user"
	"strings"
)

type keychainSecretStore struct {
	service string
	account string
}

func newSecretStore(service string) (SecretStore, error) {
	currentUser, err := user.Current()
	if err != nil {
		return nil, fmt.Errorf("resolve current user: %w", err)
	}

	return &keychainSecretStore{service: service, account: currentUser.Username}, nil
}

func (s *keychainSecretStore) Save(secret string) error {
	command := exec.Command("security", "add-generic-password", "-a", s.account, "-s", s.service, "-w", secret, "-U")
	output, err := command.CombinedOutput()
	if err != nil {
		return fmt.Errorf("keychain save failed: %s", strings.TrimSpace(string(output)))
	}

	return nil
}

func (s *keychainSecretStore) Load() (string, error) {
	command := exec.Command("security", "find-generic-password", "-a", s.account, "-s", s.service, "-w")
	output, err := command.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("keychain load failed: %s", strings.TrimSpace(string(output)))
	}

	return strings.TrimSpace(string(output)), nil
}

func (s *keychainSecretStore) Delete() error {
	command := exec.Command("security", "delete-generic-password", "-a", s.account, "-s", s.service)
	output, err := command.CombinedOutput()
	if err != nil {
		trimmed := strings.TrimSpace(string(output))
		if strings.Contains(trimmed, "could not be found") {
			return nil
		}

		return fmt.Errorf("keychain delete failed: %s", trimmed)
	}

	return nil
}
