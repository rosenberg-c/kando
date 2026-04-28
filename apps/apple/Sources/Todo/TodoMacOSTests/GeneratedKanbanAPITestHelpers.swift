import Foundation
import HTTPTypes
import OpenAPIRuntime
import TodoAPIClient
@testable import TodoMacOS

func makeGeneratedKanbanAPI(transport: any ClientTransport) -> GeneratedKanbanAPI {
    GeneratedKanbanAPI(makeClient: { baseURL, _ in
        let configuration = Configuration(dateTranscoder: TestLenientISO8601DateTranscoder())
        return Client(serverURL: baseURL, configuration: configuration, transport: transport)
    })
}

private struct TestLenientISO8601DateTranscoder: DateTranscoder {
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

struct StubClientTransport: ClientTransport {
    let handler: @Sendable (HTTPRequest, HTTPBody?, URL, String) async throws -> (HTTPResponse, HTTPBody?)

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        try await handler(request, body, baseURL, operationID)
    }
}
