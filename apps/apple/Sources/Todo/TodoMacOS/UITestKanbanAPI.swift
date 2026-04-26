import Foundation

actor UITestKanbanAPI: KanbanAPI {
    private var boards: [KanbanBoard]
    private var archivedBoardIDs: Set<String>
    private var archivedOriginalTitleByBoardID: [String: String]
    private var columnsByBoardID: [String: [KanbanColumn]]
    private var tasksByBoardID: [String: [KanbanTask]]
    private let operationDelayNanoseconds: UInt64

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let initialBoard = KanbanBoard(id: "board-1", title: "UI Test Board")
        boards = [initialBoard]
        archivedBoardIDs = []
        archivedOriginalTitleByBoardID = [:]

        let requestedColumnCount = Int(environment[AppEnvironmentKey.columnCount] ?? "") ?? 2
        let columnCount = max(2, requestedColumnCount)
        let initialColumns = Self.makeColumns(count: columnCount)

        let requestedTaskCount = Int(environment[AppEnvironmentKey.workTaskCount] ?? "") ?? 1
        let taskCount = max(1, requestedTaskCount)
        let shouldSpreadTasks = environment[AppEnvironmentKey.spreadTasksAcrossColumns] == "1"
        let initialTasks = Self.makeInitialTasks(count: taskCount, columns: initialColumns, spreadAcrossColumns: shouldSpreadTasks)

        columnsByBoardID = [initialBoard.id: initialColumns]
        tasksByBoardID = [initialBoard.id: initialTasks]

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

    func listBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard] {
        await maybeDelay()
        return boards.filter { !archivedBoardIDs.contains($0.id) }
    }

    func listArchivedBoards(accessToken: String, baseURL: URL) async throws -> [KanbanBoard] {
        await maybeDelay()
        return boards.filter { archivedBoardIDs.contains($0.id) }
    }

    func createBoard(title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        await maybeDelay()
        let board = KanbanBoard(id: UUID().uuidString, title: title)
        boards.insert(board, at: 0)
        columnsByBoardID[board.id] = []
        tasksByBoardID[board.id] = []
        return board
    }

    func updateBoard(boardID: String, title: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        await maybeDelay()
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "updateBoard", title: "Not Found", detail: "board not found")
        }
        boards[index] = KanbanBoard(id: boardID, title: title)
        if index != 0 {
            let updated = boards.remove(at: index)
            boards.insert(updated, at: 0)
        }
        return boards[0]
    }

    func deleteBoard(boardID: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        guard boards.contains(where: { $0.id == boardID }) else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "deleteBoard", title: "Not Found", detail: "board not found")
        }
        if !(tasksByBoardID[boardID] ?? []).isEmpty {
            throw KanbanAPIError.unexpectedStatus(code: 409, operation: "deleteBoard", title: "Conflict", detail: "board has tasks")
        }

        boards.removeAll { $0.id == boardID }
        archivedBoardIDs.remove(boardID)
        columnsByBoardID.removeValue(forKey: boardID)
        tasksByBoardID.removeValue(forKey: boardID)
    }

    func archiveBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        await maybeDelay()
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "archiveBoard", title: "Not Found", detail: "board not found")
        }
        let board = boards[index]
        archivedOriginalTitleByBoardID[boardID] = board.title
        boards[index] = KanbanBoard(
            id: board.id,
            title: "\(board.title) (archived \(ISO8601DateFormatter().string(from: Date())))",
            archivedOriginalTitle: board.title
        )
        archivedBoardIDs.insert(boardID)
        return boards[index]
    }

    func restoreBoard(boardID: String, titleMode: RestoreBoardTitleMode, accessToken: String, baseURL: URL) async throws -> KanbanBoard {
        await maybeDelay()
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "restoreBoard", title: "Not Found", detail: "board not found")
        }
        let board = boards[index]
        let originalTitle = archivedOriginalTitleByBoardID[boardID] ?? board.archivedOriginalTitle ?? board.title
        let targetTitle = titleMode == .original ? originalTitle : board.title
        if titleMode == .original && boards.contains(where: { $0.id != boardID && !archivedBoardIDs.contains($0.id) && $0.title == targetTitle }) {
            throw KanbanAPIError.unexpectedStatus(code: 409, operation: "restoreBoard", title: "Conflict", detail: "board title already exists")
        }

        boards[index] = KanbanBoard(id: board.id, title: targetTitle)
        archivedOriginalTitleByBoardID.removeValue(forKey: boardID)
        archivedBoardIDs.remove(boardID)
        return boards[index]
    }

    func deleteArchivedBoard(boardID: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        guard archivedBoardIDs.contains(boardID) else {
            throw KanbanAPIError.unexpectedStatus(code: 409, operation: "deleteArchivedBoard", title: "Conflict", detail: "board is not archived")
        }
        boards.removeAll { $0.id == boardID }
        archivedBoardIDs.remove(boardID)
        archivedOriginalTitleByBoardID.removeValue(forKey: boardID)
        columnsByBoardID.removeValue(forKey: boardID)
        tasksByBoardID.removeValue(forKey: boardID)
    }

    func getBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoardDetails {
        await maybeDelay()
        guard let board = boards.first(where: { $0.id == boardID }) else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "getBoard", title: "Not Found", detail: "board not found")
        }
        return KanbanBoardDetails(
            board: board,
            columns: columnsByBoardID[boardID] ?? [],
            tasks: (tasksByBoardID[boardID] ?? []).filter { !$0.isArchived }
        )
    }

    func createColumn(boardID: String, title: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        guard var columns = columnsByBoardID[boardID] else { return }
        let nextPosition = (columns.map(\.position).max() ?? -1) + 1
        columns.append(KanbanColumn(id: UUID().uuidString, title: title, position: nextPosition))
        columnsByBoardID[boardID] = columns
    }

    func updateColumn(boardID: String, columnID: String, title: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        guard var columns = columnsByBoardID[boardID] else { return }
        guard let index = columns.firstIndex(where: { $0.id == columnID }) else { return }
        columns[index] = KanbanColumn(id: columns[index].id, title: title, position: columns[index].position)
        columnsByBoardID[boardID] = columns
    }

    func reorderColumns(boardID: String, orderedColumnIDs: [String], accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        guard let columns = columnsByBoardID[boardID] else { return }
        guard let reordered = reorderedColumns(columns, orderedIDs: orderedColumnIDs) else {
            throw KanbanAPIError.unexpectedStatus(code: 400, operation: "reorderColumns", title: "Bad Request", detail: "invalid column order")
        }
        columnsByBoardID[boardID] = reordered
    }

    func deleteColumn(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        if (tasksByBoardID[boardID] ?? []).contains(where: { $0.columnID == columnID && !$0.isArchived }) {
            throw KanbanAPIError.unexpectedStatus(
                code: 409,
                operation: "deleteColumn",
                title: "Conflict",
                detail: "column has tasks"
            )
        }

        guard var columns = columnsByBoardID[boardID] else { return }
        columns.removeAll { $0.id == columnID }
        for (index, column) in columns.enumerated() {
            columns[index] = KanbanColumn(id: column.id, title: column.title, position: index)
        }
        columnsByBoardID[boardID] = columns
    }

    func archiveColumnTasks(boardID: String, columnID: String, accessToken: String, baseURL: URL) async throws -> ColumnTaskArchiveResult {
        await maybeDelay()
        guard tasksByBoardID[boardID] != nil else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "archiveColumnTasks", title: "Not Found", detail: "board not found")
        }

        let archivedAt = ISO8601DateFormatter().string(from: Date())
        var tasks = tasksByBoardID[boardID] ?? []
        var archivedCount = 0
        for index in tasks.indices {
            guard tasks[index].columnID == columnID, !tasks[index].isArchived else { continue }
            tasks[index] = KanbanTask(
                id: tasks[index].id,
                columnID: tasks[index].columnID,
                title: tasks[index].title,
                description: tasks[index].description,
                position: tasks[index].position,
                isArchived: true,
                archivedAt: archivedAt
            )
            archivedCount += 1
        }
        tasksByBoardID[boardID] = tasks

        return ColumnTaskArchiveResult(archivedTaskCount: archivedCount, archivedAt: archivedAt)
    }

    func listArchivedTasksByBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> [KanbanTask] {
        await maybeDelay()
        let columns = (columnsByBoardID[boardID] ?? []).sorted { $0.position < $1.position }
        let columnOrder: [String: Int] = Dictionary(uniqueKeysWithValues: columns.enumerated().map { ($1.id, $0) })

        return (tasksByBoardID[boardID] ?? [])
            .filter { $0.isArchived }
            .sorted {
                let leftColumn = columnOrder[$0.columnID, default: Int.max]
                let rightColumn = columnOrder[$1.columnID, default: Int.max]
                if leftColumn != rightColumn {
                    return leftColumn < rightColumn
                }
                if $0.archivedAt != $1.archivedAt {
                    return ($0.archivedAt ?? "") < ($1.archivedAt ?? "")
                }
                if $0.position != $1.position {
                    return $0.position < $1.position
                }
                return $0.id < $1.id
            }
    }

    func restoreArchivedTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws -> KanbanTask {
        await maybeDelay()
        guard var tasks = tasksByBoardID[boardID] else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "restoreArchivedTask", title: "Not Found", detail: "board not found")
        }
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "restoreArchivedTask", title: "Not Found", detail: "task not found")
        }

        let task = tasks[index]
        guard task.isArchived else {
            throw KanbanAPIError.unexpectedStatus(code: 409, operation: "restoreArchivedTask", title: "Conflict", detail: "task is not archived")
        }

        let nextPosition = (tasks.filter { $0.columnID == task.columnID && !$0.isArchived }.map(\.position).max() ?? -1) + 1
        let restored = KanbanTask(
            id: task.id,
            columnID: task.columnID,
            title: task.title,
            description: task.description,
            position: nextPosition,
            isArchived: false,
            archivedAt: nil
        )
        tasks[index] = restored
        tasksByBoardID[boardID] = tasks
        return restored
    }

    func deleteArchivedTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        guard var tasks = tasksByBoardID[boardID] else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "deleteArchivedTask", title: "Not Found", detail: "board not found")
        }
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else {
            throw KanbanAPIError.unexpectedStatus(code: 404, operation: "deleteArchivedTask", title: "Not Found", detail: "task not found")
        }
        guard tasks[index].isArchived else {
            throw KanbanAPIError.unexpectedStatus(code: 409, operation: "deleteArchivedTask", title: "Conflict", detail: "task is not archived")
        }

        tasks.remove(at: index)
        tasksByBoardID[boardID] = tasks
    }

    func createTask(boardID: String, columnID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        var tasks = tasksByBoardID[boardID] ?? []
        let nextPosition = (tasks.filter { $0.columnID == columnID && !$0.isArchived }.map(\.position).max() ?? -1) + 1
        tasks.append(KanbanTask(id: UUID().uuidString, columnID: columnID, title: title, description: description, position: nextPosition))
        tasksByBoardID[boardID] = tasks
    }

    func updateTask(boardID: String, taskID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        guard var tasks = tasksByBoardID[boardID] else { return }
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        let current = tasks[index]
        tasks[index] = KanbanTask(id: current.id, columnID: current.columnID, title: title, description: description, position: current.position)
        tasksByBoardID[boardID] = tasks
    }

    func reorderTasks(boardID: String, orderedTasksByColumn: [KanbanTaskColumnOrder], accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        let columns = columnsByBoardID[boardID] ?? []
        let tasks = tasksByBoardID[boardID] ?? []

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

        tasksByBoardID[boardID] = reordered
    }

    func deleteTask(boardID: String, taskID: String, accessToken: String, baseURL: URL) async throws {
        await maybeDelay()
        var tasks = tasksByBoardID[boardID] ?? []
        tasks.removeAll { $0.id == taskID }
        tasksByBoardID[boardID] = tasks
    }

    func exportTasksBundle(boardIDs: [String], accessToken: String, baseURL: URL) async throws -> TaskExportBundle {
        await maybeDelay()
        let selectedBoardIDs = try normalizedUniqueIDs(boardIDs, operation: "exportTasksBundle")

        let snapshots = try selectedBoardIDs.map { boardID -> TaskExportBundleBoard in
            guard let board = boards.first(where: { $0.id == boardID }) else {
                throw KanbanAPIError.unexpectedStatus(code: 404, operation: "exportTasksBundle", title: "Not Found", detail: "board not found")
            }
            let columns = columnsByBoardID[boardID] ?? []
            let tasks = tasksByBoardID[boardID] ?? []

            let exportColumns = columns
                .sorted { $0.position < $1.position }
                .map { column in
                    TaskExportColumn(
                        title: column.title,
                        tasks: tasks
                            .filter { $0.columnID == column.id && !$0.isArchived }
                            .sorted { $0.position < $1.position }
                            .map { TaskExportTask(title: $0.title, description: $0.description) },
                        archivedTasks: tasks
                            .filter { $0.columnID == column.id && $0.isArchived }
                            .sorted { $0.position < $1.position }
                            .map { TaskExportTask(title: $0.title, description: $0.description, archivedAt: $0.archivedAt) }
                    )
                }

            return TaskExportBundleBoard(
                sourceBoardID: board.id,
                sourceBoardTitle: board.title,
                payload: TaskExportPayload(
                    formatVersion: TaskExportPayload.currentFormatVersion,
                    boardTitle: board.title,
                    exportedAt: ISO8601DateFormatter().string(from: Date()),
                    columns: exportColumns
                )
            )
        }

        return TaskExportBundle(
            formatVersion: TaskExportBundle.currentFormatVersion,
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            boards: snapshots
        )
    }

    func importTasksBundle(sourceBoardIDs: [String], bundle: TaskExportBundle, accessToken: String, baseURL: URL) async throws -> TaskImportBundleResult {
        await maybeDelay()

        guard bundle.formatVersion == TaskExportBundle.currentFormatVersion else {
            throw KanbanAPIError.unexpectedStatus(
                code: 400,
                operation: "importTasksBundle",
                title: "Bad Request",
                detail: "unsupported bundle format version"
            )
        }

        let selectedSourceIDs = try normalizedUniqueIDs(sourceBoardIDs, operation: "importTasksBundle")

        var snapshotBySourceID: [String: TaskExportBundleBoard] = [:]
        for snapshot in bundle.boards {
            snapshotBySourceID[snapshot.sourceBoardID] = snapshot
        }

        var totalCreatedColumns = 0
        var totalImportedTasks = 0
        for sourceBoardID in selectedSourceIDs {
            guard let snapshot = snapshotBySourceID[sourceBoardID] else {
                throw KanbanAPIError.unexpectedStatus(code: 400, operation: "importTasksBundle", title: "Bad Request", detail: "source board not found in bundle")
            }
            let destinationBoardID: String
            if boards.contains(where: { $0.id == snapshot.sourceBoardID }) {
                destinationBoardID = snapshot.sourceBoardID
            } else if let board = boards.first(where: { $0.title == snapshot.sourceBoardTitle }) {
                destinationBoardID = board.id
            } else {
                let created = KanbanBoard(id: UUID().uuidString, title: snapshot.sourceBoardTitle)
                boards.insert(created, at: 0)
                columnsByBoardID[created.id] = []
                tasksByBoardID[created.id] = []
                destinationBoardID = created.id
            }

            let result = try importPayload(into: destinationBoardID, payload: snapshot.payload)
            totalCreatedColumns += result.createdColumnCount
            totalImportedTasks += result.importedTaskCount
        }

        return TaskImportBundleResult(
            totalCreatedColumnCount: totalCreatedColumns,
            totalImportedTaskCount: totalImportedTasks
        )
    }

    private func normalizedUniqueIDs(_ ids: [String], operation: String) throws -> [String] {
        guard !ids.isEmpty else {
            throw KanbanAPIError.unexpectedStatus(code: 400, operation: operation, title: "Bad Request", detail: "no boards selected")
        }

        var normalized: [String] = []
        normalized.reserveCapacity(ids.count)
        var seen: Set<String> = []

        for value in ids {
            let id = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else {
                throw KanbanAPIError.unexpectedStatus(code: 400, operation: operation, title: "Bad Request", detail: "invalid board id")
            }
            guard !seen.contains(id) else {
                throw KanbanAPIError.unexpectedStatus(code: 400, operation: operation, title: "Bad Request", detail: "duplicate board id")
            }
            seen.insert(id)
            normalized.append(id)
        }

        return normalized
    }

    private func importPayload(into boardID: String, payload: TaskExportPayload) throws -> TaskImportResult {

        guard payload.formatVersion == TaskExportPayload.currentFormatVersion else {
            throw KanbanAPIError.unexpectedStatus(
                code: 400,
                operation: "importTasksBundle",
                title: "Bad Request",
                detail: "unsupported format version"
            )
        }

        var columns = columnsByBoardID[boardID] ?? []
        var tasks = tasksByBoardID[boardID] ?? []

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

            for task in column.archivedTasks {
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
                        position: position,
                        isArchived: true,
                        archivedAt: task.archivedAt
                    )
                )
                importedTaskCount += 1
            }
        }

        columnsByBoardID[boardID] = columns
        tasksByBoardID[boardID] = tasks

        return TaskImportResult(createdColumnCount: createdColumnCount, importedTaskCount: importedTaskCount)
    }
}
