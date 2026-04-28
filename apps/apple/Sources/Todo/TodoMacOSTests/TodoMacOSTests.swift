import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@testable import TodoMacOS

@MainActor
struct TodoMacOSTests {
    @Test func restoreSessionSkipsWhenNoPersistedSession() async {
        // Requirement: AUTH-004
        let store = InMemorySessionStore()
        let viewModel = AuthSessionViewModel(sessionStore: store, now: { fixedNow })

        await viewModel.restoreSessionIfNeeded()

        #expect(viewModel.isSignedIn == false)
        #expect(viewModel.signedInEmail.isEmpty)
        #expect(store.clearCallCount == 0)
    }

    @Test func restoreSessionUsesPersistedValidToken() async {
        // Requirement: AUTH-002
        let session = PersistedSession(
            email: "alice@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-token",
            accessTokenExpiresAt: fixedNow.addingTimeInterval(3600)
        )
        let store = InMemorySessionStore(session: session)
        let viewModel = AuthSessionViewModel(sessionStore: store, now: { fixedNow })

        await viewModel.restoreSessionIfNeeded()

        #expect(viewModel.isSignedIn)
        #expect(viewModel.signedInEmail == "alice@example.com")
        #expect(store.clearCallCount == 0)
    }

    @Test func restoreSessionRefreshesWhenAccessTokenExpired() async {
        // Requirement: AUTH-003
        let expired = PersistedSession(
            email: "alice@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-old",
            accessTokenExpiresAt: fixedNow.addingTimeInterval(-10)
        )
        let store = InMemorySessionStore(session: expired)
        let refreshedTokens = token(expiry: fixedNow.addingTimeInterval(7200), refreshToken: "refresh-new")
        let authAPI = MockAuthAPI(refreshHandler: { refreshToken, _ in
            #expect(refreshToken == "refresh-old")
            return refreshedTokens
        })
        let viewModel = AuthSessionViewModel(sessionStore: store, now: { fixedNow }, authAPI: authAPI)

        await viewModel.restoreSessionIfNeeded()

        #expect(viewModel.isSignedIn)
        #expect(viewModel.signedInEmail == "alice@example.com")
        #expect(store.savedSessions.last?.refreshToken == "refresh-new")
        #expect(store.clearCallCount == 0)
    }

    @Test func restoreSessionClearsAndSetsExpiredStatusWhenRefreshFails() async {
        // Requirement: UX-002
        let expired = PersistedSession(
            email: "alice@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-token",
            accessTokenExpiresAt: fixedNow.addingTimeInterval(-10)
        )
        let store = InMemorySessionStore(session: expired)
        let authAPI = MockAuthAPI(refreshHandler: { _, _ in nil })
        let viewModel = AuthSessionViewModel(sessionStore: store, now: { fixedNow }, authAPI: authAPI)

        await viewModel.restoreSessionIfNeeded()

        #expect(viewModel.isSignedIn == false)
        #expect(viewModel.statusIsError)
        #expect(viewModel.statusMessage == Strings.t("session.restore.expired"))
        #expect(store.clearCallCount == 1)
    }

    @Test func restoreSessionKeepsSessionWhenRefreshHasNetworkError() async {
        struct ExpectedError: Error {}

        let expired = PersistedSession(
            email: "alice@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-token",
            accessTokenExpiresAt: fixedNow.addingTimeInterval(-10)
        )
        let store = InMemorySessionStore(session: expired)
        let authAPI = MockAuthAPI(refreshHandler: { _, _ in throw ExpectedError() })
        let viewModel = AuthSessionViewModel(sessionStore: store, now: { fixedNow }, authAPI: authAPI)

        await viewModel.restoreSessionIfNeeded()

        #expect(viewModel.isSignedIn == false)
        #expect(viewModel.statusIsError)
        #expect(viewModel.statusMessage.contains("Could not refresh session"))
        #expect(store.clearCallCount == 0)
        #expect(store.load()?.email == "alice@example.com")
    }

    @Test func signOutRevokesSessionWithRefreshToken() async {
        let existing = PersistedSession(
            email: "alice@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-token-123",
            accessTokenExpiresAt: fixedNow.addingTimeInterval(3600)
        )
        let store = InMemorySessionStore(session: existing)
        let revokeTracker = RevokeTracker()
        let authAPI = MockAuthAPI(revokeHandler: { refreshToken, _ in
            await revokeTracker.record(refreshToken: refreshToken)
            return nil
        })
        let viewModel = AuthSessionViewModel(sessionStore: store, now: { fixedNow }, authAPI: authAPI)

        await viewModel.signOut()

        let revokeCallCount = await revokeTracker.callCount()
        let revokedRefreshToken = await revokeTracker.lastRefreshToken()

        #expect(revokeCallCount == 1)
        #expect(revokedRefreshToken == "refresh-token-123")
        #expect(store.clearCallCount == 1)
        #expect(store.hasSession == false)
    }

