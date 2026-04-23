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

    func moveTask(boardID: String, taskID: String, destinationColumnID: String, destinationPosition: Int, accessToken: String, baseURL: URL) async throws {
        guard destinationPosition >= 0 else {
            throw KanbanAPIError.unexpectedStatus(code: 400, operation: "moveTask", title: "Bad Request", detail: "invalid destination position")
        }
        guard columns.contains(where: { $0.id == destinationColumnID }) else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "moveTask", title: "Not Found", detail: "destination column not found")
        }
        guard let movingIndex = tasks.firstIndex(where: { $0.id == taskID }) else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "moveTask", title: "Not Found", detail: "task not found")
        }

        let movingTask = tasks[movingIndex]
        var sourceTasks = tasks.filter { $0.columnID == movingTask.columnID && $0.id != movingTask.id }
        sourceTasks.sort { $0.position < $1.position }

        if movingTask.columnID == destinationColumnID {
            guard destinationPosition <= sourceTasks.count else {
                throw KanbanAPIError.unexpectedStatus(code: 400, operation: "moveTask", title: "Bad Request", detail: "invalid destination position")
            }
            sourceTasks.insert(
                KanbanTask(id: movingTask.id, columnID: destinationColumnID, title: movingTask.title, description: movingTask.description, position: destinationPosition),
                at: destinationPosition
            )
            for (index, task) in sourceTasks.enumerated() {
                if let fullIndex = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[fullIndex] = KanbanTask(id: task.id, columnID: destinationColumnID, title: task.title, description: task.description, position: index)
                }
            }
            return
        }

        var destinationTasks = tasks.filter { $0.columnID == destinationColumnID }
        destinationTasks.sort { $0.position < $1.position }
        guard destinationPosition <= destinationTasks.count else {
            throw KanbanAPIError.unexpectedStatus(code: 400, operation: "moveTask", title: "Bad Request", detail: "invalid destination position")
        }

        destinationTasks.insert(
            KanbanTask(id: movingTask.id, columnID: destinationColumnID, title: movingTask.title, description: movingTask.description, position: destinationPosition),
            at: destinationPosition
        )

        for (index, task) in sourceTasks.enumerated() {
            if let fullIndex = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[fullIndex] = KanbanTask(id: task.id, columnID: task.columnID, title: task.title, description: task.description, position: index)
            }
        }

        for (index, task) in destinationTasks.enumerated() {
            if let fullIndex = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[fullIndex] = KanbanTask(id: task.id, columnID: destinationColumnID, title: task.title, description: task.description, position: index)
            }
        }
    }

    func deleteTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws {
        tasks.removeAll { $0.id == taskID }
    }
}
