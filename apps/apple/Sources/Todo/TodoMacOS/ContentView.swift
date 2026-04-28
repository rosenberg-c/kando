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
    @State private var isSignedOutDevPanelPresented = false
    private let processEnvironment = ProcessInfo.processInfo.environment
    private var configuredDevUsers: [RuntimeFlags.DevUser] {
        RuntimeFlags.devUsers(environment: processEnvironment)
    }

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
        .overlay(alignment: .topLeading) {
            if !auth.isSignedIn {
                Color.clear
                    .frame(width: 64, height: 40)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSignedOutDevPanelPresented = true
                    }
                    .accessibilityIdentifier("workspace-dev-panel-hit-area")
            }
        }
        .sheet(isPresented: $isSignedOutDevPanelPresented) {
            DevPanelSheet(
                backendStorage: RuntimeFlags.resolvedBackendStorage(environment: processEnvironment),
                connectionStatusText: auth.isSigningIn ? Strings.t("board.dev.status.loading") : Strings.t("board.dev.status.idle"),
                baseURLText: auth.currentAPIBaseURL()?.absoluteString ?? "(nil)",
                statusMessageText: auth.statusMessage,
                devUsers: configuredDevUsers,
                isSigningIn: auth.isSigningIn,
                onDevLogin: { user in
                    isSignedOutDevPanelPresented = false
                    auth.email = user.email
                    auth.password = user.password
                    Task {
                        await auth.signIn(keepSignedIn: keepSignedIn)
                    }
                }
            )
        }
        .task {
            if processEnvironment[AppEnvironmentKey.signedIn] == "1" {
                auth.applyUITestSignedInSession(email: processEnvironment[AppEnvironmentKey.email] ?? "ui-test@example.com")
            } else if processEnvironment[AppEnvironmentKey.uiTestMode] == "1"
                || processEnvironment[AppEnvironmentKey.testMode] == "1" {
                // Keep UI tests isolated from network/session restore side effects.
                return
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
    static let showArchivedTaskActionButtons = "board.settings.task_controls.show_archived_actions"
}

private struct TaskControlVisibility {
    let showsTopBottom: Bool
    let showsUpDown: Bool
    let showsEditDelete: Bool
    let showsArchivedActions: Bool
}

private struct TaskControlVisibilityBindings {
    let showsTopBottom: Binding<Bool>
    let showsUpDown: Binding<Bool>
    let showsEditDelete: Binding<Bool>
    let showsArchivedActions: Binding<Bool>
}

private struct ColumnShortcutEntry: Identifiable {
    let key: String
    let columnID: String
    let columnTitle: String

    var id: String { columnID }
}

private enum WorkspaceColumnShortcutKeys {
    static let all = Array("asdfghjkl").map(String.init)
}

private enum WorkspaceShortcutKeyModifiers {
    static let disallowed: NSEvent.ModifierFlags = [
        .shift,
        .control,
        .option,
        .command,
        .function,
    ]

    static func allows(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return modifiers.intersection(disallowed).isEmpty
    }
}

private struct ColumnTaskActionHandlers {
    let onMoveTaskToTop: (String, String) -> Void
    let onMoveTaskToBottom: (String, String) -> Void
    let onMoveTaskUp: (String, String) -> Void
    let onMoveTaskDown: (String, String) -> Void
    let taskDragItem: (String, String) -> TaskDragItem
    let onDropTaskItem: (TaskDragItem, String, Int) -> Void
}

private enum TaskSelectionInteraction {
    case single
    case toggle
    case range

    static func current() -> TaskSelectionInteraction {
        let modifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.shift) {
            return .range
        }
        if modifiers.contains(.control) {
            return .toggle
        }
        return .single
    }
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
    @State private var pendingTaskDeletion: PendingTaskDeletion?
    @State private var viewingArchivedTask: KanbanTask?
    @State private var pendingArchivedTaskDeletion: KanbanTask?
    @State private var isSettingsSheetPresented = false
    @State private var exportSelectionSheet: BoardExportSelectionSheetState?
    @State private var importSelectionSheet: BoardImportSelectionSheetState?
    @State private var selectedTaskID: String?
    @State private var selectedTaskIDs: Set<String> = []
    @State private var taskSelectionAnchorTaskID: String?
    @State private var selectedArchivedTaskID: String?
    @State private var isColumnShortcutPickerPresented = false
    @State private var isDevPanelPresented = false
    @State private var shortcutTargetColumnID: String?
    @State private var showsArchivedTasks = false
    @AppStorage(WorkspaceSettingsDefaultsKey.showTopBottomTaskButtons) private var showsTopBottomTaskButtons = true
    @AppStorage(WorkspaceSettingsDefaultsKey.showUpDownTaskButtons) private var showsUpDownTaskButtons = true
    @AppStorage(WorkspaceSettingsDefaultsKey.showEditDeleteTaskButtons) private var showsEditDeleteTaskButtons = true
    @AppStorage(WorkspaceSettingsDefaultsKey.showArchivedTaskActionButtons) private var showsArchivedTaskActionButtons = true
    private let backendStorage: String

    private var taskControlVisibility: TaskControlVisibility {
        TaskControlVisibility(
            showsTopBottom: showsTopBottomTaskButtons,
            showsUpDown: showsUpDownTaskButtons,
            showsEditDelete: showsEditDeleteTaskButtons,
            showsArchivedActions: showsArchivedTaskActionButtons
        )
    }

    private var taskControlVisibilityBindings: TaskControlVisibilityBindings {
        TaskControlVisibilityBindings(
            showsTopBottom: $showsTopBottomTaskButtons,
            showsUpDown: $showsUpDownTaskButtons,
            showsEditDelete: $showsEditDeleteTaskButtons,
            showsArchivedActions: $showsArchivedTaskActionButtons
        )
    }

    private func resetTaskControlDefaultsForUITestsIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment[AppEnvironmentKey.resetTaskControlDefaults] == "1" else { return }

        UserDefaults.standard.set(true, forKey: WorkspaceSettingsDefaultsKey.showTopBottomTaskButtons)
        UserDefaults.standard.set(true, forKey: WorkspaceSettingsDefaultsKey.showUpDownTaskButtons)
        UserDefaults.standard.set(true, forKey: WorkspaceSettingsDefaultsKey.showEditDeleteTaskButtons)
        UserDefaults.standard.set(true, forKey: WorkspaceSettingsDefaultsKey.showArchivedTaskActionButtons)
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
        backendStorage = RuntimeFlags.resolvedBackendStorage(environment: env)
        _board = StateObject(wrappedValue: BoardViewModel(
            api: api,
            accessTokenProvider: { await auth.validAccessToken() },
            baseURLProvider: { auth.currentAPIBaseURL() }
        ))
    }

    var body: some View {
        workspaceScaffold
    }

    private var workspaceScaffold: some View {
        workspaceWithDialogs
    }

    private var workspaceBase: some View {
        ZStack {
            workspaceContent

            if board.isLoading {
                BlockingLoadingOverlay(
                    message: Strings.t("board.loading"),
                    accessibilityID: "board-loading-overlay"
                )
            }
        }
    }

    private var workspaceWithLifecycle: some View {
        workspaceBase
        .padding(24)
        .frame(minWidth: 980, minHeight: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            devPanelActivationArea
        }
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
            selectedTaskIDs = []
            taskSelectionAnchorTaskID = nil
            selectedArchivedTaskID = nil
        })
        .onChange(of: board.columns, perform: { _ in
            let existingTaskIDs = Set(board.columns.flatMap { column in
                board.tasks(for: column.id).map(\.id)
            })

            selectedTaskIDs.formIntersection(existingTaskIDs)

            if let selectedTaskID, !selectedTaskIDs.contains(selectedTaskID) {
                self.selectedTaskID = firstSelectedTaskIDInBoardOrder()
            }

            if selectedTaskID == nil {
                selectedTaskID = firstSelectedTaskIDInBoardOrder()
            }

            if let taskSelectionAnchorTaskID, !selectedTaskIDs.contains(taskSelectionAnchorTaskID) {
                self.taskSelectionAnchorTaskID = nil
            }

            if let shortcutTargetColumnID,
                !board.columns.contains(where: { $0.id == shortcutTargetColumnID })
            {
                self.shortcutTargetColumnID = nil
            }

            if shortcutTargetColumnID == nil {
                shortcutTargetColumnID = board.columns
                    .sorted { $0.position < $1.position }
                    .first?
                    .id
            }
        })
        .onChange(of: board.archivedTasksByColumnID, perform: { _ in
            guard let selectedArchivedTaskID else { return }
            if archivedTaskDetails(for: selectedArchivedTaskID) == nil {
                self.selectedArchivedTaskID = nil
            }
        })
        .onChange(of: showsArchivedTasks, perform: { isVisible in
            if !isVisible {
                selectedArchivedTaskID = nil
            }
        })
    }

    private var workspaceWithSheets: some View {
        workspaceWithLifecycle
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
        .sheet(isPresented: $isDevPanelPresented) {
            DevPanelSheet(
                backendStorage: backendStorage,
                connectionStatusText: devPanelConnectionStatusText,
                baseURLText: auth.currentAPIBaseURL()?.absoluteString ?? "(nil)",
                statusMessageText: board.statusMessage,
                devUsers: [],
                isSigningIn: false,
                onDevLogin: nil
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
        .sheet(isPresented: $isColumnShortcutPickerPresented) {
            ColumnShortcutPickerSheet(
                entries: columnShortcutEntries,
                initialSelectionColumnID: resolvedShortcutTargetColumnID(),
                onSelectColumn: { columnID in
                    shortcutTargetColumnID = columnID
                },
                onCreateTask: { columnID in
                    openCreateTaskFromShortcutPicker(columnID: columnID)
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
        .sheet(item: $viewingArchivedTask) { task in
            ArchivedTaskDetailsSheet(task: task)
        }
    }

    private var workspaceWithDialogs: some View {
        workspaceWithSheets
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
                guard let deletion = pendingTaskDeletion else { return }
                Task {
                    switch deletion {
                    case .single(let task):
                        await board.deleteTask(taskID: task.id)
                    case .multiple(let taskIDs):
                        await board.applyTaskBatchMutation(TaskBatchMutationRequest(action: .delete, taskIDs: taskIDs))
                    }
                }
                pendingTaskDeletion = nil
            }
            .accessibilityIdentifier("task-delete-confirm-action")
            Button(Strings.t("common.cancel"), role: .cancel) {
                pendingTaskDeletion = nil
            }
            .accessibilityIdentifier("task-delete-confirm-cancel")
        } message: {
            if let pendingTaskDeletion {
                switch pendingTaskDeletion {
                case .single(let task):
                    Text(Strings.f("board.task.delete.confirm.message", task.title))
                case .multiple(let taskIDs):
                    Text(Strings.f("board.task.delete.confirm.message.multiple", taskIDs.count))
                }
            }
        }
        .confirmationDialog(
            Strings.t("board.archived_task.delete.confirm.title"),
            isPresented: Binding(
                get: { pendingArchivedTaskDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingArchivedTaskDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(Strings.t("board.archived_task.delete.confirm.action"), role: .destructive) {
                guard let task = pendingArchivedTaskDeletion else { return }
                Task { await board.deleteArchivedTask(taskID: task.id) }
                pendingArchivedTaskDeletion = nil
            }
            .accessibilityIdentifier("archived-task-delete-confirm-action")
            Button(Strings.t("common.cancel"), role: .cancel) {
                pendingArchivedTaskDeletion = nil
            }
            .accessibilityIdentifier("archived-task-delete-confirm-cancel")
        } message: {
            if let task = pendingArchivedTaskDeletion {
                Text(Strings.f("board.archived_task.delete.confirm.message", task.title))
            }
        }
    }

    private var workspaceContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            workspaceHeader

            Text(Strings.f("loggedin.subtitle", auth.signedInEmail))
                .font(.callout)
                .foregroundStyle(.secondary)

            addColumnControls
            archivedToggleRow
            boardColumnsRegion
            statusAndDiagnosticsSection

            Spacer(minLength: 0)
        }
        .allowsHitTesting(!board.isLoading)
    }

    private var workspaceHeader: some View {
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
    }

    private var devPanelActivationArea: some View {
        Color.clear
            .frame(width: 64, height: 40)
            .contentShape(Rectangle())
            .onTapGesture {
                isDevPanelPresented = true
            }
            .accessibilityIdentifier("workspace-dev-panel-hit-area")
    }

    private var devPanelConnectionStatusText: String {
        if board.isLoading {
            return Strings.t("board.dev.status.loading")
        }
        if board.statusIsError {
            return Strings.t("board.dev.status.error")
        }
        if board.board != nil {
            return Strings.t("board.dev.status.connected")
        }
        return Strings.t("board.dev.status.idle")
    }

    private var addColumnControls: some View {
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
    }

    private var archivedToggleRow: some View {
        HStack(spacing: 10) {
            Toggle("board.archived_tasks.toggle", isOn: $showsArchivedTasks)
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("workspace-toggle-show-archived")

            if board.isArchivedTasksLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityIdentifier("workspace-archived-tasks-loading")
            }

            if board.archivedTasksStatusIsError {
                Text(board.archivedTasksStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .accessibilityIdentifier("workspace-archived-tasks-error")

                Button("board.archived_tasks.retry") {
                    Task { await board.reloadArchivedTasks() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("workspace-archived-tasks-retry")
            }
        }
    }

    private var boardColumnsRegion: some View {
        GeometryReader { geometry in
            let taskListMaxHeight = max(
                WorkspaceLayout.taskListMinHeight,
                geometry.size.height - WorkspaceLayout.reservedVerticalChromeHeight
            )

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(board.columns, id: \.id) { column in
                        columnCardView(for: column, taskListMaxHeight: taskListMaxHeight)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusAndDiagnosticsSection: some View {
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
    }

    @ViewBuilder
    private func columnCardView(for column: KanbanColumn, taskListMaxHeight: CGFloat) -> some View {
        let taskActionHandlers = ColumnTaskActionHandlers(
            onMoveTaskToTop: { taskID, columnID in
                _ = moveTaskSelectionToTop(triggerTaskID: taskID, columnID: columnID)
            },
            onMoveTaskToBottom: { taskID, columnID in
                _ = moveTaskSelectionToBottom(triggerTaskID: taskID, columnID: columnID)
            },
            onMoveTaskUp: { taskID, columnID in
                _ = moveTaskSelectionUp(triggerTaskID: taskID, columnID: columnID)
            },
            onMoveTaskDown: { taskID, columnID in
                _ = moveTaskSelectionDown(triggerTaskID: taskID, columnID: columnID)
            },
            taskDragItem: { taskID, columnID in
                dragItem(taskID: taskID, columnID: columnID)
            },
            onDropTaskItem: { item, destinationColumnID, destinationPosition in
                _ = handleTaskDrop(item: item, destinationColumnID: destinationColumnID, destinationPosition: destinationPosition)
            }
        )

        ColumnCard(
            column: column,
            tasks: board.tasks(for: column.id),
            archivedTasks: board.archivedTasks(for: column.id),
            showsArchivedTasks: showsArchivedTasks,
            taskListMaxHeight: taskListMaxHeight,
            isEnabled: board.canMutateBoardActions,
            onRename: { editingColumn = EditableColumn(column: column) },
            onDelete: {
                pendingColumnDeletion = EditableColumn(column: column)
            },
            onArchiveTasks: {
                Task {
                    await board.archiveColumnTasks(columnID: column.id)
                }
            },
            onAddTask: { creatingTaskInColumn = CreateTaskTarget(columnID: column.id) },
            onEditTask: { task in editingTask = EditableTask(columnID: column.id, task: task) },
            onDeleteTask: { task in
                _ = beginTaskDeletion(triggerTaskID: task.id, columnID: column.id)
            },
            onViewArchivedTask: { task in
                viewingArchivedTask = task
            },
            onRestoreArchivedTask: { task in
                Task { await board.restoreArchivedTask(taskID: task.id) }
            },
            onDeleteArchivedTask: { task in
                pendingArchivedTaskDeletion = task
            },
            taskControlVisibility: taskControlVisibility,
            selectedTaskIDs: selectedTaskIDs,
            selectedArchivedTaskID: selectedArchivedTaskID,
            onSelectTask: { taskID, interaction in
                selectTask(taskID: taskID, interaction: interaction)
            },
            onSelectArchivedTask: { taskID in
                selectedArchivedTaskID = taskID
                selectedTaskID = nil
                selectedTaskIDs = []
                taskSelectionAnchorTaskID = nil
            },
            taskActions: taskActionHandlers
        )
    }

    private struct SelectedTaskDetails {
        let taskID: String
        let columnID: String
        let task: KanbanTask
        let index: Int
        let taskCount: Int
    }

    private struct SelectedArchivedTaskDetails {
        let taskID: String
        let task: KanbanTask
    }

    private var columnShortcutEntries: [ColumnShortcutEntry] {
        let orderedColumns = board.columns.sorted { $0.position < $1.position }
        return zip(WorkspaceColumnShortcutKeys.all, orderedColumns)
            .map { key, column in
                ColumnShortcutEntry(key: key, columnID: column.id, columnTitle: column.title)
            }
    }

    private enum TaskShortcutAction {
        case openColumnShortcutPicker
        case clearSelection
        case moveTop
        case moveBottom
        case moveUp
        case moveDown
        case edit
        case viewArchived
        case restoreArchived
        case delete

        init?(event: NSEvent) {
            guard WorkspaceShortcutKeyModifiers.allows(event) else { return nil }

            if event.charactersIgnoringModifiers == "\u{1B}" {
                self = .clearSelection
                return
            }

            guard let key = event.charactersIgnoringModifiers?.lowercased() else { return nil }
            switch key {
            case "a": self = .openColumnShortcutPicker
            case "t": self = .moveTop
            case "b": self = .moveBottom
            case "u": self = .moveUp
            case "d": self = .moveDown
            case "e": self = .edit
            case "v": self = .viewArchived
            case "r": self = .restoreArchived
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

    private func firstSelectedTaskIDInBoardOrder() -> String? {
        for column in board.columns {
            for task in board.tasks(for: column.id) where selectedTaskIDs.contains(task.id) {
                return task.id
            }
        }
        return nil
    }

    private func rangeSelectionTaskIDs(anchorTaskID: String, targetTaskID: String) -> Set<String>? {
        guard let anchorDetails = taskDetails(for: anchorTaskID),
            let targetDetails = taskDetails(for: targetTaskID),
            anchorDetails.columnID == targetDetails.columnID
        else {
            return nil
        }

        let tasks = board.tasks(for: anchorDetails.columnID)
        let lower = min(anchorDetails.index, targetDetails.index)
        let upper = max(anchorDetails.index, targetDetails.index)
        return Set(tasks[lower...upper].map(\.id))
    }

    private func selectedTaskIDsForColumnAction(triggerTaskID: String, columnID: String) -> [String] {
        let columnTasks = board.tasks(for: columnID)
        let selectedInColumn = columnTasks.filter { selectedTaskIDs.contains($0.id) }
        if !selectedInColumn.isEmpty {
            return selectedInColumn.map(\.id)
        }
        if columnTasks.contains(where: { $0.id == triggerTaskID }) {
            return [triggerTaskID]
        }
        return []
    }

    private func reorderColumnTasksIfNeeded(columnID: String, orderedTaskIDs: [String]) -> Bool {
        let existingTaskIDs = board.tasks(for: columnID).map(\.id)
        guard orderedTaskIDs != existingTaskIDs else { return false }
        Task {
            await board.reorderTasksInColumn(columnID: columnID, orderedTaskIDs: orderedTaskIDs)
        }
        return true
    }

    private func dragItem(taskID: String, columnID: String) -> TaskDragItem {
        let orderedSelectedTaskIDs = board.tasks(for: columnID)
            .map(\.id)
            .filter { selectedTaskIDs.contains($0) }
        if orderedSelectedTaskIDs.contains(taskID) {
            return TaskDragItem(taskIDs: orderedSelectedTaskIDs)
        }
        return TaskDragItem(taskIDs: [taskID])
    }

    private func handleTaskDrop(item: TaskDragItem, destinationColumnID: String, destinationPosition: Int) -> Bool {
        guard board.canMutateBoardActions else { return false }

        var seen = Set<String>()
        let movingTaskIDs = item.taskIDs.filter { seen.insert($0).inserted }
        guard !movingTaskIDs.isEmpty else { return false }

        let movingTaskIDSet = Set(movingTaskIDs)
        var orderedTaskIDsByColumnID: [String: [String]] = [:]
        for column in board.columns {
            orderedTaskIDsByColumnID[column.id] = board.tasks(for: column.id).map(\.id)
        }

        guard let originalDestinationTaskIDs = orderedTaskIDsByColumnID[destinationColumnID] else {
            return false
        }

        for columnID in orderedTaskIDsByColumnID.keys {
            orderedTaskIDsByColumnID[columnID] = orderedTaskIDsByColumnID[columnID, default: []]
                .filter { !movingTaskIDSet.contains($0) }
        }

        var destinationTaskIDs = orderedTaskIDsByColumnID[destinationColumnID, default: []]
        let removedBeforeDestination = originalDestinationTaskIDs
            .prefix(max(0, destinationPosition))
            .filter { movingTaskIDSet.contains($0) }
            .count
        let adjustedDestinationPosition = max(0, destinationPosition - removedBeforeDestination)
        let insertionIndex = min(adjustedDestinationPosition, destinationTaskIDs.count)
        destinationTaskIDs.insert(contentsOf: movingTaskIDs, at: insertionIndex)
        orderedTaskIDsByColumnID[destinationColumnID] = destinationTaskIDs

        let orderedTasksByColumn = board.columns
            .sorted { $0.position < $1.position }
            .map { column in
                KanbanTaskColumnOrder(columnID: column.id, taskIDs: orderedTaskIDsByColumnID[column.id, default: []])
            }

        Task {
            await board.reorderTasks(orderedTasksByColumn: orderedTasksByColumn)
        }
        return true
    }

    private func selectTask(taskID: String, interaction: TaskSelectionInteraction) {
        switch interaction {
        case .single:
            selectedTaskIDs = [taskID]
            selectedTaskID = taskID
            taskSelectionAnchorTaskID = taskID
        case .toggle:
            if selectedTaskIDs.contains(taskID) {
                selectedTaskIDs.remove(taskID)
                if selectedTaskID == taskID {
                    selectedTaskID = firstSelectedTaskIDInBoardOrder()
                }
                if taskSelectionAnchorTaskID == taskID, selectedTaskIDs.isEmpty {
                    taskSelectionAnchorTaskID = nil
                }
            } else {
                selectedTaskIDs.insert(taskID)
                selectedTaskID = taskID
                if taskSelectionAnchorTaskID == nil {
                    taskSelectionAnchorTaskID = taskID
                }
            }
        case .range:
            if let anchorTaskID = taskSelectionAnchorTaskID,
                let rangeTaskIDs = rangeSelectionTaskIDs(anchorTaskID: anchorTaskID, targetTaskID: taskID)
            {
                selectedTaskIDs = rangeTaskIDs
                selectedTaskID = taskID
            } else {
                selectedTaskIDs = [taskID]
                selectedTaskID = taskID
                taskSelectionAnchorTaskID = taskID
            }
        }

        if !selectedTaskIDs.isEmpty {
            selectedArchivedTaskID = nil
        }
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

    private func archivedTaskDetails(for taskID: String) -> SelectedArchivedTaskDetails? {
        for column in board.columns {
            let archivedTasks = board.archivedTasks(for: column.id)
            if let task = archivedTasks.first(where: { $0.id == taskID }) {
                return SelectedArchivedTaskDetails(taskID: taskID, task: task)
            }
        }
        return nil
    }

    private func withSelectedArchivedTaskDetails(_ action: (SelectedArchivedTaskDetails) -> Bool) -> Bool {
        guard board.canMutateBoardActions,
            showsArchivedTasks,
            let selectedArchivedTaskID,
            let details = archivedTaskDetails(for: selectedArchivedTaskID)
        else {
            return false
        }
        return action(details)
    }

    private func withActionableSelectedArchivedTaskDetails(_ action: (SelectedArchivedTaskDetails) -> Bool) -> Bool {
        guard pendingArchivedTaskDeletion == nil, viewingArchivedTask == nil else { return false }
        return withSelectedArchivedTaskDetails(action)
    }

    private func moveSelectedTaskUp() -> Bool {
        withSelectedTaskDetails { details in
            moveTaskSelectionUp(triggerTaskID: details.taskID, columnID: details.columnID)
        }
    }

    private func moveSelectedTaskDown() -> Bool {
        withSelectedTaskDetails { details in
            moveTaskSelectionDown(triggerTaskID: details.taskID, columnID: details.columnID)
        }
    }

    private func moveSelectedTaskToTop() -> Bool {
        withSelectedTaskDetails { details in
            moveTaskSelectionToTop(triggerTaskID: details.taskID, columnID: details.columnID)
        }
    }

    private func moveTaskSelectionToTop(triggerTaskID: String, columnID: String) -> Bool {
        guard board.canMutateBoardActions else { return false }
        let columnTasks = board.tasks(for: columnID)
        guard !columnTasks.isEmpty else { return false }

        let selectedTaskIDsForMove = selectedTaskIDsForColumnAction(triggerTaskID: triggerTaskID, columnID: columnID)

        guard !selectedTaskIDsForMove.isEmpty else { return false }
        if selectedTaskIDsForMove.count == 1 {
            guard let singleTaskID = selectedTaskIDsForMove.first,
                let details = taskDetails(for: singleTaskID),
                details.index > 0
            else {
                return false
            }
            Task {
                await board.moveTask(taskID: singleTaskID, destinationColumnID: columnID, destinationPosition: 0)
            }
            return true
        }

        let selectedIDSet = Set(selectedTaskIDsForMove)
        let reorderedTaskIDs = selectedTaskIDsForMove + columnTasks
            .map(\.id)
            .filter { !selectedIDSet.contains($0) }
        return reorderColumnTasksIfNeeded(columnID: columnID, orderedTaskIDs: reorderedTaskIDs)
    }

    private func moveTaskSelectionToBottom(triggerTaskID: String, columnID: String) -> Bool {
        guard board.canMutateBoardActions else { return false }
        let columnTasks = board.tasks(for: columnID)
        guard !columnTasks.isEmpty else { return false }

        let selectedTaskIDsForMove = selectedTaskIDsForColumnAction(triggerTaskID: triggerTaskID, columnID: columnID)
        guard !selectedTaskIDsForMove.isEmpty else { return false }
        if selectedTaskIDsForMove.count == 1 {
            guard let singleTaskID = selectedTaskIDsForMove.first,
                let details = taskDetails(for: singleTaskID),
                details.index < (details.taskCount - 1)
            else {
                return false
            }
            Task {
                await board.moveTask(taskID: singleTaskID, destinationColumnID: columnID, destinationPosition: details.taskCount)
            }
            return true
        }

        let selectedIDSet = Set(selectedTaskIDsForMove)
        let reorderedTaskIDs = columnTasks
            .map(\.id)
            .filter { !selectedIDSet.contains($0) } + selectedTaskIDsForMove
        return reorderColumnTasksIfNeeded(columnID: columnID, orderedTaskIDs: reorderedTaskIDs)
    }

    private func moveTaskSelectionUp(triggerTaskID: String, columnID: String) -> Bool {
        guard board.canMutateBoardActions else { return false }
        let selectedTaskIDsForMove = selectedTaskIDsForColumnAction(triggerTaskID: triggerTaskID, columnID: columnID)
        guard !selectedTaskIDsForMove.isEmpty else { return false }
        if selectedTaskIDsForMove.count == 1 {
            guard let singleTaskID = selectedTaskIDsForMove.first,
                let details = taskDetails(for: singleTaskID),
                details.index > 0
            else {
                return false
            }
            Task {
                await board.moveTask(taskID: singleTaskID, destinationColumnID: columnID, destinationPosition: details.index - 1)
            }
            return true
        }

        let selectedIDSet = Set(selectedTaskIDsForMove)
        var reorderedTaskIDs = board.tasks(for: columnID).map(\.id)
        guard reorderedTaskIDs.count > 1 else { return false }
        for index in 1..<reorderedTaskIDs.count where selectedIDSet.contains(reorderedTaskIDs[index]) && !selectedIDSet.contains(reorderedTaskIDs[index - 1]) {
            reorderedTaskIDs.swapAt(index, index - 1)
        }
        return reorderColumnTasksIfNeeded(columnID: columnID, orderedTaskIDs: reorderedTaskIDs)
    }

    private func moveTaskSelectionDown(triggerTaskID: String, columnID: String) -> Bool {
        guard board.canMutateBoardActions else { return false }
        let selectedTaskIDsForMove = selectedTaskIDsForColumnAction(triggerTaskID: triggerTaskID, columnID: columnID)
        guard !selectedTaskIDsForMove.isEmpty else { return false }
        if selectedTaskIDsForMove.count == 1 {
            guard let singleTaskID = selectedTaskIDsForMove.first,
                let details = taskDetails(for: singleTaskID),
                details.index < (details.taskCount - 1)
            else {
                return false
            }
            Task {
                await board.moveTask(taskID: singleTaskID, destinationColumnID: columnID, destinationPosition: details.index + 1)
            }
            return true
        }

        let selectedIDSet = Set(selectedTaskIDsForMove)
        var reorderedTaskIDs = board.tasks(for: columnID).map(\.id)
        guard reorderedTaskIDs.count > 1 else { return false }
        for index in stride(from: reorderedTaskIDs.count - 2, through: 0, by: -1)
        where selectedIDSet.contains(reorderedTaskIDs[index]) && !selectedIDSet.contains(reorderedTaskIDs[index + 1]) {
            reorderedTaskIDs.swapAt(index, index + 1)
        }
        return reorderColumnTasksIfNeeded(columnID: columnID, orderedTaskIDs: reorderedTaskIDs)
    }

    private func moveSelectedTaskToBottom() -> Bool {
        withSelectedTaskDetails { details in
            moveTaskSelectionToBottom(triggerTaskID: details.taskID, columnID: details.columnID)
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
            beginTaskDeletion(triggerTaskID: details.taskID, columnID: details.columnID)
        }
    }

    private func beginTaskDeletion(triggerTaskID: String, columnID: String) -> Bool {
        guard pendingTaskDeletion == nil, editingTask == nil else { return false }
        let selectedTaskIDsForDelete = selectedTaskIDsForColumnAction(triggerTaskID: triggerTaskID, columnID: columnID)
        guard !selectedTaskIDsForDelete.isEmpty else { return false }

        if selectedTaskIDsForDelete.count == 1 {
            guard let taskID = selectedTaskIDsForDelete.first,
                let details = taskDetails(for: taskID)
            else {
                return false
            }
            pendingTaskDeletion = .single(EditableTask(columnID: details.columnID, task: details.task))
            return true
        }

        pendingTaskDeletion = .multiple(taskIDs: selectedTaskIDsForDelete)
        return true
    }

    private func viewSelectedArchivedTask() -> Bool {
        withActionableSelectedArchivedTaskDetails { details in
            viewingArchivedTask = details.task
            return true
        }
    }

    private func restoreSelectedArchivedTask() -> Bool {
        withActionableSelectedArchivedTaskDetails { details in
            Task {
                await board.restoreArchivedTask(taskID: details.taskID)
            }
            return true
        }
    }

    private func deleteSelectedArchivedTask() -> Bool {
        withActionableSelectedArchivedTaskDetails { details in
            pendingArchivedTaskDeletion = details.task
            return true
        }
    }

    private func resolvedShortcutTargetColumnID() -> String? {
        let entries = columnShortcutEntries
        guard !entries.isEmpty else { return nil }

        if let shortcutTargetColumnID,
            entries.contains(where: { $0.columnID == shortcutTargetColumnID })
        {
            return shortcutTargetColumnID
        }
        return entries.first?.columnID
    }

    private func presentColumnShortcutPicker() -> Bool {
        guard board.canMutateBoardActions else { return false }
        guard let targetColumnID = resolvedShortcutTargetColumnID() else { return false }
        shortcutTargetColumnID = targetColumnID
        isColumnShortcutPickerPresented = true
        return true
    }

    private func openCreateTaskFromShortcutPicker(columnID: String) {
        guard board.canMutateBoardActions else {
            isColumnShortcutPickerPresented = false
            return
        }
        guard creatingTaskInColumn == nil else { return }
        guard columnShortcutEntries.contains(where: { $0.columnID == columnID }) else { return }

        shortcutTargetColumnID = columnID
        isColumnShortcutPickerPresented = false
        creatingTaskInColumn = CreateTaskTarget(columnID: columnID)
    }

    private func handleTaskShortcutKey(event: NSEvent) -> Bool {
        guard let action = TaskShortcutAction(event: event) else { return false }

        switch action {
        case .openColumnShortcutPicker:
            return presentColumnShortcutPicker()
        case .clearSelection:
            guard !selectedTaskIDs.isEmpty || selectedArchivedTaskID != nil else { return false }
            selectedTaskID = nil
            selectedTaskIDs = []
            taskSelectionAnchorTaskID = nil
            selectedArchivedTaskID = nil
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
        case .viewArchived:
            return viewSelectedArchivedTask()
        case .restoreArchived:
            return restoreSelectedArchivedTask()
        case .delete:
            if selectedTaskID != nil {
                return deleteSelectedTask()
            }
            return deleteSelectedArchivedTask()
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

                Text("board.settings.shortcuts.column_picker")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("board-settings-shortcuts-column-picker")

                Text("board.settings.shortcuts.create_shortcut")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("board-settings-shortcuts-create")

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

                Text("board.settings.shortcuts.archived_actions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("board-settings-shortcuts-archived-actions")
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

                Toggle("board.settings.task_controls.archived_actions", isOn: taskControlVisibility.showsArchivedActions)
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("board-settings-task-controls-archived-actions")
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

private struct ColumnShortcutPickerSheet: View {
    let entries: [ColumnShortcutEntry]
    let initialSelectionColumnID: String?
    let onSelectColumn: (String) -> Void
    let onCreateTask: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedColumnID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("board.column.shortcut_picker.title")
                .font(.title3.weight(.semibold))

            Text("board.column.shortcut_picker.subtitle")
                .font(.callout)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entries) { entry in
                        Button {
                            selectedColumnID = entry.columnID
                            onSelectColumn(entry.columnID)
                        } label: {
                            HStack(spacing: 10) {
                                Text(entry.key.uppercased())
                                    .font(.caption.monospaced().weight(.semibold))
                                    .frame(width: 20, alignment: .leading)
                                Text(entry.columnTitle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if selectedColumnID == entry.columnID {
                                    Text("common.selected")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier("column-shortcut-picker-selected-\(entry.columnID)")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .accessibilityIdentifier("column-shortcut-picker-row-\(entry.columnID)")
                    }
                }
            }
            .frame(maxHeight: 240)
            .accessibilityIdentifier("column-shortcut-picker-list")

            HStack {
                Button("common.cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("column-shortcut-picker-cancel")

                Spacer()

                Button("board.column.shortcut_picker.create") {
                    guard let selectedColumnID else { return }
                    onCreateTask(selectedColumnID)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedColumnID == nil)
                .accessibilityIdentifier("column-shortcut-picker-create")
            }
        }
        .padding(20)
        .frame(width: 420)
        .accessibilityIdentifier("column-shortcut-picker-sheet")
        .background(WorkspaceKeyMonitor(onKeyDown: handleKeyDown(event:)))
        .onAppear {
            guard !entries.isEmpty else {
                dismiss()
                return
            }

            if let initialSelectionColumnID,
                entries.contains(where: { $0.columnID == initialSelectionColumnID })
            {
                selectedColumnID = initialSelectionColumnID
            } else {
                selectedColumnID = entries.first?.columnID
            }

            if let selectedColumnID {
                onSelectColumn(selectedColumnID)
            }
        }
    }

    private func handleKeyDown(event: NSEvent) -> Bool {
        guard WorkspaceShortcutKeyModifiers.allows(event) else { return false }

        if event.charactersIgnoringModifiers == "\u{1B}" {
            dismiss()
            return true
        }

        let isReturnKey = event.keyCode == 36 || event.keyCode == 76
        if isReturnKey {
            guard let selectedColumnID else { return false }
            onCreateTask(selectedColumnID)
            return true
        }

        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
        guard let entry = entries.first(where: { $0.key == key }) else { return false }
        selectedColumnID = entry.columnID
        onSelectColumn(entry.columnID)
        return true
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
            if let textView = responder as? NSTextView {
                return textView.isEditable
            }
            if let textField = responder as? NSTextField {
                return textField.isEditable
            }
            return false
        }

        private func removeMonitor() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

    }
}

// SwiftUI TextEditor on macOS does not expose return-key submit hooks.
// This bridge keeps task-description behavior aligned with title input:
// Enter submits, Shift+Enter inserts a newline.
private struct SubmitAwareTextEditor: NSViewRepresentable {
    private static let textContainerMaxHeight: CGFloat = 10_000_000
    private static let submitDisallowedModifiers: NSEvent.ModifierFlags = [
        .shift,
        .control,
        .option,
        .command,
        .function,
    ]

    @Binding var text: String
    let accessibilityID: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = SubmitAwareNSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.drawsBackground = false
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.isRichText = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: Self.textContainerMaxHeight)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.onSubmit = onSubmit
        textView.setAccessibilityIdentifier(accessibilityID)

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? SubmitAwareNSTextView else { return }
        textView.onSubmit = onSubmit
        textView.setAccessibilityIdentifier(accessibilityID)
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }

    final class SubmitAwareNSTextView: NSTextView {
        var onSubmit: (() -> Void)?

        override func keyDown(with event: NSEvent) {
            let isReturnKey = event.keyCode == 36 || event.keyCode == 76
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let submitModifiers = modifiers.intersection(SubmitAwareTextEditor.submitDisallowedModifiers)
            if isReturnKey, submitModifiers.isEmpty, !hasMarkedText() {
                onSubmit?()
                return
            }
            super.keyDown(with: event)
        }
    }
}

private struct ColumnCard: View {
    let column: KanbanColumn
    let tasks: [KanbanTask]
    let archivedTasks: [KanbanTask]
    let showsArchivedTasks: Bool
    let taskListMaxHeight: CGFloat
    let isEnabled: Bool
    let onRename: () -> Void
    let onDelete: () -> Void
    let onArchiveTasks: () -> Void
    let onAddTask: () -> Void
    let onEditTask: (KanbanTask) -> Void
    let onDeleteTask: (KanbanTask) -> Void
    let onViewArchivedTask: (KanbanTask) -> Void
    let onRestoreArchivedTask: (KanbanTask) -> Void
    let onDeleteArchivedTask: (KanbanTask) -> Void
    let taskControlVisibility: TaskControlVisibility
    let selectedTaskIDs: Set<String>
    let selectedArchivedTaskID: String?
    let onSelectTask: (String, TaskSelectionInteraction) -> Void
    let onSelectArchivedTask: (String) -> Void
    let taskActions: ColumnTaskActionHandlers

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
                Button("board.column.archive_tasks", action: onArchiveTasks)
                    .buttonStyle(.bordered)
                    .disabled(!isEnabled || tasks.isEmpty)
                    .accessibilityIdentifier("column-archive-tasks-\(column.id)")
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
                            isSelected: selectedTaskIDs.contains(task.id),
                            onSelectTask: onSelectTask,
                            onMoveToTop: {
                                taskActions.onMoveTaskToTop(task.id, column.id)
                            },
                            onMoveToBottom: {
                                taskActions.onMoveTaskToBottom(task.id, column.id)
                            },
                            onMoveUp: {
                                taskActions.onMoveTaskUp(task.id, column.id)
                            },
                            onMoveDown: {
                                taskActions.onMoveTaskDown(task.id, column.id)
                            },
                            dragItem: {
                                taskActions.taskDragItem(task.id, column.id)
                            },
                            onDropTask: { draggedTask in
                                taskActions.onDropTaskItem(draggedTask, column.id, task.position)
                            }
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(Strings.f("board.column.archived_count", archivedTasks.count))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("column-archived-section-\(column.id)")

                        if showsArchivedTasks {
                            ForEach(archivedTasks, id: \.id) { archivedTask in
                                ArchivedTaskRow(
                                    task: archivedTask,
                                    isEnabled: isEnabled,
                                    taskControlVisibility: taskControlVisibility,
                                    isSelected: selectedArchivedTaskID == archivedTask.id,
                                    onSelect: { onSelectArchivedTask(archivedTask.id) },
                                    onView: { onViewArchivedTask(archivedTask) },
                                    onRestore: { onRestoreArchivedTask(archivedTask) },
                                    onDelete: { onDeleteArchivedTask(archivedTask) }
                                )
                            }
                        }
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
            if tasks.contains(where: { item.taskIDs.contains($0.id) }) {
                destinationPosition = max(0, tasks.count - 1)
            } else {
                destinationPosition = tasks.count
            }
            taskActions.onDropTaskItem(item, column.id, destinationPosition)
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
    let onSelectTask: (String, TaskSelectionInteraction) -> Void
    let onMoveToTop: () -> Void
    let onMoveToBottom: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let dragItem: () -> TaskDragItem
    let onDropTask: (TaskDragItem) -> Void

    private var isFirstTask: Bool { index == 0 }
    private var isLastTask: Bool { index == taskCount - 1 }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if taskControlVisibility.showsTopBottom {
                HStack(spacing: 8) {
                    Button("board.task.move_top") {
                        onMoveToTop()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isEnabled || isFirstTask)
                    .accessibilityIdentifier("task-move-top-\(task.id)")

                    Spacer(minLength: 0)

                    Button("board.task.move_bottom") {
                        onMoveToBottom()
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
                            onMoveUp()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isEnabled || isFirstTask)
                        .accessibilityIdentifier("task-move-up-\(task.id)")

                        Button("board.task.move_down") {
                            onMoveDown()
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
            onSelectTask(task.id, TaskSelectionInteraction.current())
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .draggable(dragItem())
        .dropDestination(for: TaskDragItem.self) { items, _ in
            guard let item = items.first else { return false }
            onDropTask(item)
            return true
        }
    }
}

private struct ArchivedTaskRow: View {
    let task: KanbanTask
    let isEnabled: Bool
    let taskControlVisibility: TaskControlVisibility
    let isSelected: Bool
    let onSelect: () -> Void
    let onView: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("archived-task-title-\(task.id)")

            if !task.description.isEmpty {
                Text(task.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(Strings.f("board.task.archived_at", task.archivedAt ?? "-"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("archived-task-time-\(task.id)")

            HStack(spacing: 8) {
                if taskControlVisibility.showsArchivedActions {
                    Button("board.archived_task.view", action: onView)
                        .buttonStyle(.bordered)
                        .disabled(!isEnabled)
                        .accessibilityIdentifier("archived-task-view-\(task.id)")
                    Button("board.archived_task.restore", action: onRestore)
                        .buttonStyle(.bordered)
                        .disabled(!isEnabled)
                        .accessibilityIdentifier("archived-task-restore-\(task.id)")
                    Button("board.archived_task.delete", action: onDelete)
                        .buttonStyle(.bordered)
                        .disabled(!isEnabled)
                        .accessibilityIdentifier("archived-task-delete-\(task.id)")
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("archived-task-row-\(task.id)")
        .accessibilityValue(isSelected ? "selected" : "unselected")
        .onTapGesture {
            onSelect()
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }
}

private struct ArchivedTaskDetailsSheet: View {
    let task: KanbanTask
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("board.archived_task.view.title")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("board.task.title.placeholder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: .constant(task.title))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("board.task.description.placeholder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: .constant(task.description))
                    .frame(minHeight: 120)
                    .disabled(true)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
            }

            Text(Strings.f("board.task.archived_at", task.archivedAt ?? "-"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("common.close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("archived-task-view-close")
            }
        }
        .padding(20)
        .frame(width: 420)
        .accessibilityIdentifier("archived-task-view-sheet")
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
    @State private var isSubmitting = false

    init(title: String, submitLabel: String, initialTitle: String, initialDescription: String, onSubmit: @escaping (String, String) -> Void) {
        self.title = title
        self.submitLabel = submitLabel
        self.initialTitle = initialTitle
        self.initialDescription = initialDescription
        self.onSubmit = onSubmit
        _inputTitle = State(initialValue: initialTitle)
        _inputDescription = State(initialValue: initialDescription)
    }

    private var hasValidTitle: Bool {
        isNonEmptyTitle(inputTitle)
    }

    private func submitAndDismiss() {
        guard hasValidTitle, !isSubmitting else { return }
        isSubmitting = true
        onSubmit(inputTitle, inputDescription)
        dismiss()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("task-editor-title")

            TextField("board.task.title.placeholder", text: $inputTitle)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("task-editor-title-input")
                .onSubmit {
                    submitAndDismiss()
                }

            SubmitAwareTextEditor(
                text: $inputDescription,
                accessibilityID: "task-editor-description-input",
                onSubmit: submitAndDismiss
            )
                .frame(height: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("common.cancel") { dismiss() }
                    .disabled(isSubmitting)
                    .accessibilityIdentifier("task-editor-cancel")
                Button(submitLabel) {
                    submitAndDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!hasValidTitle || isSubmitting)
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

    private var hasValidTitle: Bool {
        isNonEmptyTitle(inputTitle)
    }

    private func submitIfValid() {
        guard hasValidTitle, !isSubmitting else { return }

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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
            TextField("board.input.placeholder", text: $inputTitle)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("board-editor-title-input")
                .onSubmit {
                    submitIfValid()
                }
            HStack {
                Spacer()
                Button("common.cancel") { dismiss() }
                    .disabled(isSubmitting)
                Button(submitLabel) {
                    submitIfValid()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!hasValidTitle || isSubmitting)
                .accessibilityIdentifier("board-editor-submit")
            }
        }
        .padding(20)
        .frame(width: 420)
        .accessibilityIdentifier("board-editor-sheet")
    }
}

private func isNonEmptyTitle(_ title: String) -> Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

private enum PendingTaskDeletion {
    case single(EditableTask)
    case multiple(taskIDs: [String])
}

private struct CreateTaskTarget: Identifiable {
    let columnID: String
    var id: String { columnID }
}

private struct TaskDragItem: Transferable {
    let taskIDs: [String]

    var taskID: String {
        taskIDs.first ?? ""
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(
            contentType: TaskDragPayload.type,
            exporting: { item in encodedPayload(for: item.taskIDs) },
            importing: { data in TaskDragItem(taskIDs: try decodeTaskIDs(from: data)) }
        )
        DataRepresentation(
            contentType: .data,
            exporting: { item in encodedPayload(for: item.taskIDs) },
            importing: { data in TaskDragItem(taskIDs: try decodeTaskIDs(from: data)) }
        )
    }

    private static func encodedPayload(for taskIDs: [String]) -> Data {
        let joined = taskIDs.joined(separator: ",")
        return Data("\(TaskDragPayload.payloadPrefix)\(joined)".utf8)
    }

    private static func decodeTaskIDs(from data: Data) throws -> [String] {
        guard
            let payload = String(data: data, encoding: .utf8),
            payload.hasPrefix(TaskDragPayload.payloadPrefix)
        else {
            throw TaskDragItemTransferError.invalidPayload
        }

        let raw = String(payload.dropFirst(TaskDragPayload.payloadPrefix.count))
        let taskIDs = raw
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.isEmpty }
        guard !taskIDs.isEmpty else {
            throw TaskDragItemTransferError.invalidPayload
        }
        return taskIDs
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

private struct DevPanelSheet: View {
    let backendStorage: String
    let connectionStatusText: String
    let baseURLText: String
    let statusMessageText: String
    let devUsers: [RuntimeFlags.DevUser]
    let isSigningIn: Bool
    let onDevLogin: ((RuntimeFlags.DevUser) -> Void)?

    init(
        backendStorage: String,
        connectionStatusText: String,
        baseURLText: String,
        statusMessageText: String,
        devUsers: [RuntimeFlags.DevUser] = [],
        isSigningIn: Bool = false,
        onDevLogin: ((RuntimeFlags.DevUser) -> Void)? = nil
    ) {
        self.backendStorage = backendStorage
        self.connectionStatusText = connectionStatusText
        self.baseURLText = baseURLText
        self.statusMessageText = statusMessageText
        self.devUsers = devUsers
        self.isSigningIn = isSigningIn
        self.onDevLogin = onDevLogin
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("board.dev.panel.title")
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("dev-panel-title")

            Group {
                Text(Strings.f("board.dev.panel.backend", backendStorage))
                Text(Strings.f("board.dev.panel.status", connectionStatusText))
                Text(Strings.f("board.dev.panel.base_url", baseURLText))

                if !statusMessageText.isEmpty {
                    Text(Strings.f("board.dev.panel.last_status", statusMessageText))
                }
            }
            .font(.caption.monospaced())
            .textSelection(.enabled)

            if let onDevLogin, !devUsers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("board.dev.panel.dev_users")
                        .font(.caption.weight(.semibold))
                    ForEach(Array(devUsers.enumerated()), id: \.offset) { index, user in
                        Button(Strings.f("board.dev.panel.sign_in_as", user.email)) {
                            onDevLogin(user)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSigningIn)
                        .accessibilityIdentifier("dev-panel-login-\(index)")
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(minWidth: 420, minHeight: 220, alignment: .topLeading)
        .padding(20)
        .accessibilityIdentifier("dev-panel-sheet")
    }
}

#Preview {
    ContentView()
}
