import Foundation

struct AuthSessionTokens: Sendable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
}

enum AuthLoginResult: Sendable {
    case success(AuthSessionTokens)
    case failure(Int)
}

protocol AuthAPI: Sendable {
    func login(email: String, password: String, baseURL: URL) async throws -> AuthLoginResult
    func refreshTokens(refreshToken: String, baseURL: URL) async throws -> AuthSessionTokens?
    func revokeSession(refreshToken: String, baseURL: URL) async throws -> Int?
}
