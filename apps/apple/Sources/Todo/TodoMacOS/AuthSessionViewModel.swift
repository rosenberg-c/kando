import Foundation

@MainActor
final class AuthSessionViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var signedInEmail = ""
    @Published var isSignedIn = false
    @Published var isSigningIn = false
    @Published var statusMessage = ""
    @Published var statusIsError = false
    @Published var canRetryRestore = false

    private var didRestoreSession = false
    private var currentSession: PersistedSession?
    private let sessionStore: any AuthSessionStoring
    private let authAPI: any AuthAPI
    private let now: () -> Date

    init(
        sessionStore: (any AuthSessionStoring)? = nil,
        now: @escaping () -> Date = Date.init,
        authAPI: (any AuthAPI)? = nil
    ) {
        self.sessionStore = sessionStore ?? AuthSessionViewModel.defaultSessionStore()
        self.now = now
        self.authAPI = authAPI ?? GeneratedAuthAPI()

        let env = ProcessInfo.processInfo.environment
        if Self.shouldUseUITestSignedInSession(environment: env) {
            applyUITestSignedInSession(email: env[AppEnvironmentKey.email] ?? "ui-test@example.com")
        }
    }

    func signIn(keepSignedIn: Bool) async {
        isSigningIn = true
        statusMessage = ""
        statusIsError = false
        canRetryRestore = false
        defer { isSigningIn = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = apiBaseURL() else {
            statusIsError = true
            statusMessage = Strings.t("signin.result.invalid_base_url")
            return
        }

        do {
            let outcome = try await authAPI.login(email: trimmedEmail, password: password, baseURL: baseURL)

            switch outcome {
            case let .success(tokens):
                signedInEmail = trimmedEmail
                isSignedIn = true
                let session = PersistedSession.fromSessionTokens(email: trimmedEmail, tokens)
                currentSession = session
                if keepSignedIn {
                    sessionStore.save(session)
                } else {
                    sessionStore.clear()
                }
                statusIsError = false
                statusMessage = Strings.t("signin.result.success")
                canRetryRestore = false
            case let .failure(statusCode):
                statusIsError = true
                statusMessage = Strings.f("signin.result.failure", statusCode)
            }
        } catch {
            statusIsError = true
            statusMessage = Strings.f("signin.result.network_error", error.localizedDescription)
        }
    }

    func restoreSessionIfNeeded() async {
        guard !didRestoreSession else {
            return
        }
        didRestoreSession = true

        guard let session = sessionStore.load() else {
            return
        }

        if session.accessTokenExpiresAt > now() {
            apply(session: session)
            return
        }

        guard let baseURL = apiBaseURL() else {
            sessionStore.clear()
            setSessionExpiredStatus()
            return
        }

        do {
            if let refreshed = try await refreshSession(session: session, baseURL: baseURL) {
                apply(session: refreshed)
                return
            }
        } catch {
            statusIsError = true
            statusMessage = Strings.f("session.restore.network_error", error.localizedDescription)
            canRetryRestore = true
        }
    }

    func retrySessionRestore() async {
        didRestoreSession = false
        await restoreSessionIfNeeded()
    }

    func currentAPIBaseURL() -> URL? {
        apiBaseURL()
    }

    func validAccessToken() async -> String? {
        guard let session = currentSession ?? sessionStore.load() else {
            return nil
        }

        if session.accessTokenExpiresAt > now().addingTimeInterval(30) {
            currentSession = session
            return session.accessToken
        }

        guard let baseURL = apiBaseURL() else {
            return nil
        }

        do {
            if let refreshed = try await refreshSession(session: session, baseURL: baseURL) {
                return refreshed.accessToken
            }
            return nil
        } catch {
            statusIsError = true
            statusMessage = Strings.f("session.restore.network_error", error.localizedDescription)
            canRetryRestore = true
            return nil
        }
    }

    func signOut() async {
        statusMessage = ""
        statusIsError = false

        let sessionToRevoke = currentSession ?? sessionStore.load()
        if let session = sessionToRevoke, let baseURL = apiBaseURL() {
            do {
                let statusCode = try await authAPI.revokeSession(refreshToken: session.refreshToken, baseURL: baseURL)
                if let statusCode {
                    statusIsError = true
                    statusMessage = Strings.f("signout.result.failure", statusCode)
                }
            } catch {
                statusIsError = true
                statusMessage = Strings.f("signout.result.network_error", error.localizedDescription)
            }
        }

        sessionStore.clear()
        currentSession = nil
        isSignedIn = false
        signedInEmail = ""
        password = ""
        canRetryRestore = false

        if !statusIsError {
            statusMessage = Strings.t("signout.result.success")
        }
    }

    func applyUITestSignedInSession(email: String) {
        let session = PersistedSession(
            email: email,
            accessToken: "uitest-access-token",
            refreshToken: "uitest-refresh-token",
            accessTokenExpiresAt: Date.distantFuture
        )
        currentSession = session
        self.email = email
        signedInEmail = email
        isSignedIn = true
        isSigningIn = false
        statusMessage = ""
        statusIsError = false
        canRetryRestore = false
    }

    private func apply(session: PersistedSession) {
        currentSession = session
        email = session.email
        signedInEmail = session.email
        isSignedIn = true
        canRetryRestore = false
    }

    private func apiBaseURL() -> URL? {
        URL(string: ProcessInfo.processInfo.environment["TODO_API_BASE_URL"] ?? "http://localhost:8080")
    }

    private func refreshSession(session: PersistedSession, baseURL: URL) async throws -> PersistedSession? {
        guard let tokens = try await authAPI.refreshTokens(refreshToken: session.refreshToken, baseURL: baseURL) else {
            sessionStore.clear()
            setSessionExpiredStatus()
            return nil
        }

        let refreshed = PersistedSession.fromSessionTokens(email: session.email, tokens)
        sessionStore.save(refreshed)
        currentSession = refreshed
        return refreshed
    }

    private static func defaultSessionStore() -> any AuthSessionStoring {
        let env = ProcessInfo.processInfo.environment
        if RuntimeFlags.shouldDisableKeychain(environment: env)
            || shouldUseUITestSignedInSession(environment: env) {
            return EphemeralSessionStore()
        }
        return KeychainSessionStore()
    }

    private static func shouldUseUITestSignedInSession(environment: [String: String]) -> Bool {
        environment[AppEnvironmentKey.uiTestMode] == "1"
            && environment[AppEnvironmentKey.signedIn] == "1"
    }
    private func setSessionExpiredStatus() {
        statusIsError = true
        statusMessage = Strings.t("session.restore.expired")
        canRetryRestore = false
    }

}

private extension PersistedSession {
    static func fromSessionTokens(email: String, _ tokens: AuthSessionTokens) -> Self {
        PersistedSession(
            email: email,
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            accessTokenExpiresAt: tokens.accessTokenExpiresAt
        )
    }
}
