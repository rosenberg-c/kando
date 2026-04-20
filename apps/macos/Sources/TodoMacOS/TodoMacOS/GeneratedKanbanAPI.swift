import Foundation
import HTTPTypes
import OpenAPIRuntime
import TodoAPIClient

struct GeneratedKanbanAPI: KanbanAPI {
    func ensureBoard(accessToken: String, baseURL: URL, defaultTitle: String) async throws -> KanbanBoard {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let listOutput = try await client.listBoards()

        switch listOutput {
        case let .ok(ok):
            let boards = try ok.body.json ?? []
            if let board = boards.first {
                return mapBoard(board)
            }

            let payload = Components.Schemas.CreateBoardRequest(title: defaultTitle)
            let createOutput = try await client.createBoard(body: .json(payload))
            switch createOutput {
            case let .ok(created):
                return mapBoard(try created.body.json)
            case let .default(statusCode, payload):
                throw mapStatus(statusCode, operation: "createBoard", model: problem(from: payload.body))
            }

        case let .default(statusCode, payload):
            throw mapStatus(statusCode, operation: "listBoards", model: problem(from: payload.body))
        }
    }

    func getBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoardDetails {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.getBoard(path: .init(boardId: boardID))
        switch output {
        case let .ok(ok):
            let body = try ok.body.json
            return KanbanBoardDetails(
                board: mapBoard(body.board),
                columns: (body.columns ?? []).map(mapColumn).sorted { $0.position < $1.position },
                todos: (body.todos ?? []).map(mapTodo)
            )
        case let .default(statusCode, payload):
            throw mapStatus(statusCode, operation: "getBoard", model: problem(from: payload.body))
        }
    }

    func createColumn(boardID: String, title: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.CreateColumnRequest(title: title)
        let output = try await client.createColumn(path: .init(boardId: boardID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "createColumn", model: problem(from: payload.body))
        }
    }

    func updateColumn(boardID: String, columnID: String, title: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.UpdateColumnRequest(title: title)
        let output = try await client.updateColumn(path: .init(boardId: boardID, columnId: columnID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "updateColumn", model: problem(from: payload.body))
        }
    }

    func deleteColumn(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.deleteColumn(path: .init(boardId: boardID, columnId: columnID))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "deleteColumn", model: problem(from: payload.body))
        }
    }

    func createTodo(boardID: String, columnID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.CreateTodoRequest(columnId: columnID, description: description, title: title)
        let output = try await client.createTodo(path: .init(boardId: boardID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "createTodo", model: problem(from: payload.body))
        }
    }

    func updateTodo(boardID: String, todoID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.UpdateTodoRequest(description: description, title: title)
        let output = try await client.updateTodo(path: .init(boardId: boardID, todoId: todoID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "updateTodo", model: problem(from: payload.body))
        }
    }

    func deleteTodo(boardID: String, todoID: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.deleteTodo(path: .init(boardId: boardID, todoId: todoID))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "deleteTodo", model: problem(from: payload.body))
        }
    }

    private func authenticatedClient(baseURL: URL, accessToken: String) -> Client {
        TodoAPIClientFactory.makeClient(baseURL: baseURL, middlewares: [BearerAuthMiddleware(accessToken: accessToken)])
    }

    private func mapStatus(_ statusCode: Int, operation: String, model: Components.Schemas.ErrorModel?) -> Error {
        if statusCode == 401 || statusCode == 403 {
            return KanbanAPIError.unauthorized
        }

        return KanbanAPIError.unexpectedStatus(code: statusCode, operation: operation, title: model?.title, detail: model?.detail)
    }

    private func problem(from body: any Sendable) -> Components.Schemas.ErrorModel? {
        if let body = body as? Operations.ListBoards.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.CreateBoard.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.GetBoard.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.CreateColumn.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.UpdateColumn.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.DeleteColumn.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.CreateTodo.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.UpdateTodo.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.DeleteTodo.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        return nil
    }

    private func mapBoard(_ board: Components.Schemas.Board) -> KanbanBoard {
        KanbanBoard(id: board.id, title: board.title)
    }

    private func mapColumn(_ column: Components.Schemas.Column) -> KanbanColumn {
        KanbanColumn(id: column.id, title: column.title, position: Int(column.position))
    }

    private func mapTodo(_ todo: Components.Schemas.Todo) -> KanbanTodo {
        KanbanTodo(id: todo.id, columnID: todo.columnId, title: todo.title, description: todo.description, position: Int(todo.position))
    }
}

private struct BearerAuthMiddleware: ClientMiddleware {
    let accessToken: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(accessToken)"
        return try await next(request, body, baseURL)
    }
}
