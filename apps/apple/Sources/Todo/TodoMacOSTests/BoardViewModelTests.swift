import Foundation
import Testing
@testable import TodoMacOS

@MainActor
struct BoardViewModelTests {
    @Test func exportTasksWritesVersionedJSONSnapshot() async throws {
        // Requirements: API-007, BOARD-005, BOARD-007, BOARD-008, UX-013
        let board = KanbanBoard(id: "board-1", title: "Main")
        let exportedPayload = TaskExportPayload(
            formatVersion: TaskExportPayload.currentFormatVersion,
            boardTitle: "Main",
            exportedAt: "2026-04-24T00:00:00Z",
            columns: [
                TaskExportColumn(title: "Backlog", tasks: [TaskExportTask(title: "Plan", description: "notes")]),
                TaskExportColumn(title: "Done", tasks: [TaskExportTask(title: "Ship", description: "")])
            ]
        )
        let details = KanbanBoardDetails(
            board: board,
            columns: [
                KanbanColumn(id: "column-1", title: "Backlog", position: 0),
                KanbanColumn(id: "column-2", title: "Done", position: 1)
            ],
            tasks: [
                KanbanTask(id: "task-1", columnID: "column-1", title: "Plan", description: "notes", position: 0),
                KanbanTask(id: "task-2", columnID: "column-2", title: "Ship", description: "", position: 0)
            ]
        )

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in details },
            exportTasksHandler: { _, _, _ in exportedPayload }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()

        let fileURL = makeTemporaryFileURL(fileName: "task-export.json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        await viewModel.exportTasks(to: fileURL)

        let data = try Data(contentsOf: fileURL)
        let payload = try JSONDecoder().decode(TaskExportPayload.self, from: data)

        #expect(payload.formatVersion == TaskExportPayload.currentFormatVersion)
        #expect(payload.boardTitle == "Main")
        #expect(payload.columns.map(\.title) == ["Backlog", "Done"])
        #expect(payload.columns.first?.tasks.map(\.title) == ["Plan"])
        #expect(payload.taskCount == 2)
        #expect(viewModel.statusIsError == false)
        #expect(viewModel.statusMessage.contains("2"))
    }

    @Test func importTasksCreatesMissingColumnsAndTasksFromJSON() async throws {
        // Requirements: API-007, API-008, BOARD-006, BOARD-008, UX-013
        let board = KanbanBoard(id: "board-1", title: "Main")
        let capture = ImportCapture()

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in
                KanbanBoardDetails(
                    board: board,
                    columns: [
                        KanbanColumn(id: "column-1", title: "Backlog", position: 0),
                        KanbanColumn(id: "column-2", title: "Done", position: 1)
                    ],
                    tasks: []
                )
            },
            importTasksHandler: { boardID, payload, _, _ in
                await capture.record(boardID: boardID, payload: payload)
                return TaskImportResult(createdColumnCount: 1, importedTaskCount: 3)
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()

        let payload = TaskExportPayload(
            formatVersion: TaskExportPayload.currentFormatVersion,
            boardTitle: "Main",
            exportedAt: "2026-04-24T00:00:00Z",
            columns: [
                TaskExportColumn(title: "Backlog", tasks: [TaskExportTask(title: "Plan", description: "")]),
                TaskExportColumn(title: "Done", tasks: [
                    TaskExportTask(title: "Ship", description: ""),
                    TaskExportTask(title: "Celebrate", description: "")
                ])
            ]
        )

        let fileURL = makeTemporaryFileURL(fileName: "task-import.json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try JSONEncoder().encode(payload).write(to: fileURL, options: .atomic)

        await viewModel.importTasks(from: fileURL)

        #expect(await capture.boardID() == "board-1")
        let importedPayload = await capture.payload()
        #expect(importedPayload?.columns.map(\.title) == ["Backlog", "Done"])
        #expect(importedPayload?.taskCount == 3)
        #expect(viewModel.statusIsError == false)
        #expect(viewModel.statusMessage.contains("3"))
    }

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
            listBoardsHandler: { _, _ in [board] },
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
        // Requirements: BOARD-003, UX-009
        let gate = SuspendedOperationGate()
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(board: board, columns: [], tasks: [])

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
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
            listBoardsHandler: { _, _ in [board] },
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

    @Test func reorderTasksConflictSurfacesStatusDetails() async {
        // Requirements: UX-006, API-005
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [
                KanbanColumn(id: "column-1", title: "Backlog", position: 0),
                KanbanColumn(id: "column-2", title: "Doing", position: 1)
            ],
            tasks: [KanbanTask(id: "task-1", columnID: "column-1", title: "Task", description: "", position: 0)]
        )

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in details },
            reorderTasksHandler: { _, _, _, _ in
                throw KanbanAPIError.unexpectedStatus(
                    code: 409,
                    operation: "reorderTasks",
                    title: "Conflict",
                    detail: "invalid task list"
                )
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        await viewModel.moveTask(taskID: "task-1", destinationColumnID: "column-2", destinationPosition: 0)

        #expect(viewModel.statusIsError)
        #expect(viewModel.statusMessage.contains("409"))
        #expect(viewModel.debugMessage.contains("operation=reorderTasks"))
        #expect(viewModel.debugMessage.contains("status=409"))
        #expect(viewModel.debugMessage.contains("detail=invalid task list"))
    }

