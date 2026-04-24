import Foundation

@MainActor
final class BoardViewModel: ObservableObject {
    @Published private(set) var board: KanbanBoard?
    @Published private(set) var columns: [KanbanColumn] = []
    @Published private(set) var tasksByColumnID: [String: [KanbanTask]] = [:]
    @Published var statusMessage = ""
    @Published var statusIsError = false
    @Published var isLoading = false
    @Published var debugMessage = ""

    var canMutateBoardActions: Bool {
        board != nil && !isLoading
    }

    private let api: any KanbanAPI
    private let accessTokenProvider: @MainActor () async -> String?
    private let baseURLProvider: @MainActor () -> URL?

    init(
        api: (any KanbanAPI)? = nil,
        accessTokenProvider: @escaping @MainActor () async -> String?,
        baseURLProvider: @escaping @MainActor () -> URL?
    ) {
        self.api = api ?? GeneratedKanbanAPI()
        self.accessTokenProvider = accessTokenProvider
        self.baseURLProvider = baseURLProvider
    }

    func loadBoardIfNeeded() async {
        guard board == nil else {
            return
        }
        await reloadBoard()
    }

    func reloadBoard() async {
        await runMutation {
            let context = try await self.resolveContext()
            let ensuredBoard = try await self.api.ensureBoard(accessToken: context.accessToken, baseURL: context.baseURL, defaultTitle: Strings.t("board.default.title"))
            let details = try await self.api.getBoard(boardID: ensuredBoard.id, accessToken: context.accessToken, baseURL: context.baseURL)
            self.apply(details: details)
            self.setSuccess(Strings.t("board.status.loaded"))
        }
    }