    @Test func signOutRevokesAfterSignInWithoutKeepSignedIn() async {
        // Requirement: AUTH-001
        let store = InMemorySessionStore()
        let revokeTracker = RevokeTracker()
        let authAPI = MockAuthAPI(
            loginHandler: { _, _, _ in
                .success(token(expiry: fixedNow.addingTimeInterval(3600), refreshToken: "refresh-from-login"))
            },
            revokeHandler: { refreshToken, _ in
                await revokeTracker.record(refreshToken: refreshToken)
                return nil
            }
        )
        let viewModel = AuthSessionViewModel(sessionStore: store, now: { fixedNow }, authAPI: authAPI)

        viewModel.email = "alice@example.com"
        viewModel.password = "secret"
        await viewModel.signIn(keepSignedIn: false)
        await viewModel.signOut()

        let revokeCallCount = await revokeTracker.callCount()
        let revokedRefreshToken = await revokeTracker.lastRefreshToken()

        #expect(viewModel.isSignedIn == false)
        #expect(store.hasSession == false)
        #expect(revokeCallCount == 1)
        #expect(revokedRefreshToken == "refresh-from-login")
    }

    @Test func retryButtonEnabledAfterRestoreNetworkErrorAndRetrySucceeds() async {
        struct ExpectedError: Error {}

        let expired = PersistedSession(
            email: "alice@example.com",
            accessToken: "access-token",
            refreshToken: "refresh-token",
            accessTokenExpiresAt: fixedNow.addingTimeInterval(-10)
        )
        let store = InMemorySessionStore(session: expired)
        let refreshTracker = RefreshTracker()
        let authAPI = MockAuthAPI(refreshHandler: { _, _ in
            let refreshCallCount = await refreshTracker.incrementAndReturn()
            if refreshCallCount == 1 {
                throw ExpectedError()
            }
            return token(expiry: fixedNow.addingTimeInterval(3600))
        })
        let viewModel = AuthSessionViewModel(sessionStore: store, now: { fixedNow }, authAPI: authAPI)

        await viewModel.restoreSessionIfNeeded()
        #expect(viewModel.canRetryRestore)

        await viewModel.retrySessionRestore()
        #expect(viewModel.canRetryRestore == false)
        #expect(viewModel.isSignedIn)
    }

