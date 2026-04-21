# Test Matrix

This matrix maps requirement IDs from `docs/REQUIREMENTS.md` and `docs/requirements/*.md` to current automated coverage.

Status values:

- `Covered`: automated test exists and directly validates requirement behavior.
- `Partial`: related tests exist but do not fully validate the requirement end-to-end.
- `Gap`: no automated test currently mapped.

## Coverage Map

| Requirement ID | Coverage Type | Test References | Status | Notes |
| --- | --- | --- | --- | --- |
| `AUTH-001` | API + Swift unit | `internal/api/server/server_test.go` (`TestLoginReturnsTokensOnSuccess`), `apps/apple/Sources/Todo/TodoMacOSTests/TodoMacOSTests.swift` (`signOutRevokesAfterSignInWithoutKeepSignedIn`) | Covered | Successful email/password sign-in behavior is validated in backend and app flow. |
| `AUTH-002` | Swift unit | `apps/apple/Sources/Todo/TodoMacOSTests/TodoMacOSTests.swift` (`restoreSessionUsesPersistedValidToken`) | Covered | Persisted valid session restore path is validated. |
| `AUTH-003` | Swift unit | `apps/apple/Sources/Todo/TodoMacOSTests/TodoMacOSTests.swift` (`restoreSessionRefreshesWhenAccessTokenExpired`) | Covered | Expired access token refresh path is validated. |
| `AUTH-004` | Swift unit | `apps/apple/Sources/Todo/TodoMacOSTests/TodoMacOSTests.swift` (`restoreSessionSkipsWhenNoPersistedSession`) | Covered | Missing persisted session keeps app signed out. |
| `BOARD-001` | API integration | `internal/api/server/server_test.go` (`TestKanbanBoardColumnTodoCRUD`) | Covered | Board retrieval after auth and seeded data is validated. |
| `BOARD-002` | API integration | `internal/api/server/server_test.go` (`TestKanbanBoardColumnTodoCRUD`) | Covered | Response includes board + columns + tasks. |
| `BOARD-003` | Swift unit | `apps/apple/Sources/Todo/TodoMacOSTests/TodoMacOSTests.swift` (`mutationActionsEnabledOnlyWhenBoardReady`) | Covered | Mutation availability toggles based on board readiness/loading state. |
| `BOARD-004` | Swift unit/UI | - | Gap | Manual refresh action not currently under automated test. |
| `COL-001` | Repository/API | `internal/kanban/contracttest/repository_contract.go` (`ValidationAndConflict`), `internal/api/server/server_test.go` (`TestKanbanBoardColumnTodoCRUD`) | Covered | Non-empty title and create flow validated via contract/API tests. |
| `COL-002` | Repository | `internal/kanban/memory_repository_test.go` (`TestMemoryRepositoryCRUDAndReindex`) | Covered | Rename path validated in memory repo tests. |
| `COL-003` | Repository/API | `internal/kanban/memory_repository_test.go`, `internal/kanban/contracttest/repository_contract.go` (`CRUD`) | Covered | Delete path validated for valid state. |
| `COL-004` | Repository | `internal/kanban/memory_repository_test.go` (`TestMemoryRepositoryCRUDAndReindex`) | Covered | Reindex behavior checked after deletion. |
| `COL-DEL-001` | XCUITest | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift` (`testDeleteColumnConfirmationCancelAndConfirm`) | Covered | Column delete is gated by explicit confirmation in UI. |
| `COL-DEL-002` | XCUITest | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift` (`testDeleteColumnConfirmationCancelAndConfirm`) | Covered | Confirmation dialog title text is asserted before action. |
| `COL-DEL-003` | XCUITest | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift` (`testDeleteColumnConfirmationCancelAndConfirm`) | Covered | Cancel path keeps the column unchanged. |
| `COL-DEL-004` | XCUITest | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift` (`testDeleteColumnConfirmationCancelAndConfirm`) | Covered | Confirm path executes deletion and removes column from UI. |
| `COL-RULE-001` | Domain/API | `internal/kanban/service_test.go` (`TestServiceDeleteColumnWithTodosReturnsConflict`), `internal/api/server/server_test.go` (`TestKanbanDeleteColumnWithTodosReturnsConflict`) | Covered | Domain and HTTP conflict behavior for non-empty columns is validated. |
| `COL-RULE-002` | API integration | `internal/api/server/server_test.go` (`TestKanbanDeleteColumnWithTodosReturnsConflict`) | Covered | Explicit `409` asserted. |
| `COL-RULE-003` | Swift unit | `apps/apple/Sources/Todo/TodoMacOSTests/TodoMacOSTests.swift` (`deleteColumnConflictSurfacesStatusAndDebugDiagnostics`) | Covered | View model surfaces conflict status/error text for column-delete rule violations. |
| `TASK-001` | Repository/API | `internal/kanban/contracttest/repository_contract.go` (`CRUD`/`ValidationAndConflict`), `internal/api/server/server_test.go` (`TestKanbanBoardColumnTodoCRUD`) | Covered | Create and title validation are covered. |
| `TASK-002` | Repository | `internal/kanban/memory_repository_test.go` (`TestMemoryRepositoryCRUDAndReindex`) | Covered | Update task path validated. |
| `TASK-003` | Repository/API | `internal/kanban/memory_repository_test.go`, `internal/kanban/contracttest/repository_contract.go` (`CRUD`) | Covered | Delete path validated. |
| `TASK-004` | Repository | `internal/kanban/memory_repository_test.go` (`TestMemoryRepositoryCRUDAndReindex`) | Covered | Reindex behavior checked after deletion. |
| `TASK-DEL-001` | XCUITest | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift` (`testDeleteTodoConfirmationCancelAndConfirm`) | Covered | Task delete is gated by explicit confirmation in UI. |
| `TASK-DEL-002` | XCUITest | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift` (`testDeleteTodoConfirmationCancelAndConfirm`) | Covered | Confirmation dialog title text is asserted before action. |
| `TASK-DEL-003` | XCUITest | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift` (`testDeleteTodoConfirmationCancelAndConfirm`) | Covered | Cancel path keeps the task unchanged. |
| `TASK-DEL-004` | XCUITest | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift` (`testDeleteTodoConfirmationCancelAndConfirm`) | Covered | Confirm path executes deletion and removes the task from UI. |
| `API-001` | Repository/API contract | `internal/kanban/repository_contract_test.go`, `internal/api/server/server_test.go` | Covered | Shared service + API CRUD contract validates backend source-of-truth behavior. |
| `API-002` | Build-time generation | `make generate`, generated clients in repo | Partial | Enforced by workflow/convention; no dedicated failing test when client usage diverges. |
| `API-003` | API integration | `internal/api/server/server_test.go` (`TestKanbanRoutesRequireBearerToken`, `TestKanbanRouteReturnsForbiddenForOtherOwner`, `TestKanbanRouteReturnsNotFoundForMissingResources`, `TestKanbanValidationReturnsBadRequest`, `TestKanbanDeleteColumnWithTodosReturnsConflict`) | Covered | 401/403/404/400/409 mappings asserted. |
| `API-004` | Swift unit | `apps/apple/Sources/Todo/TodoMacOSTests/TodoMacOSTests.swift` (`deleteColumnConflictSurfacesStatusAndDebugDiagnostics`) | Covered | Operation/status/detail diagnostics are asserted through view-model debug output. |
| `APPWRITE-001` | Integration contract | `internal/kanban/repository_contract_appwrite_integration_test.go` | Covered | Same repository contract suite runs against Appwrite (opt-in). |
| `APPWRITE-002` | Integration contract | `internal/kanban/repository_contract_appwrite_integration_test.go` | Partial | Pagination code path exercised indirectly; no targeted pagination boundary test. |
| `APPWRITE-003` | Integration test harness | `internal/kanban/repository_contract_appwrite_integration_test.go`, `Makefile` (`test-appwrite-integration`) | Covered | Env-gated and opt-in behavior is explicit. |
| `APPWRITE-AUTH-001` | Appwrite client unit | `internal/appwrite/client_test.go` (`TestCreateEmailPasswordSession`) | Covered | Verifies endpoint path and project header. |
| `APPWRITE-AUTH-002` | Appwrite client unit | `internal/appwrite/client_test.go` (`TestCreateEmailPasswordSessionSendsAPIKeyHeader`) | Covered | Verifies API key header propagation. |
| `APPWRITE-AUTH-003` | Appwrite client unit | `internal/appwrite/client_test.go` (`TestCreateJWT`) | Covered | Verifies JWT creation uses current session header. |
| `APPWRITE-AUTH-004` | Appwrite client unit | `internal/appwrite/client_test.go` (`TestVerifyJWT`) | Covered | Verifies identity mapping and key header omission. |
| `APPWRITE-AUTH-005` | Appwrite client unit | `internal/appwrite/client_test.go` (`TestVerifyJWTUnauthorized`) | Covered | Unauthorized maps to `auth.ErrUnauthorized`. |
| `APPWRITE-AUTH-006` | Appwrite client unit | `internal/appwrite/client_test.go` (`TestDeleteSession`) | Covered | Verifies delete current-session call semantics. |
| `APPWRITE-AUTH-007` | Appwrite client unit | `internal/appwrite/client_test.go` (`TestSummarizeExternalBodyRedactsSensitiveTerms`) | Covered | Sensitive-term redaction is asserted. |
| `APPWRITE-AUTH-008` | Appwrite client unit | `internal/appwrite/client_test.go` (`TestSummarizeExternalBodyTruncates`) | Covered | Oversized body truncation is asserted. |
| `SEC-LOGIN-001` | API/security integration | `internal/api/server/server_test.go` (`TestLoginBlockedReturnsRetryAfter`) | Covered | Blocked login returns `429` and `Retry-After`. |
| `SEC-LOGIN-002` | Security unit | `internal/api/security/login_limiter_test.go` (`TestLoginRateLimiterBlocksAfterMaxFailures`) | Covered | Lockout threshold behavior is asserted. |
| `SEC-LOGIN-003` | Security unit | `internal/api/security/login_limiter_test.go` (`TestLoginRateLimiterEvictsWhenMaxEntriesReached`) | Covered | Entry eviction behavior is asserted. |
| `MW-AUTH-001` | Middleware unit | `internal/api/middleware/auth_test.go` (`TestAuthRejectsMissingBearerToken`) | Covered | Missing/invalid bearer rejection is asserted. |
| `MW-AUTH-002` | Middleware unit | `internal/api/middleware/auth_test.go` (`TestAuthPassesIdentityToContext`) | Covered | Identity propagation to context is asserted. |
| `MW-AUTH-003` | Middleware unit | `internal/api/middleware/auth_test.go` (`TestAuthRejectsUnauthorizedVerifierError`) | Covered | Unauthorized verifier error maps to `401`. |
| `MW-AUTH-004` | Middleware unit | `internal/api/middleware/auth_test.go` (`TestAuthRejectsVerifierErrors`) | Covered | Verifier operational errors reject request as `401`. |
| `MW-REQID-001` | Middleware unit | `internal/api/middleware/request_id_test.go` (`TestRequestIDPreservesIncomingHeader`) | Covered | Incoming request ID preserved in response and context. |
| `MW-REQID-002` | Middleware unit | `internal/api/middleware/request_id_test.go` (`TestRequestIDGeneratesWhenMissing`) | Covered | Missing request ID generation and propagation is asserted. |
| `PUBLIC-001` | API integration | `internal/api/server/server_test.go` (`TestHelloReturnsTextPlain`) | Covered | `/hello` returns `200` and `text/plain`. |
| `PUBLIC-002` | OpenAPI unit | `internal/api/server/server_test.go` (`TestOpenAPIDefinesHelloAsTextPlain`) | Covered | OpenAPI content type contract is asserted. |
| `PUBLIC-003` | OpenAPI unit | `internal/api/server/server_test.go` (`TestOpenAPIDefinesKanbanPaths`) | Covered | Kanban path/method presence is asserted. |
| `CLI-001` | CLI client unit | `internal/cli/api_client_test.go` (`TestNewHTTPAPIClientRejectsInvalidBaseURL`) | Covered | Invalid base URL is rejected. |
| `CLI-002` | CLI client unit | `internal/cli/api_client_test.go` (`TestHTTPAPIClientLoginUsesTypedResponseParsing`) | Covered | Typed login response parsing is asserted. |
| `CLI-003` | CLI storage unit | `internal/cli/secure_store_test.go` (`TestSecureTokenStoreKeepsRefreshTokenOutOfStateFile`) | Covered | Refresh token is kept out of plaintext state file. |
| `CLI-004` | CLI storage unit | `internal/cli/secure_store_test.go` (`TestSecureTokenStoreLoadFailsWhenSecretStoreFails`) | Covered | Secret-store failure is propagated on load. |
| `CLI-005` | CLI storage unit | `internal/cli/secure_store_test.go` (`TestSecureTokenStoreClearDeletesKeychainBeforeStateFile`) | Covered | Clear fails safely when secret-store deletion fails. |
| `CLI-006` | CLI storage unit | `internal/cli/store_test.go` (`TestFileTokenStoreSaveAndLoad`) | Covered | File store save/load roundtrip is asserted. |
| `CLI-007` | CLI storage unit | `internal/cli/store_test.go` (`TestFileTokenStoreLoadMissing`) | Covered | Missing file maps to `ErrTokenStateNotFound`. |
| `CLI-008` | CLI storage unit | `internal/cli/store_test.go` (`TestFileTokenStoreClear`) | Covered | Clear removes persisted file. |
| `CLI-009` | CLI service unit | `internal/cli/service_test.go` (`TestServiceLoginStoresTokens`) | Covered | Login persists tokens to store. |
| `CLI-010` | CLI service unit | `internal/cli/service_test.go` (`TestServiceMeRefreshesOnUnauthorizedAndRetries`) | Covered | Unauthorized `me` triggers refresh and retry. |
| `CLI-011` | CLI service unit | `internal/cli/service_test.go` (`TestServiceLogoutClearsState`) | Covered | Logout clears persisted state. |
| `TEST-UI-001` | UI smoke | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift` (`testExample`) | Covered | Baseline app-launch smoke test. |
| `TEST-UI-002` | UI perf smoke | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift` (`testLaunchPerformance`) | Covered | Launch performance metric baseline. |
| `TEST-UI-003` | UI launch artifact | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITestsLaunchTests.swift` (`testLaunch`) | Covered | Launch screenshot artifact baseline. |
| `UX-001` | Swift UI | - | Gap | Top-leading layout is implemented but not UI-tested. |
| `UX-002` | Swift UI | - | Gap | Selectable/copyable text behavior not UI-tested. |
| `UX-003` | XCUITest | `apps/apple/Sources/Todo/TodoMacOSUITests/TodoMacOSUITests.swift` (`testDeleteTodoConfirmationCancelAndConfirm`, `testDeleteColumnConfirmationCancelAndConfirm`) | Covered | Destructive actions require and honor confirmation flows. |

## Next Test Additions (Recommended)

- Add `apps/apple` UI tests for `COL-DEL-*` and `TASK-DEL-*` confirmation flows.
- Add Swift view-model tests for auth/session restore and refresh (`AUTH-002`, `AUTH-003`).
- Add targeted Appwrite pagination test fixture for page boundary behavior (`APPWRITE-002`).
- Add a small smoke test that verifies developer diagnostics rendering (`API-004`, `UX-002`).
