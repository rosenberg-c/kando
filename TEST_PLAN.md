# Test Plan

## Goal

Close remaining requirement coverage gaps with a prioritized sequence of tests.

## Remaining Requirement Gaps

- `API-002`

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

- Status: in progress
- Added `BOARD-004` view-model refresh coverage with `manualRefreshReloadsBoardStateFromAPI`.
- Added `UX-001` XCUITest anchor assertion with `testWorkspaceAnchorsTopLeading`.
- Added CI workflow `.github/workflows/verify-generate.yml`; currently manual-only (`workflow_dispatch`) for `API-002`.
