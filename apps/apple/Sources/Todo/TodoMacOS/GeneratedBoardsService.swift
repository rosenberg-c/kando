import Foundation
import TodoAPIClient

struct GeneratedBoardsService {
    private let makeClient: GeneratedAuthenticatedClientFactory

    init(makeClient: @escaping GeneratedAuthenticatedClientFactory) {
        self.makeClient = makeClient
    }

    func listBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard] {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.listBoards()
        switch output {
        case let .ok(ok):
            return (try ok.body.json ?? []).map(GeneratedKanbanMapper.mapBoard)
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "listBoards", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func listArchivedBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard] {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.listArchivedBoards()
        switch output {
        case let .ok(ok):
            return (try ok.body.json ?? []).map(GeneratedKanbanMapper.mapBoard)
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "listArchivedBoards", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func createBoard(title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.CreateBoardRequest(title: title)
        let output = try await client.createBoard(body: .json(payload))
        switch output {
        case let .ok(ok):
            return GeneratedKanbanMapper.mapBoard(try ok.body.json)
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "createBoard", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func updateBoard(boardID: String, title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.UpdateBoardRequest(title: title)
        let output = try await client.updateBoard(path: .init(boardId: boardID), body: .json(payload))
        switch output {
        case let .ok(ok):
            return GeneratedKanbanMapper.mapBoard(try ok.body.json)
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "updateBoard", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func deleteBoard(boardID: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.deleteBoard(path: .init(boardId: boardID))
        if case let .default(statusCode, payload) = output {
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "deleteBoard", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func archiveBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.archiveBoard(path: .init(boardId: boardID))
        switch output {
        case let .ok(ok):
            return GeneratedKanbanMapper.mapBoard(try ok.body.json)
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "archiveBoard", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func restoreBoard(boardID: String, titleMode: RestoreBoardTitleMode, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.RestoreBoardRequest(titleMode: GeneratedKanbanMapper.mapRestoreTitleMode(titleMode))
        let output = try await client.restoreBoard(path: .init(boardId: boardID), body: .json(payload))
        switch output {
        case let .ok(ok):
            return GeneratedKanbanMapper.mapBoard(try ok.body.json)
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "restoreBoard", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func deleteArchivedBoard(boardID: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.deleteArchivedBoard(path: .init(boardId: boardID))
        if case let .default(statusCode, payload) = output {
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "deleteArchivedBoard", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func getBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoardDetails {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.getBoard(path: .init(boardId: boardID))
        switch output {
        case let .ok(ok):
            let body = try ok.body.json
            return KanbanBoardDetails(
                board: GeneratedKanbanMapper.mapBoard(body.board),
                columns: (body.columns ?? []).map(GeneratedKanbanMapper.mapColumn).sorted { $0.position < $1.position },
                tasks: (body.tasks ?? []).map(GeneratedKanbanMapper.mapTask)
            )
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "getBoard", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    private func authenticatedClient(baseURL: URL, accessToken: String) -> Client {
        makeClient(baseURL, accessToken)
    }
}
