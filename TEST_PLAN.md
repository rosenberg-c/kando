# Test Plan

## Goal

Close remaining requirement coverage gaps with a prioritized sequence of tests.

## Remaining Requirement Gaps

- `API-002`, `API-004`
- `AUTH-001`, `AUTH-002`, `AUTH-003`, `AUTH-004`
- `BOARD-003`, `BOARD-004`
- `COL-DEL-001`, `COL-DEL-002`, `COL-DEL-003`, `COL-DEL-004`
- `COL-RULE-003`
- `TODO-DEL-001`, `TODO-DEL-002`, `TODO-DEL-003`, `TODO-DEL-004`
- `UX-001`, `UX-002`, `UX-003`

## Phase 1: High Value / Low Effort

- Add `AUTH-001` server test for successful login token response.
- Add `COL-RULE-003` and `API-004` view-model tests asserting conflict/dev diagnostics are surfaced in UI state.
- Add `BOARD-003` view-model/UI-state test for disabled mutations while loading/unready.

## Phase 2: Core UX Safety

- Add XCUITests for delete confirmation flows:
  - `COL-DEL-*`
  - `TODO-DEL-*`
- Assertions per flow:
  - Dialog appears with expected title/content.
  - Cancel is a no-op.
  - Confirm executes delete action.

## Phase 3: Session Lifecycle

- Add `AuthSessionViewModel` tests for:
  - `AUTH-002`: restore existing session.
  - `AUTH-003`: refresh expired token.
  - `AUTH-004`: signed-out state when session is missing/invalid.

## Phase 4: Remaining Platform and Contract Checks

- `BOARD-004`: add board refresh action test in Board view model.
- `UX-001`: add lightweight UI assertion for top-leading workspace anchor.
- `UX-002`: add UI test for selectable/copyable diagnostics text behavior.
- `UX-003`: expected to be satisfied by delete-confirmation XCUITests from Phase 2.
- `API-002`: add CI guard/check ensuring generated client artifacts are up-to-date (or enforce via `verify-generate` in CI and map requirement accordingly).
