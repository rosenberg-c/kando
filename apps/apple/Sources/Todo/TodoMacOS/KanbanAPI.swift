import Foundation

struct KanbanBoard: Sendable, Equatable {
    let id: String
    let title: String
}

struct KanbanColumn: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let position: Int
}

struct KanbanTask: Sendable, Equatable, Identifiable {
    let id: String
    let columnID: String
    let title: String
    let description: String
    let position: Int
}

struct KanbanTaskColumnOrder: Sendable, Equatable {
    let columnID: String
    let taskIDs: [String]
}

struct KanbanBoardDetails: Sendable, Equatable {
    let board: KanbanBoard
    let columns: [KanbanColumn]
    let tasks: [KanbanTask]
}

enum KanbanAPIError: LocalizedError {
    case unauthorized
    case unexpectedStatus(code: Int, operation: String, title: String?, detail: String?)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return Strings.t("board.error.unauthorized")
        case let .unexpectedStatus(code, _, title, detail):
            if let title, !title.isEmpty {
                if let detail, !detail.isEmpty {
                    return Strings.f("board.error.http_detail", code, title, detail)
                }
                return Strings.f("board.error.http_title", code, title)
            }
            return Strings.f("board.error.http", code)
        case .invalidResponse:
            return Strings.t("board.error.invalid_response")
        }
    }

    var debugDescription: String {
        switch self {
        case .unauthorized:
            return "error=unauthorized"
        case let .unexpectedStatus(code, operation, title, detail):
            var parts = ["operation=\(operation)", "status=\(code)"]
            if let title, !title.isEmpty {
                parts.append("title=\(title)")
            }
            if let detail, !detail.isEmpty {
                parts.append("detail=\(detail)")
            }
            return parts.joined(separator: "\n")
        case .invalidResponse:
            return "error=invalid_response"
        }
    }
}

protocol KanbanAPI: Sendable {
    func ensureBoard(accessToken: String, baseURL: URL, defaultTitle: String) async throws -> KanbanBoard
    func getBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoardDetails
    func createColumn(boardID: String, title: String, accessToken: String, baseURL: URL) async throws
    func updateColumn(boardID: String, columnID: String, title: String, accessToken: String, baseURL: URL) async throws
    func reorderColumns(boardID: String, orderedColumnIDs: [String], accessToken: String, baseURL: URL) async throws
    func deleteColumn(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws
    func createTask(boardID: String, columnID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws
    func updateTask(boardID: String, taskID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws
    func reorderTasks(boardID: String, orderedTasksByColumn: [KanbanTaskColumnOrder], accessToken: String, baseURL: URL) async throws
    func deleteTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws
}
