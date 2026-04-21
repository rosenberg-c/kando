import Foundation
import Testing
@testable import TodoMacOS

@MainActor
struct BoardViewModelTests {
    @Test func manualRefreshReloadsBoardStateFromAPI() async {
        // Requirement: BOARD-004
        let board = KanbanBoard(id: "board-1", title: "Main")
        let firstDetails = KanbanBoardDetails(
            board: KanbanBoard(id: "board-1", title: "Main"),
            columns: [KanbanColumn(id: "column-1", title: "Backlog", position: 0)],
            tasks: [KanbanTask(id: "task-1", columnID: "column-1", title: "Initial task", description: "", position: 0)]
        )
        let refreshedDetails = KanbanBoardDetails(
            board: KanbanBoard(id: "board-1", title: "Main (Refreshed)"),
            columns: [KanbanColumn(id: "column-2", title: "Doing", position: 0)],
            tasks: [KanbanTask(id: "task-2", columnID: "column-2", title: "Refreshed task", description: "", position: 0)]
        )
        let callCounter = AsyncCounter()

        let api = MockKanbanAPI(
            ensureBoardHandler: { _, _, _ in board },
            getBoardHandler: { _, _, _ in
                let call = await callCounter.incrementAndGet()
                if call == 1 {
                    return firstDetails
                }
                return refreshedDetails
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        #expect(viewModel.board?.title == "Main")
        #expect(viewModel.columns.first?.id == "column-1")
        #expect(viewModel.tasks(for: "column-1").map(\.id) == ["task-1"])

        await viewModel.reloadBoard()
        #expect(viewModel.board?.title == "Main (Refreshed)")
        #expect(viewModel.columns.first?.id == "column-2")
        #expect(viewModel.tasks(for: "column-2").map(\.id) == ["task-2"])
    }

    @Test func mutationActionsEnabledOnlyWhenBoardReady() async {
        // Requirement: BOARD-003
        let gate = SuspendedOperationGate()
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(board: board, columns: [], tasks: [])

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

    @Test func deleteColumnConflictSurfacesStatusDetails() async {
        // Requirements: COL-RULE-003, UX-002, UX-004
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [KanbanColumn(id: "column-1", title: "Backlog", position: 0)],
            tasks: [KanbanTask(id: "task-1", columnID: "column-1", title: "Task", description: "", position: 0)]
        )

        let api = MockKanbanAPI(
            ensureBoardHandler: { _, _, _ in board },
            getBoardHandler: { _, _, _ in details },
            deleteColumnHandler: { _, _, _, _ in
                throw KanbanAPIError.unexpectedStatus(
                    code: 409,
                    operation: "deleteColumn",
                    title: "Conflict",
                    detail: "column has tasks"
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
        #expect(viewModel.debugMessage.contains("detail=column has tasks"))
    }
}

private actor AsyncCounter {
    private var value = 0

    func incrementAndGet() -> Int {
        value += 1
        return value
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
