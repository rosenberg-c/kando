import Foundation
import HTTPTypes
import OpenAPIRuntime
import TodoAPIClient

typealias GeneratedAuthenticatedClientFactory = @Sendable (URL, String) -> Client

enum GeneratedKanbanErrorMapper {
    static func mapStatus(_ statusCode: Int, operation: String, model: Components.Schemas.ErrorModel?) -> Error {
        if statusCode == 401 || statusCode == 403 {
            return KanbanAPIError.unauthorized
        }

        return KanbanAPIError.unexpectedStatus(code: statusCode, operation: operation, title: model?.title, detail: model?.detail)
    }

    static func problem(from body: any Sendable) -> Components.Schemas.ErrorModel? {
        (body as? any ProblemJSONBodyReadable)?.problemModel
    }
}

enum GeneratedKanbanMapper {
    static func mapBoard(_ board: Components.Schemas.Board) -> KanbanBoard {
        KanbanBoard(id: board.id, title: board.title, archivedOriginalTitle: board.archivedOriginalTitle)
    }

    static func mapColumn(_ column: Components.Schemas.Column) -> KanbanColumn {
        KanbanColumn(id: column.id, title: column.title, position: Int(column.position))
    }

    static func mapTask(_ task: Components.Schemas.Task) -> KanbanTask {
        KanbanTask(id: task.id, columnID: task.columnId, title: task.title, description: task.description, position: Int(task.position))
    }

    static func mapRestoreTitleMode(_ mode: RestoreBoardTitleMode) -> Components.Schemas.RestoreBoardRequest.TitleModePayload {
        switch mode {
        case .original:
            return .original
        case .archived:
            return .archived
        }
    }

    static func mapTaskBatchMutationAction(_ action: TaskBatchAction) -> Components.Schemas.TaskBatchMutationRequest.ActionPayload {
        switch action {
        case .delete:
            return .delete
        }
    }

    static func mapTaskExportPayload(_ payload: Components.Schemas.TaskExportPayload) -> TaskExportPayload {
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

    static func mapTaskExportPayload(_ payload: TaskExportPayload) throws -> Components.Schemas.TaskExportPayload {
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

    static func parseExportedAt(_ value: String) throws -> Date {
        if let date = ExportDateFormatters.plain.date(from: value) {
            return date
        }

        if let date = ExportDateFormatters.fractional.date(from: value) {
            return date
        }

        throw KanbanAPIError.invalidResponse
    }

    static func mapTaskExportBundle(_ bundle: Components.Schemas.TaskExportBundle) throws -> TaskExportBundle {
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

    static func mapTaskExportBundle(_ bundle: TaskExportBundle) throws -> Components.Schemas.TaskExportBundle {
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

private protocol ProblemJSONBodyReadable: Sendable {
    var applicationProblemJson: Components.Schemas.ErrorModel { get throws }
}

private extension ProblemJSONBodyReadable {
    var problemModel: Components.Schemas.ErrorModel? {
        try? applicationProblemJson
    }
}

// Keep this list in sync with generated operations that expose
// `Output.Default.Body.applicationProblemJson`.
extension Operations.ListBoards.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.ListArchivedBoards.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.CreateBoard.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.UpdateBoard.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.DeleteBoard.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.ArchiveBoard.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.RestoreBoard.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.DeleteArchivedBoard.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.GetBoard.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.CreateColumn.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.UpdateColumn.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.DeleteColumn.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.ArchiveTasksInColumn.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.ListArchivedTasksByBoard.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.RestoreArchivedTask.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.DeleteArchivedTask.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.ReorderColumns.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.CreateTask.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.UpdateTask.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.DeleteTask.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.ReorderTasks.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.ApplyTaskBatchMutation.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.ExportTasksBundle.Output.Default.Body: ProblemJSONBodyReadable {}
extension Operations.ImportTasksBundle.Output.Default.Body: ProblemJSONBodyReadable {}

struct BearerAuthMiddleware: ClientMiddleware {
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
