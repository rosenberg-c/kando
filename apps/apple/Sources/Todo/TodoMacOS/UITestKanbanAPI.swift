import Foundation

actor UITestKanbanAPI: KanbanAPI {
    private let board = KanbanBoard(id: "board-1", title: "UI Test Board")
    private var columns: [KanbanColumn] = [
        KanbanColumn(id: "column-work", title: "Work", position: 0),
        KanbanColumn(id: "column-empty", title: "Empty", position: 1)
    ]
    private var todos: [KanbanTodo] = [
        KanbanTodo(id: "todo-1", columnID: "column-work", title: "Example todo", description: "UI test item", position: 0)
    ]

    func ensureBoard(accessToken: String, baseURL: URL, defaultTitle: String) async throws -> KanbanBoard {
        board
    }

    func getBoard(boardID: String, accessToken: String, baseURL: URL) async throws -> KanbanBoardDetails {
        KanbanBoardDetails(board: board, columns: columns, todos: todos)
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
        if todos.contains(where: { $0.columnID == columnID }) {
            throw KanbanAPIError.unexpectedStatus(
                code: 409,
                operation: "deleteColumn",
                title: "Conflict",
                detail: "column has todos"
            )
        }
        columns.removeAll { $0.id == columnID }
        for (index, column) in columns.enumerated() {
            columns[index] = KanbanColumn(id: column.id, title: column.title, position: index)
        }
    }

    func createTodo(boardID: String, columnID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        let nextPosition = (todos.filter { $0.columnID == columnID }.map(\.position).max() ?? -1) + 1
        todos.append(KanbanTodo(id: UUID().uuidString, columnID: columnID, title: title, description: description, position: nextPosition))
    }

    func updateTodo(boardID: String, todoID: String, title: String, description: String, accessToken: String, baseURL: URL) async throws {
        guard let index = todos.firstIndex(where: { $0.id == todoID }) else { return }
        let current = todos[index]
        todos[index] = KanbanTodo(id: current.id, columnID: current.columnID, title: title, description: description, position: current.position)
    }

    func deleteTodo(boardID: String, todoID: String, accessToken: String, baseURL: URL) async throws {
        todos.removeAll { $0.id == todoID }
    }
}
