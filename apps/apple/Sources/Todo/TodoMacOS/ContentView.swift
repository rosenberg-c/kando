//
//  ContentView.swift
//  TodoMacOS
//
//  Created by christian on 2026-04-18.
//

import AppKit
import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var auth = AuthSessionViewModel()
    @AppStorage("signin.keepSignedIn") private var keepSignedIn = true
    private let processEnvironment = ProcessInfo.processInfo.environment

    private var canSubmit: Bool {
        !auth.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !auth.password.isEmpty && !auth.isSigningIn
    }

    var body: some View {
        Group {
            if auth.isSignedIn {
                LoggedInWorkspaceView(auth: auth) {
                    Task {
                        await auth.signOut()
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("signin.title")
                        .font(.largeTitle.weight(.semibold))

                    Text("signin.subtitle")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("signin.email.label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("signin.email.placeholder", text: $auth.email)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("signin.password.label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("signin.password.placeholder", text: $auth.password)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("signin.keep_signed_in", isOn: $keepSignedIn)
                        .toggleStyle(.checkbox)

                    Button("signin.submit") {
                        Task {
                            await auth.signIn(keepSignedIn: keepSignedIn)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canSubmit)

                    if !auth.statusMessage.isEmpty {
                        Text(auth.statusMessage)
                            .font(.caption)
                            .foregroundStyle(auth.statusIsError ? .red : .green)
                            .textSelection(.enabled)
                    }

                    if auth.canRetryRestore {
                        Button("session.restore.retry") {
                            Task {
                                await auth.retrySessionRestore()
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 12) {
                        Button("signin.forgot_password") {}
                            .buttonStyle(.link)
                        Button("signin.create_account") {}
                            .buttonStyle(.link)
                    }
                }
                .padding(24)
                .frame(width: 420)
                .allowsHitTesting(!auth.isSigningIn)
                .overlay {
                    if auth.isSigningIn {
                        BlockingLoadingOverlay(
                            message: Strings.t("signin.submit_in_progress"),
                            accessibilityID: "auth-loading-overlay"
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            if processEnvironment[AppEnvironmentKey.signedIn] == "1" {
                auth.applyUITestSignedInSession(email: processEnvironment[AppEnvironmentKey.email] ?? "ui-test@example.com")
            } else {
                await auth.restoreSessionIfNeeded()
            }
        }
    }
}

private enum WorkspaceLayout {
    static let taskListMinHeight: CGFloat = 180
    static let reservedVerticalChromeHeight: CGFloat = 80
}

private enum WorkspaceSettingsDefaultsKey {
    static let showTopBottomTaskButtons = "board.settings.task_controls.show_top_bottom"
    static let showUpDownTaskButtons = "board.settings.task_controls.show_up_down"
    static let showEditDeleteTaskButtons = "board.settings.task_controls.show_edit_delete"
}

private struct TaskControlVisibility {
    let showsTopBottom: Bool
    let showsUpDown: Bool
    let showsEditDelete: Bool
}

private struct TaskControlVisibilityBindings {
    let showsTopBottom: Binding<Bool>
    let showsUpDown: Binding<Bool>
    let showsEditDelete: Binding<Bool>
}

private struct LoggedInWorkspaceView: View {
    @ObservedObject var auth: AuthSessionViewModel
    let onSignOut: () -> Void

    @StateObject private var board: BoardViewModel
    @State private var newColumnTitle = ""
    @State private var editingColumn: EditableColumn?
    @State private var creatingTaskInColumn: CreateTaskTarget?
    @State private var isEditBoardSheetPresented = false
    @State private var isCreateBoardSheetPresented = false
    @State private var editingTask: EditableTask?
    @State private var pendingColumnDeletion: EditableColumn?
    @State private var pendingTaskDeletion: EditableTask?
    @State private var isSettingsSheetPresented = false
    @State private var exportSelectionSheet: BoardExportSelectionSheetState?
    @State private var importSelectionSheet: BoardImportSelectionSheetState?
    @State private var selectedTaskID: String?
    @AppStorage(WorkspaceSettingsDefaultsKey.showTopBottomTaskButtons) private var showsTopBottomTaskButtons = true
    @AppStorage(WorkspaceSettingsDefaultsKey.showUpDownTaskButtons) private var showsUpDownTaskButtons = true
    @AppStorage(WorkspaceSettingsDefaultsKey.showEditDeleteTaskButtons) private var showsEditDeleteTaskButtons = true

    private var taskControlVisibility: TaskControlVisibility {
        TaskControlVisibility(
            showsTopBottom: showsTopBottomTaskButtons,
            showsUpDown: showsUpDownTaskButtons,
            showsEditDelete: showsEditDeleteTaskButtons
        )
    }

    private var taskControlVisibilityBindings: TaskControlVisibilityBindings {
        TaskControlVisibilityBindings(
            showsTopBottom: $showsTopBottomTaskButtons,
            showsUpDown: $showsUpDownTaskButtons,
            showsEditDelete: $showsEditDeleteTaskButtons
        )
    }

    private func resetTaskControlDefaultsForUITestsIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment[AppEnvironmentKey.resetTaskControlDefaults] == "1" else { return }

        UserDefaults.standard.set(true, forKey: WorkspaceSettingsDefaultsKey.showTopBottomTaskButtons)
        UserDefaults.standard.set(true, forKey: WorkspaceSettingsDefaultsKey.showUpDownTaskButtons)
        UserDefaults.standard.set(true, forKey: WorkspaceSettingsDefaultsKey.showEditDeleteTaskButtons)
    }

    init(auth: AuthSessionViewModel, onSignOut: @escaping () -> Void) {
        self.auth = auth
        self.onSignOut = onSignOut
        let api: any KanbanAPI
        let env = ProcessInfo.processInfo.environment
        if RuntimeFlags.shouldUseMockBoard(environment: env) {
            api = UITestKanbanAPI()
        } else {
            api = GeneratedKanbanAPI()
        }
        _board = StateObject(wrappedValue: BoardViewModel(
            api: api,
            accessTokenProvider: { await auth.validAccessToken() },
            baseURLProvider: { auth.currentAPIBaseURL() }
        ))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(board.board?.title ?? Strings.t("board.title"))
                            .font(.largeTitle.weight(.semibold))
                            .accessibilityIdentifier("workspace-board-title")

                        Picker(
                            Strings.t("board.selector.label"),
                            selection: Binding<String?>(
                                get: { board.selectedBoardID },
                                set: { selectedID in
                                    guard let selectedID else { return }
                                    Task { await board.selectBoard(boardID: selectedID) }
                                }
                            )
                        ) {
                            ForEach(board.boards, id: \.id) { boardOption in
                                Text(boardOption.title).tag(Optional(boardOption.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 260, alignment: .leading)
                        .disabled(board.isLoading || board.boards.isEmpty)
                        .accessibilityIdentifier("board-selector-picker")
                    }

                    Spacer()

                    Button("board.create") {
                        isCreateBoardSheetPresented = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(board.isLoading)
                    .accessibilityIdentifier("board-create-button")

                    Button("board.column.reorder.mode.enter") {
                        isEditBoardSheetPresented = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(!board.canMutateBoardActions)
                    .accessibilityIdentifier("board-edit-mode-toggle")

                    Button("board.settings") {
                        isSettingsSheetPresented = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("board-settings-button")
                }

                Text(Strings.f("loggedin.subtitle", auth.signedInEmail))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    TextField("board.column.add.placeholder", text: $newColumnTitle)
                        .textFieldStyle(.roundedBorder)

                    Button("board.column.add.submit") {
                        let title = newColumnTitle
                        newColumnTitle = ""
                        Task { await board.createColumn(title: title) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!board.canMutateBoardActions)
                }

                GeometryReader { geometry in
                    let taskListMaxHeight = max(
                        WorkspaceLayout.taskListMinHeight,
                        geometry.size.height - WorkspaceLayout.reservedVerticalChromeHeight
                    )

                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(board.columns, id: \.id) { column in
                                ColumnCard(
                                    column: column,
                                    tasks: board.tasks(for: column.id),
                                    taskListMaxHeight: taskListMaxHeight,
                                    isEnabled: board.canMutateBoardActions,
                                    onRename: { editingColumn = EditableColumn(column: column) },
                                    onDelete: {
                                        pendingColumnDeletion = EditableColumn(column: column)
                                    },
                                    onAddTask: { creatingTaskInColumn = CreateTaskTarget(columnID: column.id) },
                                    onEditTask: { task in editingTask = EditableTask(columnID: column.id, task: task) },
                                    onDeleteTask: { task in
                                        pendingTaskDeletion = EditableTask(columnID: column.id, task: task)
                                    },
                                    taskControlVisibility: taskControlVisibility,
                                    selectedTaskID: selectedTaskID,
                                    onSelectTask: { taskID in selectedTaskID = taskID },
                                    onMoveTask: { taskID, destinationColumnID, destinationPosition in
                                        Task {
                                            await board.moveTask(
                                                taskID: taskID,
                                                destinationColumnID: destinationColumnID,
                                                destinationPosition: destinationPosition
                                            )
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                if !board.statusMessage.isEmpty {
                    Text(board.statusMessage)
                        .font(.caption)
                        .foregroundStyle(board.statusIsError ? .red : .green)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("board-status-message")
                }

                if board.statusIsError || !board.debugMessage.isEmpty {
                    DisclosureGroup(Strings.t("board.dev.title")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Spacer()
                                Button(Strings.t("board.dev.copy")) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(devDiagnosticText, forType: .string)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            Text(Strings.f("board.dev.base_url", auth.currentAPIBaseURL()?.absoluteString ?? "(nil)"))
                                .font(.caption.monospaced())
                                .textSelection(.enabled)

                            if let boardID = board.board?.id {
                                Text(Strings.f("board.dev.board_id", boardID))
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }

                            if !board.debugMessage.isEmpty {
                                Text(board.debugMessage)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .font(.caption)
                    .accessibilityIdentifier("board-dev-diagnostics")
                }

                Spacer(minLength: 0)
            }
            .allowsHitTesting(!board.isLoading)

            if board.isLoading {
                BlockingLoadingOverlay(
                    message: Strings.t("board.loading"),
                    accessibilityID: "board-loading-overlay"
                )
            }
        }
        .padding(24)
        .frame(minWidth: 980, minHeight: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            WorkspaceKeyMonitor { event in
                handleTaskShortcutKey(event: event)
            }
        )
        .task {
            resetTaskControlDefaultsForUITestsIfRequested()
            await board.loadBoardIfNeeded()
        }
        .onChange(of: board.board?.id, perform: { _ in
            selectedTaskID = nil
        })
        .onChange(of: board.columns, perform: { _ in
            guard let selectedTaskID else { return }
            if taskDetails(for: selectedTaskID) == nil {
                self.selectedTaskID = nil
            }
        })
        .sheet(item: $editingColumn) { item in
            ColumnEditorSheet(
                title: Strings.t("board.column.edit.title"),
                submitLabel: Strings.t("board.column.edit.submit"),
                initialTitle: item.title,
                onSubmit: { title in
                    Task { await board.renameColumn(columnID: item.id, title: title) }
                }
            )
        }
        .sheet(isPresented: $isCreateBoardSheetPresented) {
            BoardEditorSheet(
                title: Strings.t("board.create.title"),
                submitLabel: Strings.t("board.create.submit"),
                initialTitle: "",
                onSubmit: { title in
                    await board.createBoard(title: title)
                }
            )
        }
        .sheet(isPresented: $isEditBoardSheetPresented) {
            BoardEditSheet(
                board: board.board,
                columns: board.columns,
                canMutateBoardActions: board.canMutateBoardActions,
                canDeleteBoard: board.canDeleteActiveBoard,
                onRenameBoard: { title in
                    await board.renameActiveBoard(title: title)
                },
                onReorderColumns: { orderedColumnIDs in
                    await board.reorderColumns(orderedColumnIDs: orderedColumnIDs)
                },
                onArchiveBoard: {
                    await board.archiveActiveBoard()
                },
                onDeleteBoard: {
                    await board.deleteActiveBoard()
                }
            )
        }
        .sheet(
            isPresented: $isSettingsSheetPresented
        ) {
            WorkspaceSettingsSheet(
                canRefresh: board.canMutateBoardActions,
                activeBoards: board.boards,
                archivedBoards: board.archivedBoards,
                onRefresh: {
                    isSettingsSheetPresented = false
                    Task { await board.reloadBoard() }
                },
                onExport: {
                    isSettingsSheetPresented = false
                    presentExportSelection()
                },
                onImport: {
                    isSettingsSheetPresented = false
                    Task { @MainActor in
                        await presentImportSelection()
                    }
                },
                onSignOut: {
                    isSettingsSheetPresented = false
                    onSignOut()
                },
                onRestoreArchivedBoard: { boardID, titleMode in
                    Task { await board.restoreArchivedBoard(boardID: boardID, titleMode: titleMode) }
                },
                onDeleteArchivedBoard: { boardID in
                    Task { await board.deleteArchivedBoard(boardID: boardID) }
                },
                taskControlVisibility: taskControlVisibilityBindings
            )
        }
        .sheet(item: $exportSelectionSheet) { sheet in
            BoardTransferSelectionSheet(
                accessibilityPrefix: "board-transfer-export",
                titleKey: "board.transfer.export.selection.title",
                subtitleKey: "board.transfer.export.selection.subtitle",
                submitKey: "board.transfer.export.selection.submit",
                initialBoards: sheet.boards,
                onSubmit: { selectedBoardIDs in
                    exportSelectionSheet = nil
                    exportTasksFromSettings(includedBoardIDs: selectedBoardIDs)
                }
            )
        }
        .sheet(item: $importSelectionSheet) { sheet in
            BoardTransferSelectionSheet(
                accessibilityPrefix: "board-transfer-import",
                titleKey: "board.transfer.import.selection.title",
                subtitleKey: "board.transfer.import.selection.subtitle",
                submitKey: "board.transfer.import.selection.submit",
                initialBoards: sheet.boards,
                onSubmit: { selectedBoardIDs in
                    importSelectionSheet = nil
                    Task { @MainActor in
                        await board.importTasks(from: sheet.fileURL, includedSourceBoardIDs: selectedBoardIDs)
                    }
                }
            )
        }
        .sheet(item: $creatingTaskInColumn) { target in
            TaskEditorSheet(
                title: Strings.t("board.task.create.title"),
                submitLabel: Strings.t("board.task.create.submit"),
                initialTitle: "",
                initialDescription: "",
                onSubmit: { title, description in
                    Task { await board.createTask(columnID: target.columnID, title: title, description: description) }
                }
            )
        }
        .sheet(item: $editingTask) { item in
            TaskEditorSheet(
                title: Strings.t("board.task.edit.title"),
                submitLabel: Strings.t("board.task.edit.submit"),
                initialTitle: item.title,
                initialDescription: item.description,
                onSubmit: { title, description in
                    Task { await board.updateTask(taskID: item.id, title: title, description: description) }
                }
            )
        }
        .confirmationDialog(
            Strings.t("board.column.delete.confirm.title"),
            isPresented: Binding(
                get: { pendingColumnDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingColumnDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(Strings.t("board.column.delete.confirm.action"), role: .destructive) {
                guard let column = pendingColumnDeletion else { return }
                Task { await board.deleteColumn(columnID: column.id) }
                pendingColumnDeletion = nil
            }
            Button(Strings.t("common.cancel"), role: .cancel) {
                pendingColumnDeletion = nil
            }
        } message: {
            if let column = pendingColumnDeletion {
                Text(Strings.f("board.column.delete.confirm.message", column.title))
            }
        }
        .confirmationDialog(
            Strings.t("board.task.delete.confirm.title"),
            isPresented: Binding(
                get: { pendingTaskDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingTaskDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(Strings.t("board.task.delete.confirm.action"), role: .destructive) {
                guard let task = pendingTaskDeletion else { return }
                Task { await board.deleteTask(taskID: task.id) }
                pendingTaskDeletion = nil
            }
            .accessibilityIdentifier("task-delete-confirm-action")
            Button(Strings.t("common.cancel"), role: .cancel) {
                pendingTaskDeletion = nil
            }
            .accessibilityIdentifier("task-delete-confirm-cancel")
        } message: {
            if let task = pendingTaskDeletion {
                Text(Strings.f("board.task.delete.confirm.message", task.title))
            }
        }
    }

    private struct SelectedTaskDetails {
        let taskID: String
        let columnID: String
        let task: KanbanTask
        let index: Int
        let taskCount: Int
    }

    private enum TaskShortcutAction {
        case clearSelection
        case moveTop
        case moveBottom
        case moveUp
        case moveDown
        case edit
        case delete

        init?(event: NSEvent) {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.isEmpty else { return nil }

            if event.charactersIgnoringModifiers == "\u{1B}" {
                self = .clearSelection
                return
            }

            guard let key = event.charactersIgnoringModifiers?.lowercased() else { return nil }
            switch key {
            case "t": self = .moveTop
            case "b": self = .moveBottom
            case "u": self = .moveUp
            case "d": self = .moveDown
            case "e": self = .edit
            case "x": self = .delete
            default: return nil
            }
        }
    }

    private func taskDetails(for taskID: String) -> SelectedTaskDetails? {
        for column in board.columns {
            let tasks = board.tasks(for: column.id)
            if let index = tasks.firstIndex(where: { $0.id == taskID }) {
                return SelectedTaskDetails(taskID: taskID, columnID: column.id, task: tasks[index], index: index, taskCount: tasks.count)
            }
        }
        return nil
    }

    private func withSelectedTaskDetails(_ action: (SelectedTaskDetails) -> Bool) -> Bool {
        guard board.canMutateBoardActions, let selectedTaskID, let details = taskDetails(for: selectedTaskID) else {
            return false
        }
        return action(details)
    }

    private func withEditableSelectedTaskDetails(_ action: (SelectedTaskDetails) -> Bool) -> Bool {
        guard pendingTaskDeletion == nil, editingTask == nil else { return false }
        return withSelectedTaskDetails(action)
    }

    private func moveSelectedTaskUp() -> Bool {
        withSelectedTaskDetails { details in
            guard details.index > 0 else { return false }
            Task {
                await board.moveTask(
                    taskID: details.taskID,
                    destinationColumnID: details.columnID,
                    destinationPosition: details.index - 1
                )
            }
            return true
        }
    }

    private func moveSelectedTaskDown() -> Bool {
        withSelectedTaskDetails { details in
            guard details.index < (details.taskCount - 1) else { return false }
            Task {
                await board.moveTask(
                    taskID: details.taskID,
                    destinationColumnID: details.columnID,
                    destinationPosition: details.index + 1
                )
            }
            return true
        }
    }

    private func moveSelectedTaskToTop() -> Bool {
        withSelectedTaskDetails { details in
            guard details.index > 0 else { return false }
            Task {
                await board.moveTask(taskID: details.taskID, destinationColumnID: details.columnID, destinationPosition: 0)
            }
            return true
        }
    }

    private func moveSelectedTaskToBottom() -> Bool {
        withSelectedTaskDetails { details in
            guard details.index < (details.taskCount - 1) else { return false }
            Task {
                await board.moveTask(
                    taskID: details.taskID,
                    destinationColumnID: details.columnID,
                    destinationPosition: details.taskCount
                )
            }
            return true
        }
    }

    private func editSelectedTask() -> Bool {
        withEditableSelectedTaskDetails { details in
            editingTask = EditableTask(columnID: details.columnID, task: details.task)
            return true
        }
    }

    private func deleteSelectedTask() -> Bool {
        withEditableSelectedTaskDetails { details in
            pendingTaskDeletion = EditableTask(columnID: details.columnID, task: details.task)
            return true
        }
    }

    private func handleTaskShortcutKey(event: NSEvent) -> Bool {
        guard let action = TaskShortcutAction(event: event) else { return false }

        switch action {
        case .clearSelection:
            guard selectedTaskID != nil else { return false }
            selectedTaskID = nil
            return true
        case .moveTop:
            return moveSelectedTaskToTop()
        case .moveBottom:
            return moveSelectedTaskToBottom()
        case .moveUp:
            return moveSelectedTaskUp()
        case .moveDown:
            return moveSelectedTaskDown()
        case .edit:
            return editSelectedTask()
        case .delete:
            return deleteSelectedTask()
        }
    }

    private var devDiagnosticText: String {
        var lines: [String] = [
            Strings.f("board.dev.base_url", auth.currentAPIBaseURL()?.absoluteString ?? "(nil)")
        ]

        if let boardID = board.board?.id {
            lines.append(Strings.f("board.dev.board_id", boardID))
        }

        if !board.statusMessage.isEmpty {
            lines.append("status=\(board.statusMessage)")
        }

        if !board.debugMessage.isEmpty {
            lines.append(board.debugMessage)
        }

        return lines.joined(separator: "\n")
    }

    private func presentExportSelection() {
        let items = board.boards.map {
            BoardTransferSelectionItem(id: $0.id, title: $0.title)
        }
        guard !items.isEmpty else {
            return
        }
        exportSelectionSheet = BoardExportSelectionSheetState(boards: items)
    }

    private func presentImportSelection() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.title = Strings.t("board.import.panel.title")
        panel.prompt = Strings.t("board.import.panel.submit")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        guard let snapshots = await board.importSnapshots(from: url) else {
            return
        }
        let items = snapshots.map {
            BoardTransferSelectionItem(id: $0.sourceBoardID, title: $0.sourceBoardTitle)
        }
        guard !items.isEmpty else {
            return
        }
        importSelectionSheet = BoardImportSelectionSheetState(fileURL: url, boards: items)
    }

    @MainActor
    private func exportTasksFromSettings(includedBoardIDs: [String]) {
        NSApp.activate(ignoringOtherApps: true)

        // NOTE: Keep runModal for export panel.
        // The sheet-based variants were stable in UI tests but flaky in real app builds
        // (panel flashing/disappearing or not showing). Until we have a build-reproducible
        // fix, preserve this implementation to avoid user-facing regressions.
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "board-tasks.json"
        panel.title = Strings.t("board.export.panel.title")
        panel.prompt = Strings.t("board.export.panel.submit")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task { @MainActor in
            await board.exportTasks(to: url, includedBoardIDs: includedBoardIDs)
        }
    }
}

private struct BlockingLoadingOverlay: View {
    let message: String
    let accessibilityID: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.08)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .accessibilityIdentifier(accessibilityID)
    }
}

private struct WorkspaceSettingsSheet: View {
    let canRefresh: Bool
    let activeBoards: [KanbanBoard]
    let archivedBoards: [KanbanBoard]
    let onRefresh: () -> Void
    let onExport: () -> Void
    let onImport: () -> Void
    let onSignOut: () -> Void
    let onRestoreArchivedBoard: (String, RestoreBoardTitleMode) -> Void
    let onDeleteArchivedBoard: (String) -> Void
    let taskControlVisibility: TaskControlVisibilityBindings

    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeleteArchivedBoard: KanbanBoard?
    @State private var restoreSheetState: RestoreArchivedBoardSheetState?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("board.settings.title")
                .font(.title3.weight(.semibold))

            Text("board.settings.subtitle")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("board.refresh", action: onRefresh)
                .buttonStyle(.bordered)
                .disabled(!canRefresh)
                .accessibilityIdentifier("board-refresh-button")

            Button("loggedin.signout", action: onSignOut)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("board-settings-signout-button")

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("board.settings.transfer.title")
                    .font(.headline)

                Button("board.settings.transfer.export", action: onExport)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("board-settings-export-button")

                Button("board.settings.transfer.import", action: onImport)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("board-settings-import-button")
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("board.settings.shortcuts.title")
                    .font(.headline)
                    .accessibilityIdentifier("board-settings-shortcuts-title")

                Text("board.settings.shortcuts.select")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("board-settings-shortcuts-select")

                Text("board.settings.shortcuts.clear")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("board-settings-shortcuts-clear")

                Text("board.settings.shortcuts.top_bottom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("board-settings-shortcuts-top-bottom")

                Text("board.settings.shortcuts.up_down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("board-settings-shortcuts-up-down")

                Text("board.settings.shortcuts.edit_delete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("board-settings-shortcuts-edit-delete")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("board-settings-shortcuts-section")

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("board.settings.task_controls.title")
                    .font(.headline)
                    .accessibilityIdentifier("board-settings-task-controls-title")

                Toggle("board.settings.task_controls.top_bottom", isOn: taskControlVisibility.showsTopBottom)
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("board-settings-task-controls-top-bottom")

                Toggle("board.settings.task_controls.up_down", isOn: taskControlVisibility.showsUpDown)
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("board-settings-task-controls-up-down")

                Toggle("board.settings.task_controls.edit_delete", isOn: taskControlVisibility.showsEditDelete)
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("board-settings-task-controls-edit-delete")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("board-settings-task-controls-section")

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("board.settings.archived.title")
                    .font(.headline)

                if archivedBoards.isEmpty {
                    Text("board.settings.archived.empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(archivedBoards.enumerated()), id: \.element.id) { index, archivedBoard in
                        HStack(alignment: .firstTextBaseline) {
                            Text(archivedBoard.title)
                                .lineLimit(1)
                                .layoutPriority(1)
                            Spacer()
                            Button("board.restore") {
                                restoreSheetState = RestoreArchivedBoardSheetState(board: archivedBoard)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canRefresh)
                            .accessibilityIdentifier("board-archived-restore-row-\(index)")

                            Button("board.delete", role: .destructive) {
                                pendingDeleteArchivedBoard = archivedBoard
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canRefresh)
                            .accessibilityIdentifier("board-archived-delete-row-\(index)")
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("common.close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("board-settings-close-button")
            }
        }
        .padding(20)
        .frame(minWidth: 520, idealWidth: 560)
        .accessibilityIdentifier("board-settings-sheet")
        .confirmationDialog(
            Strings.t("board.archived.delete.confirm.title"),
            isPresented: Binding(
                get: { pendingDeleteArchivedBoard != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeleteArchivedBoard = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(Strings.t("board.archived.delete.confirm.action"), role: .destructive) {
                guard let board = pendingDeleteArchivedBoard else { return }
                onDeleteArchivedBoard(board.id)
                pendingDeleteArchivedBoard = nil
            }
            .accessibilityIdentifier("board-archived-delete-confirm-action")
            Button(Strings.t("common.cancel"), role: .cancel) {
                pendingDeleteArchivedBoard = nil
            }
            .accessibilityIdentifier("board-archived-delete-confirm-cancel")
        } message: {
            if let board = pendingDeleteArchivedBoard {
                Text(Strings.f("board.archived.delete.confirm.message", board.title))
            }
        }
        .sheet(item: $restoreSheetState) { state in
            ArchivedBoardRestoreSheet(
                board: state.board,
                activeBoards: activeBoards,
                onSubmit: { mode in
                    onRestoreArchivedBoard(state.board.id, mode)
                }
            )
        }
    }
}

private struct RestoreArchivedBoardSheetState: Identifiable {
    let id = UUID()
    let board: KanbanBoard
}

private struct ArchivedBoardRestoreSheet: View {
    let board: KanbanBoard
    let activeBoards: [KanbanBoard]
    let onSubmit: (RestoreBoardTitleMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var titleMode: RestoreBoardTitleMode = .archived

    private var originalTitle: String? {
        let value = board.archivedOriginalTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value, !value.isEmpty {
            return value
        }
        return nil
    }

    private var hasOriginalTitleConflict: Bool {
        guard titleMode == .original, let originalTitle else {
            return false
        }
        return activeBoards.contains { $0.title == originalTitle }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("board.restore.title")
                .font(.title3.weight(.semibold))

            Text(Strings.f("board.restore.message", board.title))
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker(Strings.t("board.restore.title_mode.label"), selection: $titleMode) {
                Text("board.restore.title_mode.archived")
                    .tag(RestoreBoardTitleMode.archived)
                    .accessibilityIdentifier("board-restore-title-mode-archived")
                Text("board.restore.title_mode.original")
                    .tag(RestoreBoardTitleMode.original)
                    .accessibilityIdentifier("board-restore-title-mode-original")
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("board-restore-title-mode-picker")

            if titleMode == .original {
                Text(Strings.f("board.restore.original.preview", originalTitle ?? Strings.t("board.restore.original.unavailable")))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if hasOriginalTitleConflict {
                Text("board.restore.original.conflict")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("board-restore-original-conflict")
            }

            HStack {
                Button("common.cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("board-restore-cancel-button")

                Spacer()

                Button("board.restore") {
                    onSubmit(titleMode)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasOriginalTitleConflict)
                .accessibilityIdentifier("board-restore-submit-button")
            }
        }
        .padding(20)
        .frame(width: 420)
        .accessibilityIdentifier("board-restore-sheet")
    }
}

private struct BoardTransferSelectionItem: Identifiable {
    let id: String
    let title: String
}

private struct BoardExportSelectionSheetState: Identifiable {
    let id = UUID()
    let boards: [BoardTransferSelectionItem]
}

private struct BoardImportSelectionSheetState: Identifiable {
    let id = UUID()
    let fileURL: URL
    let boards: [BoardTransferSelectionItem]
}

private struct BoardTransferSelectionSheet: View {
    let accessibilityPrefix: String
    let titleKey: String
    let subtitleKey: String
    let submitKey: String
    let initialBoards: [BoardTransferSelectionItem]
    let onSubmit: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedBoardIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(titleKey))
                .font(.title3.weight(.semibold))

            Text(LocalizedStringKey(subtitleKey))
                .font(.callout)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(initialBoards) { board in
                        Toggle(isOn: Binding(
                            get: { selectedBoardIDs.contains(board.id) },
                            set: { isEnabled in
                                if isEnabled {
                                    selectedBoardIDs.insert(board.id)
                                } else {
                                    selectedBoardIDs.remove(board.id)
                                }
                            }
                        )) {
                            Text(board.title)
                        }
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("\(accessibilityPrefix)-checkbox-\(board.id)")
                    }
                }
            }
            .frame(maxHeight: 220)
            .accessibilityIdentifier("\(accessibilityPrefix)-list")

            HStack {
                Button("common.cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("\(accessibilityPrefix)-cancel-button")

                Spacer()

                Button(LocalizedStringKey(submitKey)) {
                    let orderedSelection = initialBoards
                        .map(\.id)
                        .filter { selectedBoardIDs.contains($0) }
                    onSubmit(orderedSelection)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedBoardIDs.isEmpty)
                .accessibilityIdentifier("\(accessibilityPrefix)-submit-button")
            }
        }
        .padding(20)
        .frame(width: 420)
        .accessibilityIdentifier("\(accessibilityPrefix)-sheet")
        .onAppear {
            selectedBoardIDs = Set(initialBoards.map(\.id))
        }
    }
}

private struct WorkspaceKeyMonitor: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyMonitorNSView {
        let view = KeyMonitorNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyMonitorNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }

    final class KeyMonitorNSView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?
        private var monitor: Any?

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil {
                removeMonitor()
            }
            super.viewWillMove(toWindow: newWindow)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard window != nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard self.window?.isKeyWindow == true else { return event }
                guard self.window?.attachedSheet == nil else { return event }
                if self.isTextInputResponder(self.window?.firstResponder) {
                    return event
                }
                guard self.onKeyDown?(event) == true else { return event }
                return nil
            }
        }

        private func isTextInputResponder(_ responder: NSResponder?) -> Bool {
            guard let responder else { return false }
            return responder is NSTextView || responder is NSTextField
        }

        private func removeMonitor() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

    }
}

private struct ColumnCard: View {
    let column: KanbanColumn
    let tasks: [KanbanTask]
    let taskListMaxHeight: CGFloat
    let isEnabled: Bool
    let onRename: () -> Void
    let onDelete: () -> Void
    let onAddTask: () -> Void
    let onEditTask: (KanbanTask) -> Void
    let onDeleteTask: (KanbanTask) -> Void
    let taskControlVisibility: TaskControlVisibility
    let selectedTaskID: String?
    let onSelectTask: (String) -> Void
    let onMoveTask: (String, String, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(column.title)
                    .font(.headline)
                    .accessibilityIdentifier("column-title-\(column.id)")
                Spacer()
                Text(Strings.f("board.column.task_count", tasks.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("column-task-count-\(column.id)")
            }

            HStack(spacing: 8) {
                Button("board.column.rename", action: onRename)
                    .buttonStyle(.bordered)
                    .disabled(!isEnabled)
                Button("board.column.delete", action: onDelete)
                    .buttonStyle(.bordered)
                    .disabled(!isEnabled)
                    .accessibilityIdentifier("column-delete-\(column.id)")
            }

            Divider()

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        TaskCardView(
                            task: task,
                            index: index,
                            taskCount: tasks.count,
                            isEnabled: isEnabled,
                            onEditTask: onEditTask,
                            onDeleteTask: onDeleteTask,
                            taskControlVisibility: taskControlVisibility,
                            isSelected: selectedTaskID == task.id,
                            onSelectTask: onSelectTask,
                            onMoveToPosition: { position in
                                onMoveTask(task.id, column.id, position)
                            },
                            onDropTask: { draggedTaskID in
                                onMoveTask(draggedTaskID, column.id, task.position)
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: taskListMaxHeight)
            .accessibilityIdentifier("column-task-list-\(column.id)")

            Button("board.task.add", action: onAddTask)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!isEnabled)
                .accessibilityIdentifier("task-add-\(column.id)")
        }
        .padding(12)
        .frame(width: 280, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(Color(NSColor.windowBackgroundColor))
        .dropDestination(for: TaskDragItem.self) { items, _ in
            guard let item = items.first else { return false }
            let destinationPosition: Int
            if tasks.contains(where: { $0.id == item.taskID }) {
                destinationPosition = max(0, tasks.count - 1)
            } else {
                destinationPosition = tasks.count
            }
            onMoveTask(item.taskID, column.id, destinationPosition)
            return true
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(tasks.count)")
        .accessibilityIdentifier("column-drop-zone-\(column.id)")
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct TaskCardView: View {
    let task: KanbanTask
    let index: Int
    let taskCount: Int
    let isEnabled: Bool
    let onEditTask: (KanbanTask) -> Void
    let onDeleteTask: (KanbanTask) -> Void
    let taskControlVisibility: TaskControlVisibility
    let isSelected: Bool
    let onSelectTask: (String) -> Void
    let onMoveToPosition: (Int) -> Void
    let onDropTask: (String) -> Void

    private var isFirstTask: Bool { index == 0 }
    private var isLastTask: Bool { index == taskCount - 1 }
    private var topPosition: Int { 0 }
    private var bottomPosition: Int { taskCount }
    private var upPosition: Int { max(0, index - 1) }
    private var downPosition: Int { min(taskCount - 1, index + 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if taskControlVisibility.showsTopBottom {
                HStack(spacing: 8) {
                    Button("board.task.move_top") {
                        onMoveToPosition(topPosition)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isEnabled || isFirstTask)
                    .accessibilityIdentifier("task-move-top-\(task.id)")

                    Spacer(minLength: 0)

                    Button("board.task.move_bottom") {
                        onMoveToPosition(bottomPosition)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isEnabled || isLastTask)
                    .accessibilityIdentifier("task-move-bottom-\(task.id)")
                }
            }

            Text(task.title)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("task-title-\(task.id)")
            if !task.description.isEmpty {
                Text(task.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if taskControlVisibility.showsUpDown || taskControlVisibility.showsEditDelete {
                HStack(spacing: 8) {
                    if taskControlVisibility.showsUpDown {
                        Button("board.task.move_up") {
                            onMoveToPosition(upPosition)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isEnabled || isFirstTask)
                        .accessibilityIdentifier("task-move-up-\(task.id)")

                        Button("board.task.move_down") {
                            onMoveToPosition(downPosition)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isEnabled || isLastTask)
                        .accessibilityIdentifier("task-move-down-\(task.id)")
                    }

                    if taskControlVisibility.showsEditDelete {
                        Button("board.task.edit") { onEditTask(task) }
                            .buttonStyle(.bordered)
                            .disabled(!isEnabled)
                            .accessibilityIdentifier("task-edit-\(task.id)")
                        Button("board.task.delete") { onDeleteTask(task) }
                            .buttonStyle(.bordered)
                            .disabled(!isEnabled)
                            .accessibilityIdentifier("task-delete-\(task.id)")
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task-card-\(task.id)")
        .accessibilityValue(isSelected ? "selected" : "unselected")
        .onTapGesture {
            onSelectTask(task.id)
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .draggable(TaskDragItem(taskID: task.id))
        .dropDestination(for: TaskDragItem.self) { items, _ in
            guard let item = items.first else { return false }
            onDropTask(item.taskID)
            return true
        }
    }
}

private struct BoardEditSheet: View {
    let board: KanbanBoard?
    let columns: [KanbanColumn]
    let canMutateBoardActions: Bool
    let canDeleteBoard: Bool
    let onRenameBoard: @Sendable (String) async -> Bool
    let onReorderColumns: @Sendable ([String]) async -> Bool
    let onArchiveBoard: @Sendable () async -> Bool
    let onDeleteBoard: @Sendable () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var editingBoard: EditableBoard?
    @State private var isReorderSheetPresented = false
    @State private var reorderSheetColumns: [KanbanColumn] = []
    @State private var isApplyingReorder = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("board.column.reorder.mode.enter")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                Button("board.rename") {
                    guard let board else { return }
                    editingBoard = EditableBoard(board: board)
                }
                    .buttonStyle(.bordered)
                    .disabled(!canMutateBoardActions)
                    .accessibilityIdentifier("board-edit-rename-button")

                Button("board.column.reorder.title") {
                    reorderSheetColumns = columns
                    isReorderSheetPresented = true
                }
                    .buttonStyle(.bordered)
                    .disabled(!canMutateBoardActions)
                    .accessibilityIdentifier("board-edit-reorder-button")

                Button("board.archive") {
                    Task {
                        if await onArchiveBoard() {
                            dismiss()
                        }
                    }
                }
                    .buttonStyle(.bordered)
                    .disabled(!canMutateBoardActions)
                    .accessibilityIdentifier("board-edit-archive-button")

                Button("board.delete", role: .destructive) {
                    isDeleteConfirmationPresented = true
                }
                    .buttonStyle(.bordered)
                    .disabled(!canMutateBoardActions || !canDeleteBoard)
                    .accessibilityIdentifier("board-edit-delete-button")

                if !canDeleteBoard {
                    Text("board.delete.disabled.has_tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("board-edit-delete-disabled-message")
                }
            }

            HStack {
                Spacer()
                Button("common.close") { dismiss() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("board-edit-close-button")
            }
        }
        .padding(20)
        .frame(width: 420)
        .accessibilityElement(children: .contain)
        .sheet(item: $editingBoard) { item in
            BoardEditorSheet(
                title: Strings.t("board.rename.title"),
                submitLabel: Strings.t("board.rename.submit"),
                initialTitle: item.title,
                onSubmit: onRenameBoard
            )
        }
        .confirmationDialog(
            Strings.t("board.delete.confirm.title"),
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(Strings.t("board.delete.confirm.action"), role: .destructive) {
                Task {
                    if await onDeleteBoard() {
                        dismiss()
                    }
                }
            }
            Button(Strings.t("common.cancel"), role: .cancel) {}
        } message: {
            if let board {
                Text(Strings.f("board.delete.confirm.message", board.title))
            }
        }
        .sheet(isPresented: $isReorderSheetPresented) {
            ColumnReorderSheet(
                columns: $reorderSheetColumns,
                isApplying: isApplyingReorder,
                onCancel: {
                    guard !isApplyingReorder else { return }
                    isReorderSheetPresented = false
                },
                onDone: {
                    guard !isApplyingReorder else { return }
                    isApplyingReorder = true
                    Task {
                        defer { isApplyingReorder = false }
                        if await onReorderColumns(reorderSheetColumns.map(\.id)) {
                            isReorderSheetPresented = false
                        }
                    }
                }
            )
        }
    }
}

private struct ColumnReorderSheet: View {
    @Binding var columns: [KanbanColumn]
    let isApplying: Bool
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("board.column.reorder.title")
                .font(.title3.weight(.semibold))
            Text("board.column.reorder.subtitle")
                .font(.callout)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(columns, id: \.id) { column in
                        reorderTile(for: column)
                    }
                }
                .padding(.vertical, 2)
            }
            .accessibilityIdentifier("board-reorder-row")

            HStack {
                Spacer()
                Button("common.cancel", action: onCancel)
                    .disabled(isApplying)
                Button("board.column.reorder.done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .disabled(isApplying)
                    .accessibilityIdentifier("board-reorder-done")
            }
        }
        .padding(20)
        .frame(width: 680)
        .overlay(alignment: .topTrailing) {
            if isApplying {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
        .accessibilityIdentifier("board-reorder-sheet")
    }

    @ViewBuilder
    private func reorderTile(for column: KanbanColumn) -> some View {
        let index = columns.firstIndex(where: { $0.id == column.id }) ?? 0
        let canMoveLeft = index > 0
        let canMoveRight = index < columns.count - 1

        VStack(alignment: .leading, spacing: 8) {
            Text(column.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 6) {
                Button("board.column.move_left") {
                    moveColumnLocally(from: index, to: index - 1)
                }
                .buttonStyle(.bordered)
                .disabled(!canMoveLeft || isApplying)
                .accessibilityLabel(Text("board.column.move_left.accessibility"))
                .accessibilityIdentifier("board-reorder-move-left-\(column.id)")

                Button("board.column.move_right") {
                    moveColumnLocally(from: index, to: index + 1)
                }
                .buttonStyle(.bordered)
                .disabled(!canMoveRight || isApplying)
                .accessibilityLabel(Text("board.column.move_right.accessibility"))
                .accessibilityIdentifier("board-reorder-move-right-\(column.id)")
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .draggable(ColumnDragItem(columnID: column.id))
        .dropDestination(for: ColumnDragItem.self) { items, _ in
            guard let sourceID = items.first?.columnID else { return false }
            guard
                let sourceIndex = columns.firstIndex(where: { $0.id == sourceID }),
                let destinationIndex = columns.firstIndex(where: { $0.id == column.id }),
                sourceIndex != destinationIndex
            else {
                return false
            }
            moveColumnLocally(from: sourceIndex, to: destinationIndex)
            return true
        }
    }

    private func moveColumnLocally(from source: Int, to destination: Int) {
        guard let reordered = reorderedColumns(columns, from: source, to: destination) else {
            return
        }
        columns = reordered
    }
}

private struct ColumnEditorSheet: View {
    let title: String
    let submitLabel: String
    let initialTitle: String
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inputTitle: String

    init(title: String, submitLabel: String, initialTitle: String, onSubmit: @escaping (String) -> Void) {
        self.title = title
        self.submitLabel = submitLabel
        self.initialTitle = initialTitle
        self.onSubmit = onSubmit
        _inputTitle = State(initialValue: initialTitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
            TextField("board.column.add.placeholder", text: $inputTitle)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("common.cancel") { dismiss() }
                Button(submitLabel) {
                    onSubmit(inputTitle)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

private struct TaskEditorSheet: View {
    let title: String
    let submitLabel: String
    let initialTitle: String
    let initialDescription: String
    let onSubmit: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inputTitle: String
    @State private var inputDescription: String

    init(title: String, submitLabel: String, initialTitle: String, initialDescription: String, onSubmit: @escaping (String, String) -> Void) {
        self.title = title
        self.submitLabel = submitLabel
        self.initialTitle = initialTitle
        self.initialDescription = initialDescription
        self.onSubmit = onSubmit
        _inputTitle = State(initialValue: initialTitle)
        _inputDescription = State(initialValue: initialDescription)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("task-editor-title")

            TextField("board.task.title.placeholder", text: $inputTitle)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("task-editor-title-input")

            TextEditor(text: $inputDescription)
                .font(.body)
                .frame(height: 110)
                .accessibilityIdentifier("task-editor-description-input")
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("common.cancel") { dismiss() }
                    .accessibilityIdentifier("task-editor-cancel")
                Button(submitLabel) {
                    onSubmit(inputTitle, inputDescription)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("task-editor-submit")
            }
        }
        .padding(20)
        .frame(width: 460)
        .accessibilityIdentifier("task-editor-sheet")
    }
}

private struct BoardEditorSheet: View {
    let title: String
    let submitLabel: String
    let initialTitle: String
    let onSubmit: @Sendable (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var inputTitle: String
    @State private var isSubmitting = false

    init(title: String, submitLabel: String, initialTitle: String, onSubmit: @escaping @Sendable (String) async -> Bool) {
        self.title = title
        self.submitLabel = submitLabel
        self.initialTitle = initialTitle
        self.onSubmit = onSubmit
        _inputTitle = State(initialValue: initialTitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
            TextField("board.input.placeholder", text: $inputTitle)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("board-editor-title-input")
            HStack {
                Spacer()
                Button("common.cancel") { dismiss() }
                    .disabled(isSubmitting)
                Button(submitLabel) {
                    isSubmitting = true
                    Task {
                        let succeeded = await onSubmit(inputTitle)
                        await MainActor.run {
                            isSubmitting = false
                            if succeeded {
                                dismiss()
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .accessibilityIdentifier("board-editor-submit")
            }
        }
        .padding(20)
        .frame(width: 420)
        .accessibilityIdentifier("board-editor-sheet")
    }
}

private struct EditableColumn: Identifiable {
    let id: String
    let title: String

    init(column: KanbanColumn) {
        id = column.id
        title = column.title
    }
}

private struct EditableBoard: Identifiable {
    let id: String
    let title: String

    init(board: KanbanBoard) {
        id = board.id
        title = board.title
    }
}

private struct EditableTask: Identifiable {
    let id: String
    let columnID: String
    let title: String
    let description: String

    init(columnID: String, task: KanbanTask) {
        id = task.id
        self.columnID = columnID
        title = task.title
        description = task.description
    }
}

private struct CreateTaskTarget: Identifiable {
    let columnID: String
    var id: String { columnID }
}

private struct TaskDragItem: Transferable {
    let taskID: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(
            contentType: TaskDragPayload.type,
            exporting: { item in encodedPayload(for: item.taskID) },
            importing: { data in TaskDragItem(taskID: try decodeTaskID(from: data)) }
        )
        DataRepresentation(
            contentType: .data,
            exporting: { item in encodedPayload(for: item.taskID) },
            importing: { data in TaskDragItem(taskID: try decodeTaskID(from: data)) }
        )
    }

    private static func encodedPayload(for taskID: String) -> Data {
        Data("\(TaskDragPayload.payloadPrefix)\(taskID)".utf8)
    }

    private static func decodeTaskID(from data: Data) throws -> String {
        guard
            let payload = String(data: data, encoding: .utf8),
            payload.hasPrefix(TaskDragPayload.payloadPrefix)
        else {
            throw TaskDragItemTransferError.invalidPayload
        }

        let taskID = String(payload.dropFirst(TaskDragPayload.payloadPrefix.count))
        guard !taskID.isEmpty else {
            throw TaskDragItemTransferError.invalidPayload
        }
        return taskID
    }
}

private struct ColumnDragItem: Transferable {
    let columnID: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(
            contentType: ColumnDragPayload.type,
            exporting: { item in encodedPayload(for: item.columnID) },
            importing: { data in ColumnDragItem(columnID: try decodeColumnID(from: data)) }
        )
    }

    private static func encodedPayload(for columnID: String) -> Data {
        Data("\(ColumnDragPayload.payloadPrefix)\(columnID)".utf8)
    }

    private static func decodeColumnID(from data: Data) throws -> String {
        guard
            let payload = String(data: data, encoding: .utf8),
            payload.hasPrefix(ColumnDragPayload.payloadPrefix)
        else {
            throw ColumnDragItemTransferError.invalidPayload
        }

        let columnID = String(payload.dropFirst(ColumnDragPayload.payloadPrefix.count))
        guard !columnID.isEmpty else {
            throw ColumnDragItemTransferError.invalidPayload
        }
        return columnID
    }
}

private enum TaskDragItemTransferError: Error {
    case invalidPayload
}

private enum ColumnDragItemTransferError: Error {
    case invalidPayload
}

private enum TaskDragPayload {
    static let prefix = "todo-task"
    static let sessionToken = UUID().uuidString.lowercased()
    static let payloadPrefix = "\(prefix):\(sessionToken):"
    static let type = UTType(exportedAs: "com.todo.task-id", conformingTo: .data)
}

private enum ColumnDragPayload {
    static let prefix = "todo-column"
    static let sessionToken = UUID().uuidString.lowercased()
    static let payloadPrefix = "\(prefix):\(sessionToken):"
    static let type = UTType(exportedAs: "com.todo.column-id", conformingTo: .data)
}

#Preview {
    ContentView()
}
