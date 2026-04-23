import Foundation

actor UITestKanbanAPI: KanbanAPI {
    private let board = KanbanBoard(id: "board-1", title: "UI Test Board")
    private var columns: [KanbanColumn] = [
        KanbanColumn(id: "column-work", title: "Work", position: 0),
        KanbanColumn(id: "column-empty", title: "Empty", position: 1)
    ]

    private var tasks: [KanbanTask]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let requestedTaskCount = Int(environment[AppEnvironmentKey.workTaskCount] ?? "") ?? 1
        let taskCount = max(1, requestedTaskCount)
        tasks = Self.makeInitialTasks(count: taskCount)
    }

    private static func makeInitialTasks(count: Int) -> [KanbanTask] {
        (0..<count).map { index in
            let position = index
            let id = "task-\(index + 1)"
            let title = index == 0 ? "Example task" : "Example task \(index + 1)"
            return KanbanTask(
                id: id,
                columnID: "column-work",
                title: title,
                description: "UI test item",
                position: position
            )
        }
    }

    func ensureBoard(accessToken: String, baseURL: URL, defaultTitle: String) async throws -> KanbanBoard {
        board
    }

    func getBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoardDetails {
        KanbanBoardDetails(board: board, columns: columns, tasks: tasks)
    }

    func createColumn(boardID: String, title: String, accessToken: String, baseURL: URL) async throws {
        let nextPosition = (columns.map(\.position).max() ?? -1) + 1
        columns.append(KanbanColumn(id: UUID().uuidString, title: title, position: nextPosition))
    }

    func updateColumn(boardID: String, columnID: String, title: String, accessToken: String, baseURL: URL) async throws {
        guard let index = columns.firstIndex(where: { $0.id == columnID }) else { return }
        columns[index] = KanbanColumn(id: columns[index].id, title: title, position: columns[index].position)
    }

    func reorderColumns(boardID: String, orderedColumnIDs: [String], accessToken: String, baseURL: URL) async throws {
        guard let reordered = reorderedColumns(columns, orderedIDs: orderedColumnIDs) else {
            throw KanbanAPIError.unexpectedStatus(code: 400, operation: "reorderColumns", title: "Bad Request", detail: "invalid column order")
        }
        columns = reordered
    }

    func deleteColumn(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws {
        if tasks.contains(where: { $0.columnID == columnID }) {
            throw KanbanAPIError.unexpectedStatus(
                code: 409,
                operation: "deleteColumn",
                title: "Conflict",
                detail: "column has tasks"
            )
        }
        columns.removeAll { $0.id == columnID }
        for (index, column) in columns.enumerated() {
            columns[index] = KanbanColumn(id: column.id, title: column.title, position: index)
        }
    }

    func createTask(boardID: String, columnID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        let nextPosition = (tasks.filter { $0.columnID == columnID }.map(\.position).max() ?? -1) + 1
        tasks.append(KanbanTask(id: UUID().uuidString, columnID: columnID, title: title, description: description, position: nextPosition))
    }

    func updateTask(boardID: String, taskID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        let current = tasks[index]
        tasks[index] = KanbanTask(id: current.id, columnID: current.columnID, title: title, description: description, position: current.position)
    }

    func reorderTasks(boardID: String, orderedTasksByColumn: [KanbanTaskColumnOrder], accessToken: String, baseURL: URL) async throws {
        let expectedColumns = Set(columns.map(\.id))
        let providedColumns = Set(orderedTasksByColumn.map(\.columnID))
        guard expectedColumns == providedColumns else {
            throw KanbanAPIError.unexpectedStatus(code: 400, operation: "reorderTasks", title: "Bad Request", detail: "invalid column list")
        }

        let expectedTaskIDs = Set(tasks.map(\.id))
        let providedTaskIDs = Set(orderedTasksByColumn.flatMap(\.taskIDs))
        guard expectedTaskIDs == providedTaskIDs else {
            throw KanbanAPIError.unexpectedStatus(code: 400, operation: "reorderTasks", title: "Bad Request", detail: "invalid task list")
        }

        var taskByID: [String: KanbanTask] = [:]
        for task in tasks {
            taskByID[task.id] = task
        }

        var reordered: [KanbanTask] = []
        for columnOrder in orderedTasksByColumn {
            for (position, taskID) in columnOrder.taskIDs.enumerated() {
                guard let task = taskByID[taskID] else {
                    throw KanbanAPIError.unexpectedStatus(code: 400, operation: "reorderTasks", title: "Bad Request", detail: "invalid task id")
                }
                reordered.append(
                    KanbanTask(
                        id: task.id,
                        columnID: columnOrder.columnID,
                        title: task.title,
                        description: task.description,
                        position: position
                    )
                )
            }
        }

        tasks = reordered
    }

    func deleteTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws {
        tasks.removeAll { $0.id == taskID }
    }
}