    func createColumn(title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setError(Strings.t("board.column.validation.title_required"))
            return
        }

        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.createColumn(boardID: boardID, title: trimmed, accessToken: context.accessToken, baseURL: context.baseURL)
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.f("board.column.status.created", trimmed))
        }
    }

    func renameColumn(columnID: String, title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setError(Strings.t("board.column.validation.title_required"))
            return
        }

        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.updateColumn(boardID: boardID, columnID: columnID, title: trimmed, accessToken: context.accessToken, baseURL: context.baseURL)
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.f("board.column.status.renamed", trimmed))
        }
    }

    func deleteColumn(columnID: String) async {
        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.deleteColumn(boardID: boardID, columnID: columnID, accessToken: context.accessToken, baseURL: context.baseURL)
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.t("board.column.status.deleted"))
        }
    }

    @discardableResult
    func reorderColumns(orderedColumnIDs: [String]) async -> Bool {
        let previousColumns = columns
        guard let reordered = reorderedColumns(columns, orderedIDs: orderedColumnIDs) else {
            setError(Strings.t("board.error.invalid_response"))
            return false
        }
        columns = reordered

        var didSucceed = false

        await runMutation {
            do {
                let context = try await self.resolveContext(requireBoard: true)
                let boardID = try self.requireBoardID(context)
                try await self.api.reorderColumns(
                    boardID: boardID,
                    orderedColumnIDs: orderedColumnIDs,
                    accessToken: context.accessToken,
                    baseURL: context.baseURL
                )
                self.setSuccess(Strings.t("board.column.status.moved"))
                didSucceed = true
            } catch {
                self.columns = previousColumns
                throw error
            }
        }

        return didSucceed
    }

    func createTask(columnID: String, title: String, description: String) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            setError(Strings.t("board.task.validation.title_required"))
            return
        }

        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.createTask(boardID: boardID, columnID: columnID, title: trimmedTitle, description: trimmedDescription, accessToken: context.accessToken, baseURL: context.baseURL)
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.f("board.task.status.created", trimmedTitle))
        }
    }

    func updateTask(taskID: String, title: String, description: String) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            setError(Strings.t("board.task.validation.title_required"))
            return
        }

        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.updateTask(boardID: boardID, taskID: taskID, title: trimmedTitle, description: trimmedDescription, accessToken: context.accessToken, baseURL: context.baseURL)
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.f("board.task.status.updated", trimmedTitle))
        }
    }

    func deleteTask(taskID: String) async {
        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.deleteTask(boardID: boardID, taskID: taskID, accessToken: context.accessToken, baseURL: context.baseURL)
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.t("board.task.status.deleted"))
        }
    }

    func moveTask(taskID: String, destinationColumnID: String, destinationPosition: Int) async {
        guard destinationPosition >= 0 else {
            setError(Strings.t("board.error.invalid_response"))
            return
        }

        guard let sourceColumnID = tasksByColumnID.first(where: { _, tasks in
            tasks.contains(where: { $0.id == taskID })
        })?.key else {
            setError(Strings.t("board.error.invalid_response"))
            return
        }

        var reorderedTasksByColumn = tasksByColumnID
        guard var sourceTasks = reorderedTasksByColumn[sourceColumnID],
              let sourceIndex = sourceTasks.firstIndex(where: { $0.id == taskID }) else {
            setError(Strings.t("board.error.invalid_response"))
            return
        }

        let movingTask = sourceTasks.remove(at: sourceIndex)
        reorderedTasksByColumn[sourceColumnID] = sourceTasks

        var destinationTasks = reorderedTasksByColumn[destinationColumnID] ?? []
        let insertionIndex = min(destinationPosition, destinationTasks.count)
        destinationTasks.insert(movingTask, at: insertionIndex)
        reorderedTasksByColumn[destinationColumnID] = destinationTasks

        let orderedTasksByColumn = columns
            .sorted { $0.position < $1.position }
            .map { column in
                KanbanTaskColumnOrder(
                    columnID: column.id,
                    taskIDs: (reorderedTasksByColumn[column.id] ?? []).map(\.id)
                )
            }

        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.reorderTasks(
                boardID: boardID,
                orderedTasksByColumn: orderedTasksByColumn,
                accessToken: context.accessToken,
                baseURL: context.baseURL
            )
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.t("board.task.status.moved"))
        }
    }

    func exportTasks(to fileURL: URL) async {
        do {
            let context = try await resolveContext(requireBoard: true)
            let boardID = try requireBoardID(context)
            let payload = try await api.exportTasks(
                boardID: boardID,
                accessToken: context.accessToken,
                baseURL: context.baseURL
            )
            let data = try await Task.detached(priority: .userInitiated) { () throws -> Data in
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                return try encoder.encode(payload)
            }.value
            try await Task.detached(priority: .userInitiated) {
                try data.write(to: fileURL, options: .atomic)
            }.value
            setSuccess(Strings.f("board.export.status.success", payload.taskCount))
            debugMessage = ""
        } catch {
            setError(Strings.f("board.export.status.failed", error.localizedDescription))
            debugMessage = error.localizedDescription
        }
    }

    func importTasks(from fileURL: URL) async {
        let payload: TaskExportPayload
        do {
            payload = try await Task.detached(priority: .userInitiated) { () throws -> TaskExportPayload in
                let data = try Data(contentsOf: fileURL)
                return try JSONDecoder().decode(TaskExportPayload.self, from: data)
            }.value
        } catch {
            setError(Strings.f("board.import.status.failed", error.localizedDescription))
            debugMessage = error.localizedDescription
            return
        }

        guard payload.formatVersion == TaskExportPayload.currentFormatVersion else {
            setError(Strings.f("board.import.status.unsupported_version", payload.formatVersion))
            debugMessage = "unsupported_format_version=\(payload.formatVersion)"
            return
        }

        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            let result = try await self.api.importTasks(
                boardID: boardID,
                payload: payload,
                accessToken: context.accessToken,
                baseURL: context.baseURL
            )

            try await self.reloadWithContext(context)
            self.setSuccess(Strings.f("board.import.status.success", result.importedTaskCount))
        }
    }

    func tasks(for columnID: String) -> [KanbanTask] {
        (tasksByColumnID[columnID] ?? []).sorted { $0.position < $1.position }
    }

    private func runMutation(_ operation: @escaping @MainActor () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await operation()
            debugMessage = ""
        } catch {
            if let apiError = error as? KanbanAPIError, case .unauthorized = apiError {
                setError(Strings.t("board.error.unauthorized"))
                debugMessage = apiError.debugDescription
            } else if let apiError = error as? KanbanAPIError {
                setError(apiError.errorDescription ?? Strings.t("board.error.invalid_response"))
                debugMessage = apiError.debugDescription
            } else if let localized = error as? LocalizedError, let description = localized.errorDescription {
                setError(description)
                debugMessage = error.localizedDescription
            } else {
                setError(Strings.f("board.error.network", error.localizedDescription))
                debugMessage = error.localizedDescription
            }
        }
    }

    private func resolveContext(requireBoard: Bool = false) async throws -> BoardContext {
        guard let baseURL = baseURLProvider() else {
            throw KanbanAPIError.invalidResponse
        }
        guard let token = await accessTokenProvider() else {
            throw KanbanAPIError.unauthorized
        }

        if requireBoard {
            guard let boardID = board?.id else {
                throw KanbanAPIError.invalidResponse
            }
            return BoardContext(baseURL: baseURL, accessToken: token, boardID: boardID)
        }

        return BoardContext(baseURL: baseURL, accessToken: token, boardID: board?.id)
    }

    private func reloadWithContext(_ context: BoardContext) async throws {
        let boardID = try requireBoardID(context)
        let details = try await api.getBoard(boardID: boardID, accessToken: context.accessToken, baseURL: context.baseURL)
        apply(details: details)
    }

    private func requireBoardID(_ context: BoardContext) throws -> String {
        guard let boardID = context.boardID else {
            throw KanbanAPIError.invalidResponse
        }
        return boardID
    }

    private func apply(details: KanbanBoardDetails) {
        board = details.board
        columns = details.columns.sorted { $0.position < $1.position }
        var grouped: [String: [KanbanTask]] = [:]
        for task in details.tasks {
            grouped[task.columnID, default: []].append(task)
        }
        for key in grouped.keys {
            grouped[key]?.sort { $0.position < $1.position }
        }
        tasksByColumnID = grouped
    }

    private func setError(_ message: String) {
        statusIsError = true
        statusMessage = message
    }

    private func setSuccess(_ message: String) {
        statusIsError = false
        statusMessage = message
    }
}

private struct BoardContext {
    let baseURL: URL
    let accessToken: String
    let boardID: String?
}
