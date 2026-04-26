import Foundation
import Testing
@testable import TodoMacOS

@MainActor
struct BoardViewModelTests {
    @Test func exportTasksWritesVersionedJSONSnapshot() async throws {
        // Requirements: API-007, BOARD-005, BOARD-007, BOARD-008, BOARD-018, BOARD-020, UX-013, UX-024
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
            exportTasksBundleHandler: { boardIDs, _, _ in
                TaskExportBundle(
                    formatVersion: TaskExportBundle.currentFormatVersion,
                    exportedAt: "2026-04-24T00:00:00Z",
                    boards: boardIDs.map {
                        TaskExportBundleBoard(sourceBoardID: $0, sourceBoardTitle: "Main", payload: exportedPayload)
                    }
                )
            }
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
        let payload = try JSONDecoder().decode(TaskExportBundle.self, from: data)

        #expect(payload.formatVersion == TaskExportBundle.currentFormatVersion)
        #expect(payload.boards.count == 1)
        #expect(payload.boards.first?.sourceBoardTitle == "Main")
        #expect(payload.boards.first?.payload.columns.map(\.title) == ["Backlog", "Done"])
        #expect(payload.boards.first?.payload.columns.first?.tasks.map(\.title) == ["Plan"])
        #expect(payload.taskCount == 2)
        #expect(viewModel.statusIsError == false)
        #expect(viewModel.statusMessage.contains("2"))
    }

