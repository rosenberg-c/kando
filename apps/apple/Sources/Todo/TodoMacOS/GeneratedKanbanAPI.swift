import Foundation
import HTTPTypes
import OpenAPIRuntime
import TodoAPIClient

struct GeneratedKanbanAPI: KanbanAPI {
    func listBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard] {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.listBoards()
        switch output {
        case let .ok(ok):
            return (try ok.body.json ?? []).map(mapBoard)
        case let .default(statusCode, payload):
            throw mapStatus(statusCode, operation: "listBoards", model: problem(from: payload.body))
        }
    }

    func listArchivedBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard] {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.listArchivedBoards()
        switch output {
        case let .ok(ok):
            return (try ok.body.json ?? []).map(mapBoard)
        case let .default(statusCode, payload):
            throw mapStatus(statusCode, operation: "listArchivedBoards", model: problem(from: payload.body))
        }
    }

    func createBoard(title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.CreateBoardRequest(title: title)
        let output = try await client.createBoard(body: .json(payload))
        switch output {
        case let .ok(ok):
            return mapBoard(try ok.body.json)
        case let .default(statusCode, payload):
            throw mapStatus(statusCode, operation: "createBoard", model: problem(from: payload.body))
        }
    }

    func updateBoard(boardID: String, title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.UpdateBoardRequest(title: title)
        let output = try await client.updateBoard(path: .init(boardId: boardID), body: .json(payload))
        switch output {
        case let .ok(ok):
            return mapBoard(try ok.body.json)
        case let .default(statusCode, payload):
            throw mapStatus(statusCode, operation: "updateBoard", model: problem(from: payload.body))
        }
    }

    func deleteBoard(boardID: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.deleteBoard(path: .init(boardId: boardID))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "deleteBoard", model: problem(from: payload.body))
        }
    }

    func archiveBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.archiveBoard(path: .init(boardId: boardID))
        switch output {
        case let .ok(ok):
            return mapBoard(try ok.body.json)
        case let .default(statusCode, payload):
            throw mapStatus(statusCode, operation: "archiveBoard", model: problem(from: payload.body))
        }
    }

    func restoreBoard(boardID: String, titleMode: RestoreBoardTitleMode, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.RestoreBoardRequest(titleMode: mapRestoreTitleMode(titleMode))
        let output = try await client.restoreBoard(path: .init(boardId: boardID), body: .json(payload))
        switch output {
        case let .ok(ok):
            return mapBoard(try ok.body.json)
        case let .default(statusCode, payload):
            throw mapStatus(statusCode, operation: "restoreBoard", model: problem(from: payload.body))
        }
    }

    func deleteArchivedBoard(boardID: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.deleteArchivedBoard(path: .init(boardId: boardID))
        if case let .default(statusCode, payload) = output {
            throw mapStatus(statusCode, operation: "deleteArchivedBoard", model: problem(from: payload.body))
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

    func archiveColumnTasks(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws -> ColumnTaskArchiveResult {
        let requestURL = baseURL
            .appendingPathComponent("boards")
            .appendingPathComponent(boardID)
            .appendingPathComponent("columns")
            .appendingPathComponent(columnID)
            .appendingPathComponent("archive-tasks")

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KanbanAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw mapJSONProblemStatus(httpResponse.statusCode, operation: "archiveColumnTasks", data: data)
        }

        let decoded = try JSONDecoder().decode(ArchiveColumnTasksDTO.self, from: data)
        return ColumnTaskArchiveResult(
            archivedTaskCount: decoded.archivedTaskCount,
            archivedAt: decoded.archivedAt
        )
    }

    func listArchivedTasksByBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> [KanbanTask] {
        let requestURL = baseURL
            .appendingPathComponent("boards")
            .appendingPathComponent(boardID)
            .appendingPathComponent("tasks")
            .appendingPathComponent("archived")

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KanbanAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw mapJSONProblemStatus(httpResponse.statusCode, operation: "listArchivedTasksByBoard", data: data)
        }

        let decoded = try JSONDecoder().decode([ArchivedTaskDTO].self, from: data)
        return decoded.map {
            KanbanTask(
                id: $0.id,
                columnID: $0.columnID,
                title: $0.title,
                description: $0.description,
                position: $0.position,
                isArchived: true,
                archivedAt: $0.archivedAt
            )
        }
    }

    func restoreArchivedTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws -> KanbanTask {
        let requestURL = baseURL
            .appendingPathComponent("boards")
            .appendingPathComponent(boardID)
            .appendingPathComponent("tasks")
            .appendingPathComponent(taskID)
            .appendingPathComponent("restore")

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KanbanAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw mapJSONProblemStatus(httpResponse.statusCode, operation: "restoreArchivedTask", data: data)
        }

        let task = try JSONDecoder().decode(TaskDTO.self, from: data)
        return KanbanTask(
            id: task.id,
            columnID: task.columnID,
            title: task.title,
            description: task.description,
            position: task.position
        )
    }

    func deleteArchivedTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws {
        let requestURL = baseURL
            .appendingPathComponent("boards")
            .appendingPathComponent(boardID)
            .appendingPathComponent("tasks")
            .appendingPathComponent(taskID)
            .appendingPathComponent("archived")

        var request = URLRequest(url: requestURL)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KanbanAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 204 else {
            throw mapJSONProblemStatus(httpResponse.statusCode, operation: "deleteArchivedTask", data: data)
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

    func exportTasksBundle(boardIDs: [String], accessToken: String, baseURL: URL) async throws -> TaskExportBundle {
        let requestURL = baseURL
            .appendingPathComponent("boards")
            .appendingPathComponent("tasks")
            .appendingPathComponent("export")

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["boardIds": boardIDs])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KanbanAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw mapJSONProblemStatus(httpResponse.statusCode, operation: "exportTasksBundle", data: data)
        }

        return try JSONDecoder().decode(TaskExportBundle.self, from: data)
    }

    func importTasksBundle(sourceBoardIDs: [String], bundle: TaskExportBundle, accessToken: String, baseURL: URL) async throws -> TaskImportBundleResult {
        let requestURL = baseURL
            .appendingPathComponent("boards")
            .appendingPathComponent("tasks")
            .appendingPathComponent("import")

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let importRequest = TaskImportBundleRequestDTO(sourceBoardIds: sourceBoardIDs, bundle: bundle)
        request.httpBody = try JSONEncoder().encode(importRequest)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KanbanAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw mapJSONProblemStatus(httpResponse.statusCode, operation: "importTasksBundle", data: data)
        }

        let decoded = try JSONDecoder().decode(TaskImportBundleResponseDTO.self, from: data)
        return TaskImportBundleResult(
            totalCreatedColumnCount: decoded.totalCreatedColumnCount,
            totalImportedTaskCount: decoded.totalImportedTaskCount
        )
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
        if let body = body as? Operations.ListArchivedBoards.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.CreateBoard.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.UpdateBoard.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.DeleteBoard.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.ArchiveBoard.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.RestoreBoard.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.DeleteArchivedBoard.Output.Default.Body,
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
        if let body = body as? Operations.ExportTasksBundle.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        if let body = body as? Operations.ImportTasksBundle.Output.Default.Body,
           case let .applicationProblemJson(model) = body {
            return model
        }
        return nil
    }

    private func mapTaskExportPayload(_ payload: Components.Schemas.TaskExportPayload) -> TaskExportPayload {
        TaskExportPayload(
            formatVersion: Int(payload.formatVersion),
            boardTitle: payload.boardTitle,
            exportedAt: ExportDateFormatters.plain.string(from: payload.exportedAt),
            columns: payload.columns.map {
                TaskExportColumn(
                    title: $0.title,
                    tasks: $0.tasks.map { task in
                        TaskExportTask(title: task.title, description: task.description)
                    }
                )
            }
        )
    }

    private func mapTaskExportPayload(_ payload: TaskExportPayload) throws -> Components.Schemas.TaskExportPayload {
        Components.Schemas.TaskExportPayload(
            boardTitle: payload.boardTitle,
            columns: payload.columns.map { column in
                Components.Schemas.TaskExportColumn(
                    tasks: column.tasks.map { task in
                        Components.Schemas.TaskExportTask(description: task.description, title: task.title)
                    },
                    title: column.title
                )
            },
            exportedAt: try parseExportedAt(payload.exportedAt),
            formatVersion: Int64(payload.formatVersion)
        )
    }

    private func parseExportedAt(_ value: String) throws -> Date {
        if let date = ExportDateFormatters.plain.date(from: value) {
            return date
        }

        if let date = ExportDateFormatters.fractional.date(from: value) {
            return date
        }

        throw KanbanAPIError.invalidResponse
    }

    private func mapTaskExportBundle(_ bundle: Components.Schemas.TaskExportBundle) throws -> TaskExportBundle {
        TaskExportBundle(
            formatVersion: Int(bundle.formatVersion),
            exportedAt: ExportDateFormatters.plain.string(from: bundle.exportedAt),
            boards: bundle.boards.map { snapshot in
                TaskExportBundleBoard(
                    sourceBoardID: snapshot.sourceBoardId,
                    sourceBoardTitle: snapshot.sourceBoardTitle,
                    payload: mapTaskExportPayload(snapshot.payload)
                )
            }
        )
    }

    private func mapTaskExportBundle(_ bundle: TaskExportBundle) throws -> Components.Schemas.TaskExportBundle {
        Components.Schemas.TaskExportBundle(
            boards: try bundle.boards.map { snapshot in
                Components.Schemas.TaskExportBundleBoard(
                    payload: try mapTaskExportPayload(snapshot.payload),
                    sourceBoardId: snapshot.sourceBoardID,
                    sourceBoardTitle: snapshot.sourceBoardTitle
                )
            },
            exportedAt: try parseExportedAt(bundle.exportedAt),
            formatVersion: Int64(bundle.formatVersion)
        )
    }

    private func mapBoard(_ board: Components.Schemas.Board) -> KanbanBoard {
        KanbanBoard(id: board.id, title: board.title, archivedOriginalTitle: board.archivedOriginalTitle)
    }

    private func mapRestoreTitleMode(_ mode: RestoreBoardTitleMode) -> Components.Schemas.RestoreBoardRequest.TitleModePayload {
        switch mode {
        case .original:
            return .original
        case .archived:
            return .archived
        }
    }

    private func mapColumn(_ column: Components.Schemas.Column) -> KanbanColumn {
        KanbanColumn(id: column.id, title: column.title, position: Int(column.position))
    }

    private func mapTask(_ task: Components.Schemas.Task) -> KanbanTask {
        KanbanTask(id: task.id, columnID: task.columnId, title: task.title, description: task.description, position: Int(task.position))
    }
}