    @Test func taskExportBundleBoardDecodesSourceBoardIdFromServerPayload() throws {
        let json = """
        {
          "sourceBoardId": "c8bb0279-aa18-4055-b88f-2f73455efeb3",
          "sourceBoardTitle": "Main",
          "payload": {
            "formatVersion": 2,
            "boardTitle": "Main",
            "exportedAt": "2026-04-28T10:00:00Z",
            "columns": []
          }
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(TaskExportBundleBoard.self, from: json)

        #expect(snapshot.sourceBoardID == "c8bb0279-aa18-4055-b88f-2f73455efeb3")
    }

    @Test func taskExportBundleBoardDecodesLegacySourceBoardIDKey() throws {
        let json = """
        {
          "sourceBoardID": "c8bb0279-aa18-4055-b88f-2f73455efeb3",
          "sourceBoardTitle": "Main",
          "payload": {
            "formatVersion": 2,
            "boardTitle": "Main",
            "exportedAt": "2026-04-28T10:00:00Z",
            "columns": []
          }
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(TaskExportBundleBoard.self, from: json)

        #expect(snapshot.sourceBoardID == "c8bb0279-aa18-4055-b88f-2f73455efeb3")
    }

    @Test func applyTaskBatchMutationEncodesGeneratedContractShape() async throws {
        let transport = StubClientTransport { request, body, _, operationID in
            #expect(operationID == "applyTaskBatchMutation")
            #expect(request.method == .post)
            #expect(request.path == "/boards/board-1/tasks/actions")

            let requestBody = try #require(body)
            let payloadData = try await Data(collecting: requestBody, upTo: 8_192)
            let payloadObject = try #require(JSONSerialization.jsonObject(with: payloadData) as? [String: Any])
            #expect(payloadObject["action"] as? String == "delete")
            #expect(payloadObject["taskIds"] as? [String] == ["task-1", "task-2"])

            let response = HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"])
            return (response, HTTPBody(Data("[]".utf8)))
        }
        let api = makeGeneratedKanbanAPI(transport: transport)

        try await api.applyTaskBatchMutation(
            boardID: "board-1",
            request: TaskBatchMutationRequest(action: .delete, taskIDs: ["task-1", "task-2"]),
            accessToken: "token",
            baseURL: URL(string: "https://example.com")!
        )
    }

    @Test func listArchivedTasksByBoardHandlesEmptyGeneratedPayload() async throws {
        let transport = StubClientTransport { _, _, _, operationID in
            #expect(operationID == "listArchivedTasksByBoard")
            let response = HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"])
            return (response, HTTPBody(Data("[]".utf8)))
        }
        let api = makeGeneratedKanbanAPI(transport: transport)

        let tasks = try await api.listArchivedTasksByBoard(
            boardID: "board-1",
            accessToken: "token",
            baseURL: URL(string: "https://example.com")!
        )

        #expect(tasks.isEmpty)
    }

    @Test func listArchivedTasksByBoardMapsGeneratedArchivedTaskFields() async throws {
        let responseJSON = """
        [
          {
            "id": "task-1",
            "boardId": "board-1",
            "columnId": "column-a",
            "title": "Archived",
            "description": "done",
            "position": 7,
            "createdAt": "2026-04-28T09:00:00Z",
            "updatedAt": "2026-04-28T09:30:00Z",
            "archivedAt": "2026-04-28T10:00:00Z"
          }
        ]
        """
        let transport = StubClientTransport { _, _, _, operationID in
            #expect(operationID == "listArchivedTasksByBoard")
            let response = HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"])
            return (response, HTTPBody(Data(responseJSON.utf8)))
        }
        let api = makeGeneratedKanbanAPI(transport: transport)

        let tasks = try await api.listArchivedTasksByBoard(
            boardID: "board-1",
            accessToken: "token",
            baseURL: URL(string: "https://example.com")!
        )

        #expect(tasks.count == 1)
        #expect(tasks.first?.id == "task-1")
        #expect(tasks.first?.columnID == "column-a")
        #expect(tasks.first?.title == "Archived")
        #expect(tasks.first?.description == "done")
        #expect(tasks.first?.position == 7)
        #expect(tasks.first?.isArchived == true)
    }

    @Test func restoreArchivedTaskMapsProblemDetailsFromDefaultResponse() async {
        let problemJSON = """
        {
          "title": "Conflict",
          "detail": "task cannot be restored"
        }
        """
        let transport = StubClientTransport { request, _, _, operationID in
            #expect(operationID == "restoreArchivedTask")
            #expect(request.method == .post)
            #expect(request.path == "/boards/board-1/tasks/task-1/restore")
            let response = HTTPResponse(status: .init(code: 409), headerFields: [.contentType: "application/problem+json"])
            return (response, HTTPBody(Data(problemJSON.utf8)))
        }
        let api = makeGeneratedKanbanAPI(transport: transport)

        do {
            _ = try await api.restoreArchivedTask(
                boardID: "board-1",
                taskID: "task-1",
                accessToken: "token",
                baseURL: URL(string: "https://example.com")!
            )
            Issue.record("Expected restoreArchivedTask to throw")
        } catch let KanbanAPIError.unexpectedStatus(code, operation, title, detail) {
            #expect(code == 409)
            #expect(operation == "restoreArchivedTask")
            #expect(title == "Conflict")
            #expect(detail == "task cannot be restored")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

}

private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

private func token(expiry: Date, refreshToken: String = "refresh-token") -> AuthSessionTokens {
    AuthSessionTokens(
        accessToken: "access-token",
        refreshToken: refreshToken,
        accessTokenExpiresAt: expiry
    )
}

private final class InMemorySessionStore: AuthSessionStoring {
    var session: PersistedSession?
    var savedSessions: [PersistedSession] = []
    var clearCallCount = 0
    var hasSession: Bool { session != nil }

    init(session: PersistedSession? = nil) {
        self.session = session
    }

    func save(_ session: PersistedSession) {
        self.session = session
        savedSessions.append(session)
    }

    func load() -> PersistedSession? {
        session
    }

    func clear() {
        clearCallCount += 1
        session = nil
    }
}

private struct MockAuthAPI: AuthAPI {
    var loginHandler: @Sendable (String, String, URL) async throws -> AuthLoginResult
    var refreshHandler: @Sendable (String, URL) async throws -> AuthSessionTokens?
    var revokeHandler: @Sendable (String, URL) async throws -> Int?

    init(
        loginHandler: @escaping @Sendable (String, String, URL) async throws -> AuthLoginResult = { _, _, _ in .failure(500) },
        refreshHandler: @escaping @Sendable (String, URL) async throws -> AuthSessionTokens? = { _, _ in nil },
        revokeHandler: @escaping @Sendable (String, URL) async throws -> Int? = { _, _ in nil }
    ) {
        self.loginHandler = loginHandler
        self.refreshHandler = refreshHandler
        self.revokeHandler = revokeHandler
    }

    func login(email: String, password: String, baseURL: URL) async throws -> AuthLoginResult {
        try await loginHandler(email, password, baseURL)
    }

    func refreshTokens(refreshToken: String, baseURL: URL) async throws -> AuthSessionTokens? {
        try await refreshHandler(refreshToken, baseURL)
    }

    func revokeSession(refreshToken: String, baseURL: URL) async throws -> Int? {
        try await revokeHandler(refreshToken, baseURL)
    }
}

private actor RevokeTracker {
    private var count = 0
    private var token = ""

    func record(refreshToken: String) {
        count += 1
        token = refreshToken
    }

    func callCount() -> Int {
        count
    }

    func lastRefreshToken() -> String {
        token
    }
}

private actor RefreshTracker {
    private var count = 0

    func incrementAndReturn() -> Int {
        count += 1
        return count
    }
}