    @Test func importTasksCreatesMissingColumnsAndTasksFromBundleJSON() async throws {
        // Requirements: API-007, API-008, BOARD-006, BOARD-008, BOARD-019, UX-013, UX-025
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
            importTasksBundleHandler: { sourceBoardIDs, bundle, _, _ in
                let selected = bundle.boards.filter { sourceBoardIDs.contains($0.sourceBoardID) }
                if let first = selected.first {
                    await capture.record(boardID: first.sourceBoardID, payload: first.payload)
                }
                return TaskImportBundleResult(totalCreatedColumnCount: 1, totalImportedTaskCount: 3)
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()

        let bundle = TaskExportBundle(
            formatVersion: TaskExportBundle.currentFormatVersion,
            exportedAt: "2026-04-24T00:00:00Z",
            boards: [
                TaskExportBundleBoard(
                    sourceBoardID: "board-1",
                    sourceBoardTitle: "Main",
                    payload: TaskExportPayload(
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
                )
            ]
        )

        let fileURL = makeTemporaryFileURL(fileName: "task-import.json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try JSONEncoder().encode(bundle).write(to: fileURL, options: .atomic)

        await viewModel.importTasks(from: fileURL)

        #expect(await capture.boardID() == "board-1")
        let importedPayload = await capture.payload()
        #expect(importedPayload?.columns.map(\.title) == ["Backlog", "Done"])
        #expect(importedPayload?.taskCount == 3)
        #expect(viewModel.statusIsError == false)
        #expect(viewModel.statusMessage.contains("3"))
    }

    @Test func exportTasksIncludesOnlyCheckedBoards() async throws {
        // Requirements: BOARD-018, UX-024, UX-026
        let boardA = KanbanBoard(id: "board-a", title: "A")
        let boardB = KanbanBoard(id: "board-b", title: "B")

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [boardA, boardB] },
            getBoardHandler: { boardID, _, _ in
                let board = boardID == boardA.id ? boardA : boardB
                return KanbanBoardDetails(board: board, columns: [], tasks: [])
            },
            exportTasksBundleHandler: { boardIDs, _, _ in
                TaskExportBundle(
                    formatVersion: TaskExportBundle.currentFormatVersion,
                    exportedAt: "2026-04-24T00:00:00Z",
                    boards: boardIDs.map { boardID in
                        TaskExportBundleBoard(
                            sourceBoardID: boardID,
                            sourceBoardTitle: boardID == boardA.id ? "A" : "B",
                            payload: TaskExportPayload(
                                formatVersion: TaskExportPayload.currentFormatVersion,
                                boardTitle: boardID == boardA.id ? "A" : "B",
                                exportedAt: "2026-04-24T00:00:00Z",
                                columns: [TaskExportColumn(title: "Backlog", tasks: [TaskExportTask(title: boardID, description: "")])]
                            )
                        )
                    }
                )
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()

        let fileURL = makeTemporaryFileURL(fileName: "task-export-selected.json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        await viewModel.exportTasks(to: fileURL, includedBoardIDs: [boardB.id])

        let data = try Data(contentsOf: fileURL)
        let bundle = try JSONDecoder().decode(TaskExportBundle.self, from: data)
        #expect(bundle.boards.count == 1)
        #expect(bundle.boards.first?.sourceBoardID == boardB.id)
        #expect(bundle.boards.first?.payload.columns.first?.tasks.first?.title == boardB.id)
    }

    @Test func importTasksIncludesOnlyCheckedBoardsFromBundle() async throws {
        // Requirements: BOARD-019, UX-025, UX-026
        let boardA = KanbanBoard(id: "board-a", title: "A")
        let boardB = KanbanBoard(id: "board-b", title: "B")
        let capture = MultiImportCapture()

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [boardA, boardB] },
            getBoardHandler: { boardID, _, _ in
                let board = boardID == boardA.id ? boardA : boardB
                return KanbanBoardDetails(board: board, columns: [], tasks: [])
            },
            importTasksBundleHandler: { sourceBoardIDs, bundle, _, _ in
                let selected = bundle.boards.filter { sourceBoardIDs.contains($0.sourceBoardID) }
                for snapshot in selected {
                    await capture.record(boardID: snapshot.sourceBoardID, payload: snapshot.payload)
                }
                return TaskImportBundleResult(
                    totalCreatedColumnCount: 0,
                    totalImportedTaskCount: selected.reduce(0) { $0 + $1.payload.taskCount }
                )
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()

        let bundle = TaskExportBundle(
            formatVersion: TaskExportBundle.currentFormatVersion,
            exportedAt: "2026-04-24T00:00:00Z",
            boards: [
                TaskExportBundleBoard(
                    sourceBoardID: boardA.id,
                    sourceBoardTitle: boardA.title,
                    payload: TaskExportPayload(
                        formatVersion: TaskExportPayload.currentFormatVersion,
                        boardTitle: boardA.title,
                        exportedAt: "2026-04-24T00:00:00Z",
                        columns: [TaskExportColumn(title: "Backlog", tasks: [TaskExportTask(title: "A task", description: "")])]
                    )
                ),
                TaskExportBundleBoard(
                    sourceBoardID: boardB.id,
                    sourceBoardTitle: boardB.title,
                    payload: TaskExportPayload(
                        formatVersion: TaskExportPayload.currentFormatVersion,
                        boardTitle: boardB.title,
                        exportedAt: "2026-04-24T00:00:00Z",
                        columns: [TaskExportColumn(title: "Backlog", tasks: [TaskExportTask(title: "B task", description: "")])]
                    )
                )
            ]
        )

        let fileURL = makeTemporaryFileURL(fileName: "task-import-selected.json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try JSONEncoder().encode(bundle).write(to: fileURL, options: .atomic)

        await viewModel.importTasks(from: fileURL, includedSourceBoardIDs: [boardA.id])

        let boardIDs = await capture.boardIDs()
        #expect(boardIDs == [boardA.id])
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

    @Test func archiveColumnTasksArchivesOnlySelectedColumnAndReloads() async {
        // Requirements: COL-ARCH-001, COL-ARCH-002, COL-ARCH-003, COL-ARCH-004
        let board = KanbanBoard(id: "board-1", title: "Main")
        let before = KanbanBoardDetails(
            board: board,
            columns: [
                KanbanColumn(id: "column-a", title: "Backlog", position: 0),
                KanbanColumn(id: "column-b", title: "Done", position: 1),
            ],
            tasks: [
                KanbanTask(id: "task-a1", columnID: "column-a", title: "A1", description: "", position: 0),
                KanbanTask(id: "task-a2", columnID: "column-a", title: "A2", description: "", position: 1),
                KanbanTask(id: "task-b1", columnID: "column-b", title: "B1", description: "", position: 0),
            ]
        )
        let after = KanbanBoardDetails(
            board: board,
            columns: before.columns,
            tasks: [
                KanbanTask(id: "task-b1", columnID: "column-b", title: "B1", description: "", position: 0),
            ]
        )
        let getBoardCount = AsyncCounter()

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in
                let count = await getBoardCount.incrementAndGet()
                return count == 1 ? before : after
            },
            archiveColumnTasksHandler: { boardID, columnID, _, _ in
                #expect(boardID == board.id)
                #expect(columnID == "column-a")
                return ColumnTaskArchiveResult(archivedTaskCount: 2, archivedAt: "2026-04-26T10:00:00Z")
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        #expect(viewModel.tasks(for: "column-a").count == 2)

        let didArchive = await viewModel.archiveColumnTasks(columnID: "column-a")

        #expect(didArchive)
        #expect(viewModel.tasks(for: "column-a").isEmpty)
        #expect(viewModel.tasks(for: "column-b").map(\.title) == ["B1"])
        #expect(viewModel.statusIsError == false)
        #expect(viewModel.statusMessage.contains("2"))
    }

    @Test func reloadBoardGroupsArchivedTasksByOriginalColumn() async {
        // Requirements: TASK-023, TASK-024, TASK-026, UX-029
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [
                KanbanColumn(id: "column-a", title: "Backlog", position: 0),
                KanbanColumn(id: "column-b", title: "Done", position: 1)
            ],
            tasks: [
                KanbanTask(id: "task-1", columnID: "column-a", title: "Active", description: "", position: 0)
            ]
        )

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in details },
            listArchivedTasksByBoardHandler: { _, _, _ in
                [
                    KanbanTask(id: "arch-1", columnID: "column-a", title: "Old A", description: "", position: 0, isArchived: true, archivedAt: "2026-04-26T10:00:00Z"),
                    KanbanTask(id: "arch-2", columnID: "column-b", title: "Old B", description: "", position: 0, isArchived: true, archivedAt: "2026-04-26T11:00:00Z")
                ]
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()

        #expect(viewModel.tasks(for: "column-a").map(\.title) == ["Active"])
        #expect(viewModel.archivedTasks(for: "column-a").map(\.title) == ["Old A"])
        #expect(viewModel.archivedTasks(for: "column-b").map(\.title) == ["Old B"])
        #expect(viewModel.archivedTasksStatusIsError == false)
    }

    @Test func archivedTaskLoadFailureDoesNotBlockActiveBoardRender() async {
        // Requirement: UX-031
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [KanbanColumn(id: "column-a", title: "Backlog", position: 0)],
            tasks: [KanbanTask(id: "task-1", columnID: "column-a", title: "Active", description: "", position: 0)]
        )

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in details },
            listArchivedTasksByBoardHandler: { _, _, _ in
                throw KanbanAPIError.unexpectedStatus(
                    code: 500,
                    operation: "listArchivedTasksByBoard",
                    title: "Internal",
                    detail: "archived fetch failed"
                )
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()

        #expect(viewModel.board?.id == board.id)
        #expect(viewModel.tasks(for: "column-a").map(\.title) == ["Active"])
        #expect(viewModel.archivedTasks(for: "column-a").isEmpty)
        #expect(viewModel.archivedTasksStatusIsError)
        #expect(viewModel.archivedTasksStatusMessage.contains("archived fetch failed"))
        #expect(viewModel.statusIsError == false)
    }

    @Test func restoreArchivedTaskMovesTaskBackToActiveColumn() async {
        // Requirements: TASK-027, TASK-029, UX-034
        let board = KanbanBoard(id: "board-1", title: "Main")
        let getBoardCount = AsyncCounter()

        let before = KanbanBoardDetails(
            board: board,
            columns: [KanbanColumn(id: "column-a", title: "Backlog", position: 0)],
            tasks: []
        )
        let after = KanbanBoardDetails(
            board: board,
            columns: [KanbanColumn(id: "column-a", title: "Backlog", position: 0)],
            tasks: [KanbanTask(id: "task-archived", columnID: "column-a", title: "Old", description: "", position: 0)]
        )

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in
                let count = await getBoardCount.incrementAndGet()
                return count == 1 ? before : after
            },
            listArchivedTasksByBoardHandler: { _, _, _ in
                [KanbanTask(id: "task-archived", columnID: "column-a", title: "Old", description: "", position: 0, isArchived: true, archivedAt: "2026-04-26T10:00:00Z")]
            },
            restoreArchivedTaskHandler: { _, taskID, _, _ in
                KanbanTask(id: taskID, columnID: "column-a", title: "Old", description: "", position: 0)
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        #expect(viewModel.archivedTasks(for: "column-a").count == 1)
        let didRestore = await viewModel.restoreArchivedTask(taskID: "task-archived")

        #expect(didRestore)
        #expect(viewModel.tasks(for: "column-a").map(\.title) == ["Old"])
        #expect(viewModel.statusIsError == false)
    }

    @Test func deleteArchivedTaskRemovesArchivedEntry() async {
        // Requirements: TASK-028, UX-034
        let board = KanbanBoard(id: "board-1", title: "Main")
        let getBoardCount = AsyncCounter()

        let details = KanbanBoardDetails(
            board: board,
            columns: [KanbanColumn(id: "column-a", title: "Backlog", position: 0)],
            tasks: []
        )

        let archivedState = ArchivedTaskState(initial: [
            KanbanTask(id: "task-archived", columnID: "column-a", title: "Old", description: "", position: 0, isArchived: true, archivedAt: "2026-04-26T10:00:00Z")
        ])

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in
                _ = await getBoardCount.incrementAndGet()
                return details
            },
            listArchivedTasksByBoardHandler: { _, _, _ in await archivedState.current() },
            deleteArchivedTaskHandler: { _, taskID, _, _ in
                await archivedState.remove(taskID: taskID)
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        #expect(viewModel.archivedTasks(for: "column-a").count == 1)

        let didDelete = await viewModel.deleteArchivedTask(taskID: "task-archived")

        #expect(didDelete)
        #expect(viewModel.archivedTasks(for: "column-a").isEmpty)
        #expect(viewModel.statusIsError == false)
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

    @Test func reorderTasksInColumnSendsListOrderPayload() async {
        // Requirements: TASK-037, TASK-038
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [KanbanColumn(id: "column-1", title: "Backlog", position: 0)],
            tasks: [
                KanbanTask(id: "task-1", columnID: "column-1", title: "1", description: "", position: 0),
                KanbanTask(id: "task-2", columnID: "column-1", title: "2", description: "", position: 1),
                KanbanTask(id: "task-3", columnID: "column-1", title: "3", description: "", position: 2),
                KanbanTask(id: "task-4", columnID: "column-1", title: "4", description: "", position: 3),
                KanbanTask(id: "task-5", columnID: "column-1", title: "5", description: "", position: 4)
            ]
        )
        let capture = ReorderTasksCapture()

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in details },
            reorderTasksHandler: { _, orderedTasksByColumn, _, _ in
                await capture.record(orderedTasksByColumn)
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        await viewModel.reorderTasksInColumn(
            columnID: "column-1",
            orderedTaskIDs: ["task-2", "task-4", "task-1", "task-3", "task-5"]
        )

        let payload = await capture.current()
        #expect(payload?.count == 1)
        #expect(payload?.first?.columnID == "column-1")
        #expect(payload?.first?.taskIDs == ["task-2", "task-4", "task-1", "task-3", "task-5"])
    }

    @Test func deleteTasksDeletesSelectedSetWithSingleMutationCycle() async {
        // Requirement: TASK-039
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [KanbanColumn(id: "column-1", title: "Backlog", position: 0)],
            tasks: [
                KanbanTask(id: "task-1", columnID: "column-1", title: "1", description: "", position: 0),
                KanbanTask(id: "task-2", columnID: "column-1", title: "2", description: "", position: 1),
                KanbanTask(id: "task-3", columnID: "column-1", title: "3", description: "", position: 2)
            ]
        )
        let capture = TaskBatchMutationCapture()

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in details },
            applyTaskBatchMutationHandler: { _, request, _, _ in
                await capture.record(request)
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        await viewModel.deleteTasks(taskIDs: ["task-2", "task-3", "task-2"])

        #expect(await capture.current()?.action == .delete)
        #expect(await capture.current()?.taskIDs == ["task-2", "task-3"])
        #expect(viewModel.statusIsError == false)
        #expect(viewModel.statusMessage == Strings.t("board.task.status.deleted"))
    }

    @Test func reorderTasksRejectsDuplicateTaskIDsInPayload() async {
        // Requirement: API-005
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [
                KanbanColumn(id: "column-1", title: "Backlog", position: 0),
                KanbanColumn(id: "column-2", title: "Done", position: 1)
            ],
            tasks: [
                KanbanTask(id: "task-1", columnID: "column-1", title: "1", description: "", position: 0),
                KanbanTask(id: "task-2", columnID: "column-1", title: "2", description: "", position: 1),
                KanbanTask(id: "task-3", columnID: "column-2", title: "3", description: "", position: 0)
            ]
        )
        let capture = ReorderTasksCapture()

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in details },
            reorderTasksHandler: { _, orderedTasksByColumn, _, _ in
                await capture.record(orderedTasksByColumn)
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        await viewModel.reorderTasks(
            orderedTasksByColumn: [
                KanbanTaskColumnOrder(columnID: "column-1", taskIDs: ["task-1", "task-1"]),
                KanbanTaskColumnOrder(columnID: "column-2", taskIDs: ["task-3"])
            ]
        )

        #expect(await capture.current() == nil)
        #expect(viewModel.statusIsError == true)
    }

    @Test func reorderTasksSupportsCrossColumnBatchMovePayload() async {
        // Requirements: TASK-040, UX-040
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [
                KanbanColumn(id: "column-1", title: "Backlog", position: 0),
                KanbanColumn(id: "column-2", title: "Done", position: 1)
            ],
            tasks: [
                KanbanTask(id: "task-1", columnID: "column-1", title: "1", description: "", position: 0),
                KanbanTask(id: "task-2", columnID: "column-1", title: "2", description: "", position: 1),
                KanbanTask(id: "task-3", columnID: "column-1", title: "3", description: "", position: 2),
                KanbanTask(id: "task-4", columnID: "column-2", title: "4", description: "", position: 0)
            ]
        )
        let capture = ReorderTasksCapture()

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in details },
            reorderTasksHandler: { _, orderedTasksByColumn, _, _ in
                await capture.record(orderedTasksByColumn)
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        await viewModel.reorderTasks(
            orderedTasksByColumn: [
                KanbanTaskColumnOrder(columnID: "column-1", taskIDs: ["task-1"]),
                KanbanTaskColumnOrder(columnID: "column-2", taskIDs: ["task-4", "task-2", "task-3"])
            ]
        )

        let payload = await capture.current()
        #expect(payload?.count == 2)
        #expect(payload?.first(where: { $0.columnID == "column-1" })?.taskIDs == ["task-1"])
        #expect(payload?.first(where: { $0.columnID == "column-2" })?.taskIDs == ["task-4", "task-2", "task-3"])
    }

    @Test func applyTaskBatchMutationDeleteUsesBatchRequestShape() async {
        // Requirement: TASK-041
        let board = KanbanBoard(id: "board-1", title: "Main")
        let details = KanbanBoardDetails(
            board: board,
            columns: [KanbanColumn(id: "column-1", title: "Backlog", position: 0)],
            tasks: [
                KanbanTask(id: "task-1", columnID: "column-1", title: "1", description: "", position: 0),
                KanbanTask(id: "task-2", columnID: "column-1", title: "2", description: "", position: 1),
                KanbanTask(id: "task-3", columnID: "column-1", title: "3", description: "", position: 2)
            ]
        )
        let capture = TaskBatchMutationCapture()

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in [board] },
            getBoardHandler: { _, _, _ in details },
            applyTaskBatchMutationHandler: { _, request, _, _ in
                await capture.record(request)
            }
        )

