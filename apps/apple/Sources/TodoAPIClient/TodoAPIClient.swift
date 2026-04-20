import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

private struct LenientISO8601DateTranscoder: DateTranscoder {
    private let plain: any DateTranscoder = .iso8601
    private let fractional: any DateTranscoder = .iso8601WithFractionalSeconds

    func encode(_ date: Date) throws -> String {
        try plain.encode(date)
    }

    func decode(_ dateString: String) throws -> Date {
        do {
            return try plain.decode(dateString)
        } catch {
            return try fractional.decode(dateString)
        }
    }
}

public enum TodoAPIClientFactory {
    public static func makeClient(baseURL: URL, middlewares: [any ClientMiddleware] = []) -> Client {
        let configuration = Configuration(dateTranscoder: LenientISO8601DateTranscoder())
        return Client(serverURL: baseURL, configuration: configuration, transport: URLSessionTransport(), middlewares: middlewares)
    }
}
