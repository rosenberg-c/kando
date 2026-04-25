import Foundation
@testable import TodoMacOS

actor SuspendedOperationGate {
    private var started = false
    private var resumed = false
    private var resumeContinuations: [CheckedContinuation<Void, Never>] = []

    func markStarted() {
        started = true
    }

    func hasStarted() -> Bool {
        started
    }

    func waitUntilResumed() async {
        if resumed {
            return
        }
        await withCheckedContinuation { continuation in
            resumeContinuations.append(continuation)
        }
    }

    func resume() {
        resumed = true
        let continuations = resumeContinuations
        resumeContinuations.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }
}

struct MockKanbanAPI: KanbanAPI {
    var listBoardsHandler: @Sendable (String, URL) async throws -> [KanbanBoard]
    var listArchivedBoardsHandler: @Sendable (String, URL) async throws -> [KanbanBoard]
    var createBoardHandler: @Sendable (String, String, URL) async throws -> KanbanBoard
    var updateBoardHandler: @Sendable (String, String, String, URL) async throws -> KanbanBoard
    var deleteBoardHandler: @Sendable (String, String, URL) async throws -> Void
    var archiveBoardHandler: @Sendable (String, String, URL) async throws -> KanbanBoard
    var restoreBoardHandler: @Sendable (String, String, URL) async throws -> KanbanBoard
    var deleteArchivedBoardHandler: @Sendable (String, String, URL) async throws -> Void
    var getBoardHandler: @Sendable (String, String, URL) async throws -> KanbanBoardDetails
    var createColumnHandler: @Sendable (String, String, String, URL) async throws -> Void
    var updateColumnHandler: @Sendable (String, String, String, String, URL) async throws -> Void
    var reorderColumnsHandler: @Sendable (String, [String], String, URL) async throws -> Void
    var deleteColumnHandler: @Sendable (String, String, String, URL) async throws -> Void
    var createTaskHandler: @Sendable (String, String, String, String, String, URL) async throws -> Void
    var updateTaskHandler: @Sendable (String, String, String, String, String, URL) async throws -> Void
    var reorderTasksHandler: @Sendable (String, [KanbanTaskColumnOrder], String, URL) async throws -> Void
    var deleteTaskHandler: @Sendable (String, String, String, URL) async throws -> Void
    var exportTasksHandler: @Sendable (String, String, URL) async throws -> TaskExportPayload
    var importTasksHandler: @Sendable (String, TaskExportPayload, String, URL) async throws -> TaskImportResult

    init(
        listBoardsHandler: @escaping @Sendable (String, URL) async throws -> [KanbanBoard] = { _, _ in
            [KanbanBoard(id: "board-1", title: "Main")]
        },
        listArchivedBoardsHandler: @escaping @Sendable (String, URL) async throws -> [KanbanBoard] = { _, _ in
            []
        },
        createBoardHandler: @escaping @Sendable (String, String, URL) async throws -> KanbanBoard = { title, _, _ in
            KanbanBoard(id: UUID().uuidString, title: title)
        },
        updateBoardHandler: @escaping @Sendable (String, String, String, URL) async throws -> KanbanBoard = { boardID, title, _, _ in
            KanbanBoard(id: boardID, title: title)
        },
        deleteBoardHandler: @escaping @Sendable (String, String, URL) async throws -> Void = { _, _, _ in },
        archiveBoardHandler: @escaping @Sendable (String, String, URL) async throws -> KanbanBoard = { boardID, _, _ in
            KanbanBoard(id: boardID, title: "Archived")
        },
        restoreBoardHandler: @escaping @Sendable (String, String, URL) async throws -> KanbanBoard = { boardID, _, _ in
            KanbanBoard(id: boardID, title: "Restored")
        },
        deleteArchivedBoardHandler: @escaping @Sendable (String, String, URL) async throws -> Void = { _, _, _ in },
        getBoardHandler: @escaping @Sendable (String, String, URL) async throws -> KanbanBoardDetails = { _, _, _ in
            KanbanBoardDetails(board: KanbanBoard(id: "board-1", title: "Main"), columns: [], tasks: [])
        },
        createColumnHandler: @escaping @Sendable (String, String, String, URL) async throws -> Void = { _, _, _, _ in },
        updateColumnHandler: @escaping @Sendable (String, String, String, String, URL) async throws -> Void = { _, _, _, _, _ in },
        reorderColumnsHandler: @escaping @Sendable (String, [String], String, URL) async throws -> Void = { _, _, _, _ in },
        deleteColumnHandler: @escaping @Sendable (String, String, String, URL) async throws -> Void = { _, _, _, _ in },
        createTaskHandler: @escaping @Sendable (String, String, String, String, String, URL) async throws -> Void = { _, _, _, _, _, _ in },
        updateTaskHandler: @escaping @Sendable (String, String, String, String, String, URL) async throws -> Void = { _, _, _, _, _, _ in },
        reorderTasksHandler: @escaping @Sendable (String, [KanbanTaskColumnOrder], String, URL) async throws -> Void = { _, _, _, _ in },
        deleteTaskHandler: @escaping @Sendable (String, String, String, URL) async throws -> Void = { _, _, _, _ in },
        exportTasksHandler: @escaping @Sendable (String, String, URL) async throws -> TaskExportPayload = { _, _, _ in
            TaskExportPayload(formatVersion: TaskExportPayload.currentFormatVersion, boardTitle: "Main", exportedAt: "2026-04-24T00:00:00Z", columns: [])
        },
        importTasksHandler: @escaping @Sendable (String, TaskExportPayload, String, URL) async throws -> TaskImportResult = { _, payload, _, _ in
            TaskImportResult(createdColumnCount: 0, importedTaskCount: payload.taskCount)
        }
    ) {
        self.listBoardsHandler = listBoardsHandler
        self.listArchivedBoardsHandler = listArchivedBoardsHandler
        self.createBoardHandler = createBoardHandler
        self.updateBoardHandler = updateBoardHandler
        self.deleteBoardHandler = deleteBoardHandler
        self.archiveBoardHandler = archiveBoardHandler
        self.restoreBoardHandler = restoreBoardHandler
        self.deleteArchivedBoardHandler = deleteArchivedBoardHandler
        self.getBoardHandler = getBoardHandler
        self.createColumnHandler = createColumnHandler
        self.updateColumnHandler = updateColumnHandler
        self.reorderColumnsHandler = reorderColumnsHandler
        self.deleteColumnHandler = deleteColumnHandler
        self.createTaskHandler = createTaskHandler
        self.updateTaskHandler = updateTaskHandler
        self.reorderTasksHandler = reorderTasksHandler
        self.deleteTaskHandler = deleteTaskHandler
        self.exportTasksHandler = exportTasksHandler
        self.importTasksHandler = importTasksHandler
    }

