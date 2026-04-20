import Foundation

@MainActor
final class BoardViewModel: ObservableObject {
    @Published private(set) var board: KanbanBoard?
    @Published private(set) var columns: [KanbanColumn] = []
    @Published private(set) var todosByColumnID: [String: [KanbanTodo]] = [:]
    @Published var statusMessage = ""
    @Published var statusIsError = false
    @Published var isLoading = false
    @Published var debugMessage = ""

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

    func createTodo(columnID: String, title: String, description: String) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            setError(Strings.t("board.todo.validation.title_required"))
            return
        }

        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.createTodo(boardID: boardID, columnID: columnID, title: trimmedTitle, description: trimmedDescription, accessToken: context.accessToken, baseURL: context.baseURL)
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.f("board.todo.status.created", trimmedTitle))
        }
    }

    func updateTodo(todoID: String, title: String, description: String) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            setError(Strings.t("board.todo.validation.title_required"))
            return
        }

        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.updateTodo(boardID: boardID, todoID: todoID, title: trimmedTitle, description: trimmedDescription, accessToken: context.accessToken, baseURL: context.baseURL)
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.f("board.todo.status.updated", trimmedTitle))
        }
    }

    func deleteTodo(todoID: String) async {
        await runMutation {
            let context = try await self.resolveContext(requireBoard: true)
            let boardID = try self.requireBoardID(context)
            try await self.api.deleteTodo(boardID: boardID, todoID: todoID, accessToken: context.accessToken, baseURL: context.baseURL)
            try await self.reloadWithContext(context)
            self.setSuccess(Strings.t("board.todo.status.deleted"))
        }
    }

    func todos(for columnID: String) -> [KanbanTodo] {
        (todosByColumnID[columnID] ?? []).sorted { $0.position < $1.position }
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
        var grouped: [String: [KanbanTodo]] = [:]
        for todo in details.todos {
            grouped[todo.columnID, default: []].append(todo)
        }
        for key in grouped.keys {
            grouped[key]?.sort { $0.position < $1.position }
        }
        todosByColumnID = grouped
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
