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
                tasks: (body.tasks ?? []).map(mapTask)
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

    func reorderColumns(boardID: String, orderedColumnIDs: [String], accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.ReorderColumnsRequest(columnIds: orderedColumnIDs)
        let output = try await client.reorderColumns(path: .init(boardId: boardID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "reorderColumns", model: problem(from: payload.body))
        }
    }

    func deleteColumn(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.deleteColumn(path: .init(boardId: boardID, columnId: columnID))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "deleteColumn", model: problem(from: payload.body))
        }
    }

    func createTask(boardID: String, columnID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.CreateTaskRequest(columnId: columnID, description: description, title: title)
        let output = try await client.createTask(path: .init(boardId: boardID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "createTask", model: problem(from: payload.body))
        }
    }

    func updateTask(boardID: String, taskID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.UpdateTaskRequest(description: description, title: title)
        let output = try await client.updateTask(path: .init(boardId: boardID, taskId: taskID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "updateTask", model: problem(from: payload.body))
        }
    }

    func deleteTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.deleteTask(path: .init(boardId: boardID, taskId: taskID))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "deleteTask", model: problem(from: payload.body))
        }
    }

    func reorderTasks(boardID: String, orderedTasksByColumn: [KanbanTaskColumnOrder], accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.ReorderTasksRequest(
            columns: orderedTasksByColumn.map {
                Components.Schemas.TaskColumnOrderRequest(columnId: $0.columnID, taskIds: $0.taskIDs)
            }
        )
        let output = try await client.reorderTasks(path: .init(boardId: boardID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "reorderTasks", model: problem(from: payload.body))
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
        if let body = body as? Operations.ReorderColumns.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.CreateTask.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.UpdateTask.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.DeleteTask.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.ReorderTasks.Output.Default.Body,
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

    private func mapTask(_ task: Components.Schemas.Task) -> KanbanTask {
        KanbanTask(id: task.id, columnID: task.columnId, title: task.title, description: task.description, position: Int(task.position))
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
