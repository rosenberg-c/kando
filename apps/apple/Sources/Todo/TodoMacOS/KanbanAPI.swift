import Foundation

struct KanbanBoard: Sendable, Equatable {
    let id: String
    let title: String
    let archivedOriginalTitle: String?

    init(id: String, title: String, archivedOriginalTitle: String? = nil) {
        self.id = id
        self.title = title
        self.archivedOriginalTitle = archivedOriginalTitle
    }
}

enum RestoreBoardTitleMode: String, Sendable, Equatable {
    case original
    case archived
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
    let isArchived: Bool
    let archivedAt: String?

    init(
        id: String,
        columnID: String,
        title: String,
        description: String,
        position: Int,
        isArchived: Bool = false,
        archivedAt: String? = nil
    ) {
        self.id = id
        self.columnID = columnID
        self.title = title
        self.description = description
        self.position = position
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }
}

struct ColumnTaskArchiveResult: Sendable, Equatable {
    let archivedTaskCount: Int
    let archivedAt: String
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

struct TaskExportPayload: Codable, Sendable, Equatable {
    static let currentFormatVersion = 2
    static let legacyFormatVersion = 1

    let formatVersion: Int
    let boardTitle: String
    let exportedAt: String
    let columns: [TaskExportColumn]

    var taskCount: Int {
        columns.reduce(0) { $0 + $1.tasks.count + $1.archivedTasks.count }
    }
}

struct TaskExportBundle: Codable, Sendable, Equatable {
    static let currentFormatVersion = 3
    static let legacyFormatVersion = 2

    let formatVersion: Int
    let exportedAt: String
    let boards: [TaskExportBundleBoard]

    var taskCount: Int {
        boards.reduce(0) { $0 + $1.payload.taskCount }
    }
}

struct TaskExportBundleBoard: Codable, Sendable, Equatable, Identifiable {
    let sourceBoardID: String
    let sourceBoardTitle: String
    let payload: TaskExportPayload

    var id: String { sourceBoardID }
}

struct TaskExportColumn: Codable, Sendable, Equatable {
    let title: String
    let tasks: [TaskExportTask]
    let archivedTasks: [TaskExportTask]

    init(title: String, tasks: [TaskExportTask], archivedTasks: [TaskExportTask] = []) {
        self.title = title
        self.tasks = tasks
        self.archivedTasks = archivedTasks
    }
}

struct TaskExportTask: Codable, Sendable, Equatable {
    let title: String
    let description: String
    let archivedAt: String?

    init(title: String, description: String, archivedAt: String? = nil) {
        self.title = title
        self.description = description
        self.archivedAt = archivedAt
    }
}

struct TaskImportResult: Sendable, Equatable {
    let createdColumnCount: Int
    let importedTaskCount: Int
}

struct TaskImportBundleResult: Sendable, Equatable {
    let totalCreatedColumnCount: Int
    let totalImportedTaskCount: Int
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
    func listBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard]
    func listArchivedBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard]
    func createBoard(title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard
    func updateBoard(boardID: String, title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard
    func deleteBoard(boardID: String, accessToken: String, baseURL: URL) async throws
    func archiveBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard
    func restoreBoard(boardID: String, titleMode: RestoreBoardTitleMode, accessToken: String, baseURL: URL) async throws -> KanbanBoard
    func deleteArchivedBoard(boardID: String, accessToken: String, baseURL: URL) async throws
    func getBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoardDetails
    func createColumn(boardID: String, title: String, accessToken: String, baseURL: URL) async throws
    func updateColumn(boardID: String, columnID: String, title: String, accessToken: String, baseURL: URL) async throws
    func reorderColumns(boardID: String, orderedColumnIDs: [String], accessToken: String, baseURL: URL) async throws
    func deleteColumn(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws
    func archiveColumnTasks(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws -> ColumnTaskArchiveResult
    func listArchivedTasksByBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> [KanbanTask]
    func restoreArchivedTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws -> KanbanTask
    func deleteArchivedTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws
    func createTask(boardID: String, columnID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws
    func updateTask(boardID: String, taskID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws
    func reorderTasks(boardID: String, orderedTasksByColumn: [KanbanTaskColumnOrder], accessToken: String, baseURL: URL) async throws
    func deleteTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws
    func exportTasksBundle(boardIDs: [String], accessToken: String, baseURL: URL) async throws -> TaskExportBundle
    func importTasksBundle(sourceBoardIDs: [String], bundle: TaskExportBundle, accessToken: String, baseURL: URL) async throws -> TaskImportBundleResult
}
