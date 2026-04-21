# Test Plan

## Goal

Close remaining requirement coverage gaps with a prioritized sequence of tests.

## Remaining Requirement Gaps

- `API-002`
- `BOARD-004`
- `UX-001`

## Phase 1: High Value / Low Effort

- Status: done
- Added `AUTH-001` server test for successful login token response.
- Added `COL-RULE-003` and `UX-004` view-model tests asserting conflict status/detail are surfaced for clear user feedback.
- Added `BOARD-003` view-model/UI-state test for disabled mutations while loading/unready.

## Phase 2: Core UX Safety

- Status: done
- Added XCUITests for delete confirmation flows:
  - `COL-DEL-*`
  - `TASK-DEL-*`
- Added assertions for each flow:
  - Dialog appears with expected title/content.
  - Cancel is a no-op.
  - Confirm executes delete action.

## Phase 3: Session Lifecycle

- Status: done
- Added `AuthSessionViewModel` tests for:
  - `AUTH-002`: restore existing session (`restoreSessionUsesPersistedValidToken`).
  - `AUTH-003`: refresh expired token (`restoreSessionRefreshesWhenAccessTokenExpired`).
  - `AUTH-004`: signed-out state when session is missing/invalid (`restoreSessionSkipsWhenNoPersistedSession`).

## Phase 4: Remaining Platform and Contract Checks

- Status: ready
- Scope: close the remaining `Gap`/`Partial` items in `docs/TEST_MATRIX.md` (`BOARD-004`, `UX-001`, `API-002`).

### Planned additions

- `BOARD-004` (`apps/apple/Sources/Todo/TodoMacOSTests/BoardViewModelTests.swift`)
  - Add a view-model test that calls `reloadBoard()` twice and asserts refreshed state reflects updated API data.
  - Suggested test name: `manualRefreshReloadsBoardStateFromAPI`.
- `UX-001` (`apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift`)
  - Add a lightweight UI assertion that workspace content anchors top-leading (using stable accessibility identifiers).
  - Suggested test name: `testWorkspaceAnchorsTopLeading`.
- `API-002` (`Makefile` + CI pipeline)
  - Reuse existing `verify-generate` target in CI so generated artifacts cannot drift.
  - Map CI check to requirement coverage in `docs/TEST_MATRIX.md` once enforced.

### Exit criteria

- New tests run green via `make test-macos-unit` and targeted XCUITest execution.
- CI (or equivalent required check) runs `make verify-generate` on pull requests.
- `docs/TEST_MATRIX.md` updates from `Gap/Partial` to `Covered` where criteria are met.
