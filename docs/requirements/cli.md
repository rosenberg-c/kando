# CLI Session and Storage

### `CLI-001`

CLI API client rejects invalid base URLs.

### `CLI-002`

CLI API login parsing uses typed response fields for token extraction.

### `CLI-003`

Secure token storage keeps refresh tokens out of plaintext state files.

### `CLI-004`

Secure token storage load fails when secret store access fails.

### `CLI-005`

Secure token storage clear fails safely when keychain deletion fails (state file preserved).

### `CLI-006`

File token store persists and loads token state.

### `CLI-007`

File token store load on missing file returns `ErrTokenStateNotFound`.

### `CLI-008`

File token store clear removes persisted state file.

### `CLI-009`

CLI service login persists returned tokens.

### `CLI-010`

CLI service `me` refreshes on unauthorized and retries with new access token.

### `CLI-011`

CLI service logout clears persisted state.
