import Foundation
import TodoAPIClient

struct GeneratedAuthAPI: AuthAPI {
    func login(email: String, password: String, baseURL: URL) async throws -> AuthLoginResult {
        let client = TodoAPIClientFactory.makeClient(baseURL: baseURL)
        let payload = Components.Schemas.AuthLoginRequest(email: email, password: password)
        let output = try await client.login(body: .json(payload))
        switch output {
        case let .ok(ok):
            return .success(mapTokens(try ok.body.json))
        case let .default(statusCode, _):
            return .failure(statusCode)
        }
    }

    func refreshTokens(refreshToken: String, baseURL: URL) async throws -> AuthSessionTokens? {
        let client = TodoAPIClientFactory.makeClient(baseURL: baseURL)
        let payload = Components.Schemas.AuthRefreshRequest(refreshToken: refreshToken)
        let output = try await client.refreshAuth(body: .json(payload))
        switch output {
        case let .ok(ok):
            return mapTokens(try ok.body.json)
        case .default:
            return nil
        }
    }

    func revokeSession(refreshToken: String, baseURL: URL) async throws -> Int? {
        let client = TodoAPIClientFactory.makeClient(baseURL: baseURL)
        let payload = Components.Schemas.AuthRefreshRequest(refreshToken: refreshToken)
        let output = try await client.logout(body: .json(payload))
        switch output {
        case .noContent:
            return nil
        case let .default(statusCode, _):
            return statusCode
        }
    }

    private func mapTokens(_ tokens: Components.Schemas.AuthTokens) -> AuthSessionTokens {
        AuthSessionTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            accessTokenExpiresAt: tokens.accessTokenExpiresAt
        )
    }
}
