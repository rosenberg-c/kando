# macOS OpenAPI Client

This package provides the macOS-facing generated API client.

## Why this package exists

- Keeps the macOS app client-side and backend-only for authentication boundaries.
- Generates API types and operations from OpenAPI using Swift OpenAPI Generator.
- Allows the Xcode macOS app target to depend on a local package.

## OpenAPI source

The OpenAPI contract is generated from backend code into `api/openapi.yaml`.

The package reads that same contract via a symlink at `Sources/TodoAPIClient/openapi.yaml`, so there is a single OpenAPI source file in the repo.

Before building this package:

```bash
make generate-backend
```

## Session model boundary

The app persists auth/session data using an app-owned `PersistedSession` model in
`Sources/Todo/TodoMacOS/SessionStore.swift`.

Generated OpenAPI types are mapped in `GeneratedAuthAPI` (`Sources/Todo/TodoMacOS/GeneratedAuthAPI.swift`).

`AuthSessionViewModel` depends on the app-owned `AuthAPI` boundary (`Sources/Todo/TodoMacOS/AuthAPI.swift`) and app-owned auth token model (`AuthSessionTokens`), keeping view-model and session storage logic decoupled from generated client schema details.

## Build/check

```bash
swift build --package-path apps/apple
make macos-run
make macos-test-unit
```

`make macos-run` builds the Xcode target and opens the app bundle.

`make macos-test-unit` runs only macOS unit tests via the shared `TodoMacOSUnit` scheme.

Run UI/end-to-end tests manually from Xcode using the `TodoMacOS` scheme.

## Signing notes

The Xcode project does not hardcode a team identifier, so it is portable across machines.

If Xcode prompts about signing, set your own team in the target Signing settings (or use "Sign to Run Locally").

## UI text

UI-facing strings are externalized in resource files:

```txt
Sources/Todo/TodoMacOS/Localizable.strings
```
