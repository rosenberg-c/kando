import Foundation
import Testing
@testable import TodoMacOS

@MainActor
struct BoardViewModelTests {
    @Test func mutationActionsEnabledOnlyWhenBoardReady() async {
        // Requirement: BOARD-003
        let gate = SuspendedOperationGate()
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(board: board, columns: [], todos: [])

        let api = MockKanbanAPI(
            ensureBoardHandler: { _, _, _ in board },
            getBoardHandler: { _, _, _ in
                await gate.markStarted()
                await gate.waitUntilResumed()
                return details
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        #expect(viewModel.canMutateBoardActions == false)

        let loadTask = Task {
            await viewModel.reloadBoard()
        }

        #expect(await waitUntil(timeoutNanoseconds: 1_000_000_000) {
            await gate.hasStarted()
        })
        #expect(viewModel.isLoading)
        #expect(viewModel.canMutateBoardActions == false)

        await gate.resume()
        await loadTask.value

        #expect(viewModel.board?.id == "board-1")
        #expect(viewModel.canMutateBoardActions)
    }

    @Test func deleteColumnConflictSurfacesStatusAndDebugDiagnostics() async {
        // Requirements: COL-RULE-003, API-004
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [KanbanColumn(id: "column-1", title: "Backlog", position: 0)],
            todos: [KanbanTodo(id: "todo-1", columnID: "column-1", title: "Task", description: "", position: 0)]
        )

        let api = MockKanbanAPI(
            ensureBoardHandler: { _, _, _ in board },
            getBoardHandler: { _, _, _ in details },
            deleteColumnHandler: { _, _, _, _ in
                throw KanbanAPIError.unexpectedStatus(
                    code: 409,
                    operation: "deleteColumn",
                    title: "Conflict",
                    detail: "column has todos"
                )
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        await viewModel.deleteColumn(columnID: "column-1")

        #expect(viewModel.statusIsError)
        #expect(viewModel.statusMessage.contains("409"))
        #expect(viewModel.debugMessage.contains("operation=deleteColumn"))
        #expect(viewModel.debugMessage.contains("status=409"))
        #expect(viewModel.debugMessage.contains("detail=column has todos"))
    }
}

@MainActor
private func waitUntil(timeoutNanoseconds: UInt64, condition: @escaping @MainActor () async -> Bool) async -> Bool {
    let started = ContinuousClock.now
    let timeout = Duration.nanoseconds(Int64(timeoutNanoseconds))
    while !(await condition()) {
        if ContinuousClock.now - started > timeout {
            return false
        }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    return true
}
