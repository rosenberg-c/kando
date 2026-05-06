import Foundation
import TodoAPIClient

struct GeneratedColumnsService {
    private let makeClient: GeneratedAuthenticatedClientFactory

    init(makeClient: @escaping GeneratedAuthenticatedClientFactory) {
        self.makeClient = makeClient
    }

    func createColumn(boardID: String, title: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.CreateColumnRequest(title: title)
        let output = try await client.createColumn(path: .init(boardId: boardID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "createColumn", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func updateColumn(boardID: String, columnID: String, title: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.UpdateColumnRequest(title: title)
        let output = try await client.updateColumn(path: .init(boardId: boardID, columnId: columnID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "updateColumn", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func reorderColumns(boardID: String, orderedColumnIDs: [String], accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.ReorderColumnsRequest(columnIds: orderedColumnIDs)
        let output = try await client.reorderColumns(path: .init(boardId: boardID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "reorderColumns", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func deleteColumn(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.deleteColumn(path: .init(boardId: boardID, columnId: columnID))
        if case let .default(statusCode, payload) = output {
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "deleteColumn", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    private func authenticatedClient(baseURL: URL, accessToken: String) -> Client {
        makeClient(baseURL, accessToken)
    }
}