        let viewModel = BoardViewModel(
            api: api,
            accessTokenProvider: { "token-1" },
            baseURLProvider: { URL(string: "http://localhost:8080") }
        )

        await viewModel.reloadBoard()
        await viewModel.applyTaskBatchMutation(
            TaskBatchMutationRequest(action: .delete, taskIDs: ["task-3", "task-1", "task-3"])
        )

        #expect(await capture.current()?.action == .delete)
        #expect(await capture.current()?.taskIDs == ["task-3", "task-1"])
        #expect(viewModel.statusIsError == false)
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
        // Requirements: BOARD-015, BOARD-016, BOARD-023, UX-021
        let boardA = KanbanBoard(id: "board-a", title: "Board A")
        let active = MutableBoardList(initial: [KanbanBoard(id: "board-b", title: "Board B")])
        let archived = MutableBoardList(initial: [boardA])

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in await active.current() },
            listArchivedBoardsHandler: { _, _ in await archived.current() },
            restoreBoardHandler: { boardID, mode, _, _ in
                #expect(mode == .archived)
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
        let didRestore = await viewModel.restoreArchivedBoard(boardID: boardA.id, titleMode: .archived)

        #expect(didRestore)
        #expect(viewModel.archivedBoards.contains(where: { $0.id == boardA.id }) == false)
        #expect(viewModel.boards.contains(where: { $0.id == boardA.id }))
    }

    @Test func restoreArchivedBoardOriginalConflictSurfacesStatusDetails() async {
        // Requirements: BOARD-024, UX-028
        let boardA = KanbanBoard(id: "board-a", title: "Board A (archived)", archivedOriginalTitle: "Board A")
        let active = MutableBoardList(initial: [KanbanBoard(id: "board-b", title: "Board A")])
        let archived = MutableBoardList(initial: [boardA])

        let api = MockKanbanAPI(
            listBoardsHandler: { _, _ in await active.current() },
            listArchivedBoardsHandler: { _, _ in await archived.current() },
            restoreBoardHandler: { boardID, mode, _, _ in
                #expect(boardID == boardA.id)
                #expect(mode == .original)
                throw KanbanAPIError.unexpectedStatus(
                    code: 409,
                    operation: "restoreBoard",
                    title: "Conflict",
                    detail: "board title already exists"
                )
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
        let didRestore = await viewModel.restoreArchivedBoard(boardID: boardA.id, titleMode: .original)

        #expect(didRestore == false)
        #expect(viewModel.statusIsError)
        #expect(viewModel.statusMessage.contains("409"))
        #expect(viewModel.debugMessage.contains("operation=restoreBoard"))
        #expect(viewModel.debugMessage.contains("detail=board title already exists"))
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

private actor MultiImportCapture {
    private var imports: [(String, TaskExportPayload)] = []

    func record(boardID: String, payload: TaskExportPayload) {
        imports.append((boardID, payload))
    }

    func boardIDs() -> [String] {
        imports.map(\.0)
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

private actor ArchivedTaskState {
    private var tasks: [KanbanTask]

    init(initial: [KanbanTask]) {
        tasks = initial
    }

    func current() -> [KanbanTask] {
        tasks
    }

    func remove(taskID: String) {
        tasks.removeAll { $0.id == taskID }
    }
}

private actor ReorderTasksCapture {
    private var payload: [KanbanTaskColumnOrder]?

    func record(_ value: [KanbanTaskColumnOrder]) {
        payload = value
    }

    func current() -> [KanbanTaskColumnOrder]? {
        payload
    }
}

private actor TaskBatchMutationCapture {
    private var request: TaskBatchMutationRequest?

    func record(_ value: TaskBatchMutationRequest) {
        request = value
    }

    func current() -> TaskBatchMutationRequest? {
        request
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