    func listBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard] {
        try await listBoardsHandler(accessToken, baseURL)
    }

    func listArchivedBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard] {
        try await listArchivedBoardsHandler(accessToken, baseURL)
    }

    func createBoard(title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        try await createBoardHandler(title, accessToken, baseURL)
    }

    func updateBoard(boardID: String, title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        try await updateBoardHandler(boardID, title, accessToken, baseURL)
    }

    func deleteBoard(boardID: String, accessToken: String, baseURL: URL) async throws {
        try await deleteBoardHandler(boardID, accessToken, baseURL)
    }

    func archiveBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        try await archiveBoardHandler(boardID, accessToken, baseURL)
    }

    func restoreBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        try await restoreBoardHandler(boardID, accessToken, baseURL)
    }

    func deleteArchivedBoard(boardID: String, accessToken: String, baseURL: URL) async throws {
        try await deleteArchivedBoardHandler(boardID, accessToken, baseURL)
    }

    func getBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoardDetails {
        try await getBoardHandler(boardID, accessToken, baseURL)
    }

    func createColumn(boardID: String, title: String, accessToken: String, baseURL: URL) async throws {
        try await createColumnHandler(boardID, title, accessToken, baseURL)
    }

    func updateColumn(boardID: String, columnID: String, title: String, accessToken: String, baseURL: URL) async throws {
        try await updateColumnHandler(boardID, columnID, title, accessToken, baseURL)
    }

    func reorderColumns(boardID: String, orderedColumnIDs: [String], accessToken: String, baseURL: URL) async throws {
        try await reorderColumnsHandler(boardID, orderedColumnIDs, accessToken, baseURL)
    }

    func deleteColumn(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws {
        try await deleteColumnHandler(boardID, columnID, accessToken, baseURL)
    }

    func createTask(boardID: String, columnID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        try await createTaskHandler(boardID, columnID, title, description, accessToken, baseURL)
    }

    func updateTask(boardID: String, taskID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        try await updateTaskHandler(boardID, taskID, title, description, accessToken, baseURL)
    }

    func reorderTasks(boardID: String, orderedTasksByColumn: [KanbanTaskColumnOrder], accessToken: String, baseURL: URL) async throws {
        try await reorderTasksHandler(boardID, orderedTasksByColumn, accessToken, baseURL)
    }

    func deleteTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws {
        try await deleteTaskHandler(boardID, taskID, accessToken, baseURL)
    }

    func exportTasks(boardID: String, accessToken: String, baseURL: URL) async throws -> TaskExportPayload {
        try await exportTasksHandler(boardID, accessToken, baseURL)
    }

    func importTasks(boardID: String, payload: TaskExportPayload, accessToken: String, baseURL: URL) async throws -> TaskImportResult {
        try await importTasksHandler(boardID, payload, accessToken, baseURL)
    }
}
