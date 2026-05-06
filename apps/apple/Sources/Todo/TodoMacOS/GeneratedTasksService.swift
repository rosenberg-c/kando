import Foundation
import TodoAPIClient

struct GeneratedTasksService {
    private let makeClient: GeneratedAuthenticatedClientFactory

    init(makeClient: @escaping GeneratedAuthenticatedClientFactory) {
        self.makeClient = makeClient
    }

    func archiveColumnTasks(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws -> ColumnTaskArchiveResult {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.archiveTasksInColumn(path: .init(boardId: boardID, columnId: columnID))
        switch output {
        case let .ok(ok):
            let response = try ok.body.json
            return ColumnTaskArchiveResult(
                archivedTaskCount: Int(response.archivedTaskCount),
                archivedAt: GeneratedTasksService.dateFormatter.string(from: response.archivedAt)
            )
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "archiveColumnTasks", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func listArchivedTasksByBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> [KanbanTask] {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.listArchivedTasksByBoard(path: .init(boardId: boardID))
        switch output {
        case let .ok(ok):
            guard let archivedTasks = try ok.body.json else {
                throw KanbanAPIError.invalidResponse
            }
            return archivedTasks.map {
                KanbanTask(
                    id: $0.id,
                    columnID: $0.columnId,
                    title: $0.title,
                    description: $0.description,
                    position: Int($0.position),
                    isArchived: true,
                    archivedAt: GeneratedTasksService.dateFormatter.string(from: $0.archivedAt)
                )
            }
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "listArchivedTasksByBoard", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func restoreArchivedTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws -> KanbanTask {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.restoreArchivedTask(path: .init(boardId: boardID, taskId: taskID))
        switch output {
        case let .ok(ok):
            return GeneratedKanbanMapper.mapTask(try ok.body.json)
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "restoreArchivedTask", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func deleteArchivedTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.deleteArchivedTask(path: .init(boardId: boardID, taskId: taskID))
        if case let .default(statusCode, payload) = output {
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "deleteArchivedTask", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func createTask(boardID: String, columnID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.CreateTaskRequest(columnId: columnID, description: description, title: title)
        let output = try await client.createTask(path: .init(boardId: boardID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "createTask", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func updateTask(boardID: String, taskID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.UpdateTaskRequest(description: description, title: title)
        let output = try await client.updateTask(path: .init(boardId: boardID, taskId: taskID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "updateTask", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func deleteTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let output = try await client.deleteTask(path: .init(boardId: boardID, taskId: taskID))
        if case let .default(statusCode, payload) = output {
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "deleteTask", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
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
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "reorderTasks", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func applyTaskBatchMutation(boardID: String, request: TaskBatchMutationRequest, accessToken: String, baseURL: URL) async throws {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.TaskBatchMutationRequest(
            action: GeneratedKanbanMapper.mapTaskBatchMutationAction(request.action),
            taskIds: request.taskIDs
        )
        let output = try await client.applyTaskBatchMutation(path: .init(boardId: boardID), body: .json(payload))
        if case let .default(statusCode, payload) = output {
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "applyTaskBatchMutation", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func exportTasksBundle(boardIDs: [String], accessToken: String, baseURL: URL) async throws -> TaskExportBundle {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.TaskExportBundleRequest(boardIds: boardIDs)
        let output = try await client.exportTasksBundle(body: .json(payload))
        switch output {
        case let .ok(ok):
            return try GeneratedKanbanMapper.mapTaskExportBundle(try ok.body.json)
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "exportTasksBundle", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    func importTasksBundle(sourceBoardIDs: [String], bundle: TaskExportBundle, accessToken: String, baseURL: URL) async throws -> TaskImportBundleResult {
        let client = authenticatedClient(baseURL: baseURL, accessToken: accessToken)
        let payload = Components.Schemas.TaskImportBundleRequest(
            bundle: try GeneratedKanbanMapper.mapTaskExportBundle(bundle),
            sourceBoardIds: sourceBoardIDs
        )
        let output = try await client.importTasksBundle(body: .json(payload))
        switch output {
        case let .ok(ok):
            let response = try ok.body.json
            return TaskImportBundleResult(
                totalCreatedColumnCount: Int(response.totalCreatedColumnCount),
                totalImportedTaskCount: Int(response.totalImportedTaskCount)
            )
        case let .default(statusCode, payload):
            throw GeneratedKanbanErrorMapper.mapStatus(statusCode, operation: "importTasksBundle", model: GeneratedKanbanErrorMapper.problem(from: payload.body))
        }
    }

    private func authenticatedClient(baseURL: URL, accessToken: String) -> Client {
        makeClient(baseURL, accessToken)
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()
}
