import Foundation
import TodoAPIClient

struct GeneratedKanbanAPI: KanbanAPI {
    private let boardsService: GeneratedBoardsService
    private let columnsService: GeneratedColumnsService
    private let tasksService: GeneratedTasksService

    init(makeClient: @escaping GeneratedAuthenticatedClientFactory = { baseURL, accessToken in
        TodoAPIClientFactory.makeClient(baseURL: baseURL, middlewares: [BearerAuthMiddleware(accessToken: accessToken)])
    }) {
        boardsService = GeneratedBoardsService(makeClient: makeClient)
        columnsService = GeneratedColumnsService(makeClient: makeClient)
        tasksService = GeneratedTasksService(makeClient: makeClient)
    }

    func listBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard] {
        try await boardsService.listBoards(accessToken: accessToken, baseURL: baseURL)
    }

    func listArchivedBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard] {
        try await boardsService.listArchivedBoards(accessToken: accessToken, baseURL: baseURL)
    }

    func createBoard(title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        try await boardsService.createBoard(title: title, accessToken: accessToken, baseURL: baseURL)
    }

    func updateBoard(boardID: String, title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        try await boardsService.updateBoard(boardID: boardID, title: title, accessToken: accessToken, baseURL: baseURL)
    }

    func deleteBoard(boardID: String, accessToken: String, baseURL: URL) async throws {
        try await boardsService.deleteBoard(boardID: boardID, accessToken: accessToken, baseURL: baseURL)
    }

    func archiveBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        try await boardsService.archiveBoard(boardID: boardID, accessToken: accessToken, baseURL: baseURL)
    }

    func restoreBoard(boardID: String, titleMode: RestoreBoardTitleMode, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        try await boardsService.restoreBoard(boardID: boardID, titleMode: titleMode, accessToken: accessToken, baseURL: baseURL)
    }

    func deleteArchivedBoard(boardID: String, accessToken: String, baseURL: URL) async throws {
        try await boardsService.deleteArchivedBoard(boardID: boardID, accessToken: accessToken, baseURL: baseURL)
    }

    func getBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoardDetails {
        try await boardsService.getBoard(boardID: boardID, accessToken: accessToken, baseURL: baseURL)
    }

    func createColumn(boardID: String, title: String, accessToken: String, baseURL: URL) async throws {
        try await columnsService.createColumn(boardID: boardID, title: title, accessToken: accessToken, baseURL: baseURL)
    }

    func updateColumn(boardID: String, columnID: String, title: String, accessToken: String, baseURL: URL) async throws {
        try await columnsService.updateColumn(boardID: boardID, columnID: columnID, title: title, accessToken: accessToken, baseURL: baseURL)
    }

    func reorderColumns(boardID: String, orderedColumnIDs: [String], accessToken: String, baseURL: URL) async throws {
        try await columnsService.reorderColumns(boardID: boardID, orderedColumnIDs: orderedColumnIDs, accessToken: accessToken, baseURL: baseURL)
    }

    func deleteColumn(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws {
        try await columnsService.deleteColumn(boardID: boardID, columnID: columnID, accessToken: accessToken, baseURL: baseURL)
    }

    func archiveColumnTasks(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws -> ColumnTaskArchiveResult {
        try await tasksService.archiveColumnTasks(boardID: boardID, columnID: columnID, accessToken: accessToken, baseURL: baseURL)
    }

    func listArchivedTasksByBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> [KanbanTask] {
        try await tasksService.listArchivedTasksByBoard(boardID: boardID, accessToken: accessToken, baseURL: baseURL)
    }

    func restoreArchivedTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws -> KanbanTask {
        try await tasksService.restoreArchivedTask(boardID: boardID, taskID: taskID, accessToken: accessToken, baseURL: baseURL)
    }

    func deleteArchivedTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws {
        try await tasksService.deleteArchivedTask(boardID: boardID, taskID: taskID, accessToken: accessToken, baseURL: baseURL)
    }

    func createTask(boardID: String, columnID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        try await tasksService.createTask(boardID: boardID, columnID: columnID, title: title, description: description, accessToken: accessToken, baseURL: baseURL)
    }

    func updateTask(boardID: String, taskID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        try await tasksService.updateTask(boardID: boardID, taskID: taskID, title: title, description: description, accessToken: accessToken, baseURL: baseURL)
    }

    func deleteTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws {
        try await tasksService.deleteTask(boardID: boardID, taskID: taskID, accessToken: accessToken, baseURL: baseURL)
    }

    func reorderTasks(boardID: String, orderedTasksByColumn: [KanbanTaskColumnOrder], accessToken: String, baseURL: URL) async throws {
        try await tasksService.reorderTasks(boardID: boardID, orderedTasksByColumn: orderedTasksByColumn, accessToken: accessToken, baseURL: baseURL)
    }

    func applyTaskBatchMutation(boardID: String, request: TaskBatchMutationRequest, accessToken: String, baseURL: URL) async throws {
        try await tasksService.applyTaskBatchMutation(boardID: boardID, request: request, accessToken: accessToken, baseURL: baseURL)
    }

    func exportTasksBundle(boardIDs: [String], accessToken: String, baseURL: URL) async throws -> TaskExportBundle {
        try await tasksService.exportTasksBundle(boardIDs: boardIDs, accessToken: accessToken, baseURL: baseURL)
    }

    func importTasksBundle(sourceBoardIDs: [String], bundle: TaskExportBundle, accessToken: String, baseURL: URL) async throws -> TaskImportBundleResult {
        try await tasksService.importTasksBundle(sourceBoardIDs: sourceBoardIDs, bundle: bundle, accessToken: accessToken, baseURL: baseURL)
    }
}