    @Test func reorderColumnsOptimisticallyReordersAndPersists() async {
        // Requirement: COL-MOVE-008
        let gate = SuspendedOperationGate()
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [
                KanbanColumn(id: "column-a", title: "A", position: 0),
                KanbanColumn(id: "column-b", title: "B", position: 1),
                KanbanColumn(id: "column-c", title: "C", position: 2)
            ],
            tasks: []
        )

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in details },
            reorderColumnsHandler: { _, _, _, _ in
                await gate.markStarted()
                await gate.waitUntilResumed()
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()

        let reorderTask = Task {
            await viewModel.reorderColumns(orderedColumnIDs: ["column-c", "column-a", "column-b"])
        }

        #expect(await waitUntil(timeoutNanoseconds: 1_000_000_000) {
            await gate.hasStarted()
        })
        #expect(viewModel.columns.map(\.id) == ["column-c", "column-a", "column-b"])

        await gate.resume()
        await reorderTask.value

        #expect(viewModel.columns.map(\.id) == ["column-c", "column-a", "column-b"])
        #expect(viewModel.statusIsError == false)
        #expect(viewModel.statusMessage == Strings.t("board.column.status.moved"))
    }

    @Test func reorderColumnsFailureRollsBackOrderAndShowsError() async {
        // Requirement: COL-MOVE-008
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [
                KanbanColumn(id: "column-a", title: "A", position: 0),
                KanbanColumn(id: "column-b", title: "B", position: 1),
                KanbanColumn(id: "column-c", title: "C", position: 2)
            ],
            tasks: []
        )

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in details },
            reorderColumnsHandler: { _, _, _, _ in
                throw KanbanAPIError.unexpectedStatus(
                    code: 409,
                    operation: "reorderColumns",
                    title: "Conflict",
                    detail: "stale board version"
                )
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        await viewModel.reorderColumns(orderedColumnIDs: ["column-c", "column-a", "column-b"])

        #expect(viewModel.columns.map(\.id) == ["column-a", "column-b", "column-c"])
        #expect(viewModel.statusIsError)
        #expect(viewModel.statusMessage.contains("409"))
        #expect(viewModel.debugMessage.contains("operation=reorderColumns"))
    }

    @Test func switchingBoardsLoadsSelectedBoardDetails() async {
        // Requirements: BOARD-011, UX-015
        let boardA = KanbanBoard(id: "board-a", title: "Project A")
        let boardB = KanbanBoard(id: "board-b", title: "Project B")

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [boardA, boardB] },
            getBoardHandler: { boardID, _, _ in
                if boardID == boardA.id {
                    return KanbanBoardDetails(
                        board: boardA,
                        columns: [KanbanColumn(id: "column-a", title: "Backlog", position: 0)],
                        tasks: [KanbanTask(id: "task-a", columnID: "column-a", title: "A task", description: "", position: 0)]
                    )
                }
                return KanbanBoardDetails(
                    board: boardB,
                    columns: [KanbanColumn(id: "column-b", title: "Doing", position: 0)],
                    tasks: [KanbanTask(id: "task-b", columnID: "column-b", title: "B task", description: "", position: 0)]
                )
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        #expect(viewModel.board?.id == "board-a")

        await viewModel.selectBoard(boardID: "board-b")
        #expect(viewModel.board?.id == "board-b")
        #expect(viewModel.columns.map(\.id) == ["column-b"])
        #expect(viewModel.tasks(for: "column-b").map(\.id) == ["task-b"])
    }

    @Test func createAndRenameBoardUpdatesSelectionAndBoardList() async {
        // Requirements: BOARD-009, BOARD-010, UX-016
        let boardA = KanbanBoard(id: "board-a", title: "Project A")
        let boardB = KanbanBoard(id: "board-b", title: "Project B")
        let createdBoard = KanbanBoard(id: "board-c", title: "Project C")
        let renamedBoard = KanbanBoard(id: "board-c", title: "Project C Renamed")
        let boardList = MutableBoardList(initial: [boardA, boardB])

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in await boardList.current() },
            createBoardHandler: { title, _, _ in
                #expect(title == "Project C")
                await boardList.prepend(createdBoard)
                return createdBoard
            },
            updateBoardHandler: { boardID, title, _, _ in
                #expect(boardID == "board-c")
                #expect(title == "Project C Renamed")
                await boardList.replace(boardID: boardID, withTitle: title)
                return renamedBoard
            },
            getBoardHandler: { boardID, _, _ in
                let boards = await boardList.current()
                let board = boards.first(where: { $0.id == boardID }) ?? boardA
                return KanbanBoardDetails(board: board, columns: [], tasks: [])
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        await viewModel.createBoard(title: "Project C")

        #expect(viewModel.board?.id == "board-c")
        #expect(viewModel.boards.map(\.id).contains("board-c"))

        await viewModel.renameActiveBoard(title: "Project C Renamed")

        #expect(viewModel.board?.title == "Project C Renamed")
        #expect(viewModel.boards.first(where: { $0.id == "board-c" })?.title == "Project C Renamed")
    }

    @Test func deleteActiveBoardSwitchesToRemainingBoard() async {
        // Requirements: BOARD-013, UX-019
        let boardA = KanbanBoard(id: "board-a", title: "Board A")
        let boardB = KanbanBoard(id: "board-b", title: "Board B")
        let boardList = MutableBoardList(initial: [boardA, boardB])

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in await boardList.current() },
            deleteBoardHandler: { boardID, _, _ in
                #expect(boardID == boardB.id)
                await boardList.remove(boardID: boardID)
            },
            getBoardHandler: { boardID, _, _ in
                let board = (await boardList.current()).first(where: { $0.id == boardID }) ?? boardA
                if board.id == boardA.id {
                    return KanbanBoardDetails(
                        board: board,
                        columns: [KanbanColumn(id: "column-a", title: "A", position: 0)],
                        tasks: [KanbanTask(id: "task-a", columnID: "column-a", title: "Task", description: "", position: 0)]
                    )
                }
                return KanbanBoardDetails(board: board, columns: [], tasks: [])
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        await viewModel.selectBoard(boardID: boardB.id)
        #expect(viewModel.canDeleteActiveBoard)

        let didDelete = await viewModel.deleteActiveBoard()

        #expect(didDelete)
        #expect(viewModel.board?.id == boardA.id)
        #expect(viewModel.boards.contains(where: { $0.id == boardB.id }) == false)
        #expect(viewModel.statusIsError == false)
        #expect(viewModel.statusMessage == Strings.t("board.status.deleted"))
    }

    @Test func deleteActiveBoardConflictSurfacesStatusDetails() async {
        // Requirements: BOARD-013, API-013, UX-019
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [KanbanColumn(id: "column-1", title: "Backlog", position: 0)],
            tasks: [KanbanTask(id: "task-1", columnID: "column-1", title: "Task", description: "", position: 0)]
        )

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            deleteBoardHandler: { _, _, _ in
                throw KanbanAPIError.unexpectedStatus(
                    code: 409,
                    operation: "deleteBoard",
                    title: "Conflict",
                    detail: "board has tasks"
                )
            },
            getBoardHandler: { _, _, _ in details }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        #expect(viewModel.canDeleteActiveBoard == false)
        let didDelete = await viewModel.deleteActiveBoard()

        #expect(didDelete == false)
        #expect(viewModel.statusIsError)
        #expect(viewModel.statusMessage.contains("409"))
        #expect(viewModel.debugMessage.contains("operation=deleteBoard"))
        #expect(viewModel.debugMessage.contains("status=409"))
        #expect(viewModel.debugMessage.contains("detail=board has tasks"))
    }

    @Test func archiveActiveBoardMovesBoardToArchivedList() async {
        // Requirements: BOARD-014, BOARD-015, UX-020
        let boardA = KanbanBoard(id: "board-a", title: "Board A")
        let boardB = KanbanBoard(id: "board-b", title: "Board B")
        let boardList = MutableBoardList(initial: [boardA, boardB])
        let archived = MutableBoardList(initial: [])

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in await boardList.current() },
            listArchivedBoardsHandler: { _, _ in await archived.current() },
            archiveBoardHandler: { boardID, _, _ in
                guard let board = (await boardList.current()).first(where: { $0.id == boardID }) else {
                    throw KanbanAPIError.invalidResponse
                }
                await boardList.remove(boardID: boardID)
                await archived.prepend(KanbanBoard(id: boardID, title: board.title))
                return board
            },
            getBoardHandler: { boardID, _, _ in
                let board = (await boardList.current()).first(where: { $0.id == boardID }) ?? boardA
                return KanbanBoardDetails(board: board, columns: [], tasks: [])
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        let didArchive = await viewModel.archiveActiveBoard()

        #expect(didArchive)
        #expect(viewModel.archivedBoards.contains(where: { $0.id == boardA.id }))
        #expect(viewModel.boards.contains(where: { $0.id == boardA.id }) == false)
        #expect(viewModel.board?.id == boardB.id)
    }

    @Test func restoreArchivedBoardReturnsItToActiveList() async {
        // Requirements: BOARD-015, BOARD-016, UX-021
        let boardA = KanbanBoard(id: "board-a", title: "Board A")
        let active = MutableBoardList(initial: [KanbanBoard(id: "board-b", title: "Board B")])
        let archived = MutableBoardList(initial: [boardA])

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in await active.current() },
            listArchivedBoardsHandler: { _, _ in await archived.current() },
            restoreBoardHandler: { boardID, _, _ in
                guard let board = (await archived.current()).first(where: { $0.id == boardID }) else {
                    throw KanbanAPIError.invalidResponse
                }
                await archived.remove(boardID: boardID)
                await active.prepend(KanbanBoard(id: boardID, title: board.title))
                return board
            },
            getBoardHandler: { boardID, _, _ in
                let board = (await active.current()).first(where: { $0.id == boardID }) ?? boardA
                return KanbanBoardDetails(board: board, columns: [], tasks: [])
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        let didRestore = await viewModel.restoreArchivedBoard(boardID: boardA.id)

        #expect(didRestore)
        #expect(viewModel.archivedBoards.contains(where: { $0.id == boardA.id }) == false)
        #expect(viewModel.boards.contains(where: { $0.id == boardA.id }))
    }
}

private actor ImportCapture {
    private var capturedBoardID: String?
    private var capturedPayload: TaskExportPayload?

    func record(boardID: String, payload: TaskExportPayload) {
        capturedBoardID = boardID
        capturedPayload = payload
    }

    func boardID() -> String? {
        capturedBoardID
    }

    func payload() -> TaskExportPayload? {
        capturedPayload
    }
}

private actor AsyncCounter {
    private var value = 0

    func incrementAndGet() -> Int {
        value += 1
        return value
    }
}

private actor MutableBoardList {
    private var boards: [KanbanBoard]

    init(initial: [KanbanBoard]) {
        boards = initial
    }

    func current() -> [KanbanBoard] {
        boards
    }

    func prepend(_ board: KanbanBoard) {
        boards.removeAll { $0.id == board.id }
        boards.insert(board, at: 0)
    }

    func replace(boardID: String, withTitle title: String) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else {
            return
        }
        boards[index] = KanbanBoard(id: boardID, title: title)
        let updated = boards.remove(at: index)
        boards.insert(updated, at: 0)
    }

    func remove(boardID: String) {
        boards.removeAll { $0.id == boardID }
    }
}

private func makeTemporaryFileURL(fileName: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString)-\(fileName)")
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
