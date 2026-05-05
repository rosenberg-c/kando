//go:build !darwin

package cli

import "fmt"

func newSecretStore(_ string) (SecretStore, error) {
	return nil, fmt.Errorf("secret store is only supported on darwin")
}
