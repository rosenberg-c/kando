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

private struct LoggedInWorkspaceView: View {
    @ObservedObject var auth: AuthSessionViewModel
    let onSignOut: () -> Void

    @StateObject private var board: BoardViewModel
    @State private var newColumnTitle = ""
    @State private var editingColumn: EditableColumn?
    @State private var creatingTaskInColumn: CreateTaskTarget?
    @State private var editingTask: EditableTask?
    @State private var pendingColumnDeletion: EditableColumn?
    @State private var pendingTaskDeletion: EditableTask?
    @State private var isReorderSheetPresented = false
    @State private var reorderSheetColumns: [KanbanColumn] = []
    @State private var isApplyingReorder = false

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
                    Text(board.board?.title ?? Strings.t("board.title"))
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityIdentifier("workspace-board-title")

                    Spacer()

                    Button("board.refresh") {
                        Task { await board.reloadBoard() }
                    }
                    .buttonStyle(.bordered)

                    Button("board.column.reorder.mode.enter") {
                        reorderSheetColumns = board.columns
                        isReorderSheetPresented = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(!board.canMutateBoardActions)
                    .accessibilityIdentifier("board-edit-mode-toggle")

                    Button("loggedin.signout", action: onSignOut)
                        .buttonStyle(.bordered)
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
        .task {
            await board.loadBoardIfNeeded()
        }
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
                        if await applyColumnReorder(targetOrderIDs: reorderSheetColumns.map(\.id)) {
                            isReorderSheetPresented = false
                        }
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
            Button(Strings.t("common.cancel"), role: .cancel) {
                pendingTaskDeletion = nil
            }
        } message: {
            if let task = pendingTaskDeletion {
                Text(Strings.f("board.task.delete.confirm.message", task.title))
            }
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

    private func applyColumnReorder(targetOrderIDs: [String]) async -> Bool {
        let didReorder = await board.reorderColumns(orderedColumnIDs: targetOrderIDs)
        reorderSheetColumns = board.columns
        return didReorder
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
        .accessibilityIdentifier(accessibilityID)
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
                    ForEach(tasks, id: \.id) { task in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(task.title)
                                .font(.subheadline.weight(.semibold))
                                .accessibilityIdentifier("task-title-\(task.id)")
                            if !task.description.isEmpty {
                                Text(task.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            HStack(spacing: 8) {
                                Button("board.task.edit") { onEditTask(task) }
                                    .buttonStyle(.bordered)
                                    .disabled(!isEnabled)
                                Button("board.task.delete") { onDeleteTask(task) }
                                    .buttonStyle(.bordered)
                                    .disabled(!isEnabled)
                                    .accessibilityIdentifier("task-delete-\(task.id)")
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("task-card-\(task.id)")
                        .draggable(TaskDragItem(taskID: task.id))
                        .dropDestination(for: TaskDragItem.self) { items, _ in
                            guard let item = items.first else { return false }
                            onMoveTask(item.taskID, column.id, task.position)
                            return true
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
                .accessibilityIdentifier("board-reorder-move-left-\(column.id)")

                Button("board.column.move_right") {
                    moveColumnLocally(from: index, to: index + 1)
                }
                .buttonStyle(.bordered)
                .disabled(!canMoveRight || isApplying)
                .accessibilityIdentifier("board-reorder-move-right-\(column.id)")
            }
        }
        .padding(10)
        .frame(width: 180, alignment: .leading)
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

            TextField("board.task.title.placeholder", text: $inputTitle)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $inputDescription)
                .font(.body)
                .frame(height: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("common.cancel") { dismiss() }
                Button(submitLabel) {
                    onSubmit(inputTitle, inputDescription)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 460)
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
