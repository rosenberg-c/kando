import Foundation

actor UITestKanbanAPI: KanbanAPI {
    private let board = KanbanBoard(id: "board-1", title: "UI Test Board")
    private var columns: [KanbanColumn]

    private var tasks: [KanbanTask]
    private let operationDelayNanoseconds: UInt64

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let requestedColumnCount = Int(environment[AppEnvironmentKey.columnCount] ?? "") ?? 2
        let columnCount = max(2, requestedColumnCount)
        columns = Self.makeColumns(count: columnCount)

        let requestedTaskCount = Int(environment[AppEnvironmentKey.workTaskCount] ?? "") ?? 1
        let taskCount = max(1, requestedTaskCount)
        let shouldSpreadTasks = environment[AppEnvironmentKey.spreadTasksAcrossColumns] == "1"
        tasks = Self.makeInitialTasks(count: taskCount, columns: columns, spreadAcrossColumns: shouldSpreadTasks)

        let requestedDelayMs = Int(environment[AppEnvironmentKey.mockDelayMs] ?? "") ?? 0
        operationDelayNanoseconds = UInt64(max(0, requestedDelayMs)) * 1_000_000
    }

    private func maybeDelay() async {
        guard operationDelayNanoseconds > 0 else { return }
        try? await Task.sleep(nanoseconds: operationDelayNanoseconds)
    }

    private static func makeColumns(count: Int) -> [KanbanColumn] {
        guard count > 2 else {
            return [
                KanbanColumn(id: "column-work", title: "Work", position: 0),
                KanbanColumn(id: "column-empty", title: "Empty", position: 1)
            ]
        }

        return (0..<count).map { index in
            KanbanColumn(
                id: "column-\(index + 1)",
                title: "Column \(index + 1)",
                position: index
            )
        }
    }

    private static func makeInitialTasks(count: Int, columns: [KanbanColumn], spreadAcrossColumns: Bool) -> [KanbanTask] {
        let destinationColumns = spreadAcrossColumns ? columns : [columns.first!]
        var nextPositionByColumnID: [String: Int] = [:]

        return (0..<count).map { index in
            let targetColumn = destinationColumns[index % destinationColumns.count]
            let position = nextPositionByColumnID[targetColumn.id, default: 0]
            nextPositionByColumnID[targetColumn.id] = position + 1
            let id = "task-\(index + 1)"
            let title = index == 0 ? "Example task" : "Example task \(index + 1)"
            return KanbanTask(
                id: id,
                columnID: targetColumn.id,
                title: title,
                description: "UI test item",
                position: position
            )
        }
    }

    func ensureBoard(accessToken: String, baseURL: URL, defaultTitle: String) async throws -> KanbanBoard {
        await maybeDelay()
        return board
    }

    func getBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoardDetails {
        await maybeDelay()
        return KanbanBoardDetails(board: board, columns: columns, tasks: tasks)
    }

    func createColumn(boardID: String, title: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        let nextPosition = (columns.map(\.position).max() ?? -1) + 1
        columns.append(KanbanColumn(id: UUID().uuidString, title: title, position: nextPosition))
    }

    func updateColumn(boardID: String, columnID: String, title: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        guard let index = columns.firstIndex(where: { $0.id == columnID }) else { return }
        columns[index] = KanbanColumn(id: columns[index].id, title: title, position: columns[index].position)
    }

    func reorderColumns(boardID: String, orderedColumnIDs: [String], accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        guard let reordered = reorderedColumns(columns, orderedIDs: orderedColumnIDs) else {
            throw KanbanAPIError.unexpectedStatus(code: 400, operation: "reorderColumns", title: "Bad Request", detail: "invalid column order")
        }
        columns = reordered
    }

    func deleteColumn(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
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
        await maybeDelay()
        let nextPosition = (tasks.filter { $0.columnID == columnID }.map(\.position).max() ?? -1) + 1
        tasks.append(KanbanTask(id: UUID().uuidString, columnID: columnID, title: title, description: description, position: nextPosition))
    }

    func updateTask(boardID: String, taskID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        let current = tasks[index]
        tasks[index] = KanbanTask(id: current.id, columnID: current.columnID, title: title, description: description, position: current.position)
    }

    func reorderTasks(boardID: String, orderedTasksByColumn: [KanbanTaskColumnOrder], accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
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
        await maybeDelay()
        tasks.removeAll { $0.id == taskID }
    }

    func exportTasks(boardID: String, accessToken: String, baseURL: URL) async throws -> TaskExportPayload {
        await maybeDelay()

        let exportColumns = columns
            .sorted { $0.position < $1.position }
            .map { column in
                TaskExportColumn(
                    title: column.title,
                    tasks: tasks
                        .filter { $0.columnID == column.id }
                        .sorted { $0.position < $1.position }
                        .map { TaskExportTask(title: $0.title, description: $0.description) }
                )
            }

        return TaskExportPayload(
            formatVersion: TaskExportPayload.currentFormatVersion,
            boardTitle: board.title,
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            columns: exportColumns
        )
    }

    func importTasks(boardID: String, payload: TaskExportPayload, accessToken: String, baseURL: URL) async throws -> TaskImportResult {
        await maybeDelay()

        guard payload.formatVersion == TaskExportPayload.currentFormatVersion else {
            throw KanbanAPIError.unexpectedStatus(
                code: 400,
                operation: "importTasks",
                title: "Bad Request",
                detail: "unsupported format version"
            )
        }

        var columnIDByTitle: [String: String] = [:]
        for column in columns.sorted(by: { $0.position < $1.position }) {
            if columnIDByTitle[column.title] == nil {
                columnIDByTitle[column.title] = column.id
            }
        }

        var createdColumnCount = 0
        for column in payload.columns {
            let trimmedTitle = column.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else { continue }
            if columnIDByTitle[trimmedTitle] != nil { continue }

            let nextPosition = (columns.map(\.position).max() ?? -1) + 1
            let columnID = UUID().uuidString
            columns.append(KanbanColumn(id: columnID, title: trimmedTitle, position: nextPosition))
            columnIDByTitle[trimmedTitle] = columnID
            createdColumnCount += 1
        }

        var importedTaskCount = 0
        var nextPositionByColumnID: [String: Int] = [:]
        for task in tasks {
            nextPositionByColumnID[task.columnID] = max(nextPositionByColumnID[task.columnID, default: 0], task.position + 1)
        }

        for column in payload.columns {
            let trimmedTitle = column.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let columnID = columnIDByTitle[trimmedTitle] else { continue }

            for task in column.tasks {
                let trimmedTaskTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTaskTitle.isEmpty else { continue }

                let position = nextPositionByColumnID[columnID, default: 0]
                nextPositionByColumnID[columnID] = position + 1
                tasks.append(
                    KanbanTask(
                        id: UUID().uuidString,
                        columnID: columnID,
                        title: trimmedTaskTitle,
                        description: task.description,
                        position: position
                    )
                )
                importedTaskCount += 1
            }
        }

        return TaskImportResult(createdColumnCount: createdColumnCount, importedTaskCount: importedTaskCount)
    }
}
