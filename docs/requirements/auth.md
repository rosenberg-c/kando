# Authentication and Session

### `AUTH-001`

Users can sign in with email and password.

### `AUTH-002`

The app restores a valid session on launch when possible.

### `AUTH-003`

If the access token is expired and refresh is available, the app refreshes tokens.

### `AUTH-004`

If no valid session exists, the app shows the signed-out view.

### `AUTH-005`

Browser login and refresh responses return access-token fields only; refresh token is delivered via secure cookie and is not present in browser JSON token payloads.

### `AUTH-006`

Native clients use dedicated native auth endpoints for login, refresh, and logout with refresh token carried in request/response body fields.

### `AUTH-007`

If refresh-token issuance fails after provider session creation during login, the backend performs best-effort provider-session cleanup and still returns the original refresh-issuance failure.

## Platform Applicability

- `AUTH-001`: macOS (required), web (required), iOS (planned), TUI (planned).
- `AUTH-002`: macOS (required), web (required), iOS (planned), TUI (planned).
- `AUTH-003`: macOS (required), web (required), iOS (planned), TUI (planned).
- `AUTH-004`: macOS (required), web (required), iOS (planned), TUI (planned).
- `AUTH-005`: macOS (N/A), web (required), iOS (N/A), TUI (N/A).
- `AUTH-006`: macOS (required), web (N/A), iOS (planned), TUI (planned).
- `AUTH-007`: macOS (required), web (required), iOS (planned), TUI (planned).
