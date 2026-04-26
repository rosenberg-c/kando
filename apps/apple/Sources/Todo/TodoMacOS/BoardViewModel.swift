import Foundation

@MainActor
final class BoardViewModel: ObservableObject {
    @Published private(set) var board: KanbanBoard?
    @Published private(set) var boards: [KanbanBoard] = []
    @Published private(set) var archivedBoards: [KanbanBoard] = []
    @Published private(set) var selectedBoardID: String?
    @Published private(set) var columns: [KanbanColumn] = []
    @Published private(set) var tasksByColumnID: [String: [KanbanTask]] = [:]
    @Published var statusMessage = ""
    @Published var statusIsError = false
    @Published var isLoading = false
    @Published var debugMessage = ""

    var canMutateBoardActions: Bool {
        board != nil && !isLoading
    }

    var activeTaskCount: Int {
        tasksByColumnID.values.reduce(0) { $0 + $1.count }
    }

    var canDeleteActiveBoard: Bool {
        board != nil && activeTaskCount == 0 && !isLoading
    }

    private let api: any KanbanAPI
    private let accessTokenProvider: @MainActor () async -> String?
    private let baseURLProvider: @MainActor () -> URL?
    private let selectedBoardIDDefaultsKeyPrefix = "workspace.selectedBoardID"

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
        _ = await runMutation {
            let context = try await self.resolveContext()
            let availableBoards = try await self.listBoardsOrCreateDefault(context: context)
            self.archivedBoards = try await self.api.listArchivedBoards(accessToken: context.accessToken, baseURL: context.baseURL)

            let targetBoardID = self.resolveTargetBoardID(from: availableBoards, baseURL: context.baseURL)
            _ = try await self.loadAndApplyBoard(
                boardID: targetBoardID,
                availableBoards: availableBoards,
                context: context
            )
            self.setSuccess(Strings.t("board.status.loaded"))
        }
    }

    func archiveActiveBoard() async -> Bool {
        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            _ = try await self.api.archiveBoard(boardID: boardID, accessToken: context.accessToken, baseURL: context.baseURL)

            let availableBoards = try await self.listBoardsOrCreateDefault(context: context)
            self.archivedBoards = try await self.api.listArchivedBoards(accessToken: context.accessToken, baseURL: context.baseURL)
            let targetBoardID = self.resolveTargetBoardID(from: availableBoards, baseURL: context.baseURL)
            _ = try await self.loadAndApplyBoard(
                boardID: targetBoardID,
                availableBoards: availableBoards,
                context: context
            )
            self.setSuccess(Strings.t("board.status.archived"))
        }
    }

    func restoreArchivedBoard(boardID: String) async -> Bool {
        await runMutation {
            let context = try await self.resolveContext()
            _ = try await self.api.restoreBoard(boardID: boardID, accessToken: context.accessToken, baseURL: context.baseURL)
            let availableBoards = try await self.api.listBoards(accessToken: context.accessToken, baseURL: context.baseURL)
            self.archivedBoards = try await self.api.listArchivedBoards(accessToken: context.accessToken, baseURL: context.baseURL)
            if self.board == nil, !availableBoards.isEmpty {
                let targetBoardID = self.resolveTargetBoardID(from: availableBoards, baseURL: context.baseURL)
                _ = try await self.loadAndApplyBoard(boardID: targetBoardID, availableBoards: availableBoards, context: context)
            } else {
                self.boards = availableBoards
            }
            self.setSuccess(Strings.t("board.status.restored"))
        }
    }

    func deleteArchivedBoard(boardID: String) async -> Bool {
        await runMutation {
            let context = try await self.resolveContext()
            try await self.api.deleteArchivedBoard(boardID: boardID, accessToken: context.accessToken, baseURL: context.baseURL)
            self.archivedBoards = try await self.api.listArchivedBoards(accessToken: context.accessToken, baseURL: context.baseURL)
            self.setSuccess(Strings.t("board.status.archived_deleted"))
        }
    }

    func selectBoard(boardID: String) async {
        guard boardID != selectedBoardID else {
            return
        }

        _ = await runMutation {
            let context = try await self.resolveContext()
            let availableBoards = try await self.api.listBoards(accessToken: context.accessToken, baseURL: context.baseURL)
            guard availableBoards.contains(where: { $0.id == boardID }) else {
                throw KanbanAPIError.invalidResponse
            }
            let details = try await self.loadAndApplyBoard(boardID: boardID, availableBoards: availableBoards, context: context)
            self.setSuccess(Strings.f("board.status.switched", details.board.title))
        }
    }

    func createBoard(title: String) async -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setError(Strings.t("board.validation.title_required"))
            return false
        }

        return await runMutation {
            let context = try await self.resolveContext()
            let createdBoard = try await self.api.createBoard(
                title: trimmed,
                accessToken: context.accessToken,
                baseURL: context.baseURL
            )
            _ = try await self.refreshBoardsAndLoad(boardID: createdBoard.id, context: context, fallbackBoard: createdBoard)
            self.setSuccess(Strings.f("board.status.created", trimmed))
        }
    }

    func renameActiveBoard(title: String) async -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setError(Strings.t("board.validation.title_required"))
            return false
        }

        return await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            _ = try await self.api.updateBoard(
                boardID: boardID,
                title: trimmed,
                accessToken: context.accessToken,
                baseURL: context.baseURL
            )
            _ = try await self.refreshBoardsAndLoad(boardID: boardID, context: context)
            self.setSuccess(Strings.f("board.status.renamed", trimmed))
        }
    }

    func deleteActiveBoard() async -> Bool {
        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.deleteBoard(boardID: boardID, accessToken: context.accessToken, baseURL: context.baseURL)

            let availableBoards = try await self.listBoardsOrCreateDefault(context: context)
            self.archivedBoards = try await self.api.listArchivedBoards(accessToken: context.accessToken, baseURL: context.baseURL)
            let targetBoardID = self.resolveTargetBoardID(from: availableBoards, baseURL: context.baseURL)
            _ = try await self.loadAndApplyBoard(
                boardID: targetBoardID,
                availableBoards: availableBoards,
                context: context
            )
            self.setSuccess(Strings.t("board.status.deleted"))
        }
    }

    func createColumn(title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setError(Strings.t("board.column.validation.title_required"))
            return
        }

        _ = await runMutation {
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

        _ = await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.updateColumn(boardID: boardID, columnID: columnID, title: trimmed, accessToken: context.accessToken, baseURL: context.baseURL)
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.f("board.column.status.renamed", trimmed))
        }
    }

    func deleteColumn(columnID: String) async {
        _ = await runMutation {
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

        _ = await runMutation {
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

        _ = await runMutation {
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

        _ = await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.updateTask(boardID: boardID, taskID: taskID, title: trimmedTitle, description: trimmedDescription, accessToken: context.accessToken, baseURL: context.baseURL)
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.f("board.task.status.updated", trimmedTitle))
        }
    }

    func deleteTask(taskID: String) async {
        _ = await runMutation {
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

        _ = await runMutation {
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
        guard let selectedBoardID else {
            setError(Strings.t("board.error.invalid_response"))
            return
        }
        await exportTasks(to: fileURL, includedBoardIDs: [selectedBoardID])
    }

    func exportTasks(to fileURL: URL, includedBoardIDs: [String]) async {
        let selectedIDs = Set(includedBoardIDs)
        guard !selectedIDs.isEmpty else {
            setError(Strings.t("board.transfer.status.no_boards_selected"))
            return
        }

        do {
            let context = try await resolveContext()
            let selectedBoards = boards.filter { selectedIDs.contains($0.id) }
            guard selectedBoards.count == selectedIDs.count else {
                setError(Strings.t("board.error.invalid_response"))
                return
            }

            let orderedBoardIDs = selectedBoards.map(\.id)
            let bundle = try await api.exportTasksBundle(
                boardIDs: orderedBoardIDs,
                accessToken: context.accessToken,
                baseURL: context.baseURL
            )
            let data = try await Task.detached(priority: .userInitiated) { () throws -> Data in
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                return try encoder.encode(bundle)
            }.value
            try await Task.detached(priority: .userInitiated) {
                try data.write(to: fileURL, options: .atomic)
            }.value
            setSuccess(Strings.f("board.export.status.success", bundle.taskCount))
            debugMessage = ""
        } catch {
            setError(Strings.f("board.export.status.failed", error.localizedDescription))
            debugMessage = error.localizedDescription
        }
    }

    func importTasks(from fileURL: URL) async {
        let snapshots: [TaskExportBundleBoard]
        do {
            snapshots = try await readImportSnapshots(from: fileURL)
        } catch {
            setError(Strings.f("board.import.status.failed", error.localizedDescription))
            debugMessage = error.localizedDescription
            return
        }

        await importTasksFromSnapshots(snapshots, includedSourceBoardIDs: snapshots.map(\.sourceBoardID))
    }

    func importTasks(from fileURL: URL, includedSourceBoardIDs: [String]) async {
        let snapshots: [TaskExportBundleBoard]
        do {
            snapshots = try await readImportSnapshots(from: fileURL)
        } catch {
            setError(Strings.f("board.import.status.failed", error.localizedDescription))
            debugMessage = error.localizedDescription
            return
        }

        await importTasksFromSnapshots(snapshots, includedSourceBoardIDs: includedSourceBoardIDs)
    }

    private func importTasksFromSnapshots(_ snapshots: [TaskExportBundleBoard], includedSourceBoardIDs: [String]) async {
        let selectedSourceBoardIDs = Set(includedSourceBoardIDs)
        guard !selectedSourceBoardIDs.isEmpty else {
            setError(Strings.t("board.transfer.status.no_boards_selected"))
            return
        }

        let selectedSnapshots = snapshots.filter { selectedSourceBoardIDs.contains($0.sourceBoardID) }
        guard selectedSnapshots.count == selectedSourceBoardIDs.count else {
            setError(Strings.t("board.error.invalid_response"))
            return
        }

        _ = await runMutation {
            let context = try await self.resolveContext()

            let importBundle = TaskExportBundle(
                formatVersion: TaskExportBundle.currentFormatVersion,
                exportedAt: ISO8601DateFormatter().string(from: Date()),
                boards: selectedSnapshots
            )
            let result = try await self.api.importTasksBundle(
                sourceBoardIDs: selectedSnapshots.map(\.sourceBoardID),
                bundle: importBundle,
                accessToken: context.accessToken,
                baseURL: context.baseURL
            )

            try await self.reloadWithContext(context)
            self.setSuccess(Strings.f("board.import.status.success", result.totalImportedTaskCount))
        }
    }

    func importSnapshots(from fileURL: URL) async -> [TaskExportBundleBoard]? {
        do {
            return try await readImportSnapshots(from: fileURL)
        } catch {
            setError(Strings.f("board.import.status.failed", error.localizedDescription))
            debugMessage = error.localizedDescription
            return nil
        }
    }

    private func readImportSnapshots(from fileURL: URL) async throws -> [TaskExportBundleBoard] {
        let data = try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: fileURL)
        }.value

        let decoder = JSONDecoder()
        let bundle = try decoder.decode(TaskExportBundle.self, from: data)
        guard bundle.formatVersion == TaskExportBundle.currentFormatVersion else {
            throw KanbanAPIError.unexpectedStatus(
                code: 400,
                operation: "importTasks",
                title: nil,
                detail: "unsupported_bundle_format_version=\(bundle.formatVersion)"
            )
        }

        for snapshot in bundle.boards {
            guard snapshot.payload.formatVersion == TaskExportPayload.currentFormatVersion else {
                throw KanbanAPIError.unexpectedStatus(
                    code: 400,
                    operation: "importTasks",
                    title: nil,
                    detail: "unsupported_format_version=\(snapshot.payload.formatVersion)"
                )
            }
        }

        return bundle.boards
    }

    func tasks(for columnID: String) -> [KanbanTask] {
        (tasksByColumnID[columnID] ?? []).sorted { $0.position < $1.position }
    }

    private func runMutation(_ operation: @escaping @MainActor () async throws -> Void) async -> Bool {
        if isLoading {
            debugMessage = "mutation_ignored_in_flight"
            return false
        }
        isLoading = true
        defer { isLoading = false }

        do {
            try await operation()
            debugMessage = ""
            return true
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
            return false
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
            guard let boardID = selectedBoardID else {
                throw KanbanAPIError.invalidResponse
            }
            return BoardContext(baseURL: baseURL, accessToken: token, boardID: boardID)
        }

        return BoardContext(baseURL: baseURL, accessToken: token, boardID: selectedBoardID)
    }

    private func reloadWithContext(_ context: BoardContext) async throws {
        let boardID = try requireBoardID(context)
        _ = try await refreshBoardsAndLoad(boardID: boardID, context: context)
    }

    private func requireBoardID(_ context: BoardContext) throws -> String {
        guard let boardID = context.boardID else {
            throw KanbanAPIError.invalidResponse
        }
        return boardID
    }

    private func apply(details: KanbanBoardDetails) {
        apply(details: details, availableBoards: boards, baseURL: nil)
    }

    private func apply(details: KanbanBoardDetails, availableBoards: [KanbanBoard], baseURL: URL?) {
        board = details.board
        boards = availableBoards
        selectedBoardID = details.board.id
        persistSelectedBoardID(details.board.id, baseURL: baseURL)
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

    private func resolveTargetBoardID(from availableBoards: [KanbanBoard], baseURL: URL) -> String {
        if let selectedBoardID,
           availableBoards.contains(where: { $0.id == selectedBoardID }) {
            return selectedBoardID
        }

        let persistedID = persistedSelectedBoardID(baseURL: baseURL)
        if let persistedID,
           availableBoards.contains(where: { $0.id == persistedID }) {
            return persistedID
        }

        return availableBoards[0].id
    }

    private func persistedSelectedBoardID(baseURL: URL) -> String? {
        UserDefaults.standard.string(forKey: selectedBoardIDDefaultsKey(for: baseURL))
    }

    private func persistSelectedBoardID(_ boardID: String, baseURL: URL?) {
        guard let baseURL else {
            return
        }
        UserDefaults.standard.set(boardID, forKey: selectedBoardIDDefaultsKey(for: baseURL))
    }

    private func selectedBoardIDDefaultsKey(for baseURL: URL) -> String {
        return "\(selectedBoardIDDefaultsKeyPrefix).\(normalizedBaseURLIdentifier(baseURL))"
    }

    private func normalizedBaseURLIdentifier(_ baseURL: URL) -> String {
        let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let scheme = components?.scheme ?? baseURL.scheme ?? "unknown"
        let host = components?.host ?? baseURL.host ?? "unknown"
        let portPart = components?.port.map { ":\($0)" } ?? ""
        let rawPath = components?.path ?? baseURL.path
        let trimmedPath = rawPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.isEmpty {
            return "\(scheme)://\(host)\(portPart)"
        }
        return "\(scheme)://\(host)\(portPart)/\(trimmedPath)"
    }

    private func loadAndApplyBoard(boardID: String, availableBoards: [KanbanBoard], context: BoardContext) async throws -> KanbanBoardDetails {
        let details = try await self.api.getBoard(boardID: boardID, accessToken: context.accessToken, baseURL: context.baseURL)
        self.apply(details: details, availableBoards: availableBoards, baseURL: context.baseURL)
        return details
    }

    private func listBoardsOrCreateDefault(context: BoardContext) async throws -> [KanbanBoard] {
        var availableBoards = try await self.api.listBoards(accessToken: context.accessToken, baseURL: context.baseURL)
        if availableBoards.isEmpty {
            let created = try await self.api.createBoard(
                title: Strings.t("board.default.title"),
                accessToken: context.accessToken,
                baseURL: context.baseURL
            )
            availableBoards = [created]
        }
        return availableBoards
    }

    private func refreshBoardsAndLoad(boardID: String, context: BoardContext, fallbackBoard: KanbanBoard? = nil) async throws -> KanbanBoardDetails {
        var availableBoards = try await self.api.listBoards(accessToken: context.accessToken, baseURL: context.baseURL)
        if !availableBoards.contains(where: { $0.id == boardID }), let fallbackBoard, fallbackBoard.id == boardID {
            availableBoards.insert(fallbackBoard, at: 0)
        }
        guard availableBoards.contains(where: { $0.id == boardID }) else {
            throw KanbanAPIError.invalidResponse
        }
        return try await self.loadAndApplyBoard(boardID: boardID, availableBoards: availableBoards, context: context)
    }
}

private struct BoardContext {
    let baseURL: URL
    let accessToken: String
    let boardID: String?
}