private struct ArchiveColumnTasksDTO: Decodable {
    let archivedTaskCount: Int
    let archivedAt: String
}

private struct ArchivedTaskDTO: Decodable {
    let id: String
    let columnID: String
    let title: String
    let description: String
    let position: Int
    let archivedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case columnID = "columnId"
        case title
        case description
        case position
        case archivedAt
    }
}

private struct TaskDTO: Decodable {
    let id: String
    let columnID: String
    let title: String
    let description: String
    let position: Int

    enum CodingKeys: String, CodingKey {
        case id
        case columnID = "columnId"
        case title
        case description
        case position
    }
}

private struct TaskImportBundleResponseDTO: Decodable {
    let totalCreatedColumnCount: Int
    let totalImportedTaskCount: Int
}

private struct TaskImportBundleRequestDTO: Encodable {
    let sourceBoardIds: [String]
    let bundle: TaskExportBundle
}

private struct ProblemDTO: Decodable {
    let title: String?
    let detail: String?
}

private func mapJSONProblemStatus(_ statusCode: Int, operation: String, data: Data) -> Error {
    if statusCode == 401 || statusCode == 403 {
        return KanbanAPIError.unauthorized
    }

    let problem = try? JSONDecoder().decode(ProblemDTO.self, from: data)
    return KanbanAPIError.unexpectedStatus(
        code: statusCode,
        operation: operation,
        title: problem?.title,
        detail: problem?.detail
    )
}

private enum ExportDateFormatters {
    static let plain: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
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
