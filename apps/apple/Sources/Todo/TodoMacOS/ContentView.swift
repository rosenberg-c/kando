//
//  ContentView.swift
//  TodoMacOS
//
//  Created by christian on 2026-04-18.
//

import AppKit
import SwiftUI

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

                    if auth.isSigningIn {
                        ProgressView("signin.submit_in_progress")
                            .controlSize(.small)
                    }

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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            if processEnvironment["TODO_UITEST_SIGNED_IN"] == "1" {
                auth.applyUITestSignedInSession(email: processEnvironment["TODO_UITEST_EMAIL"] ?? "ui-test@example.com")
            } else {
                await auth.restoreSessionIfNeeded()
            }
        }
    }
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

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(board.columns, id: \.id) { column in
                        ColumnCard(
                            column: column,
                            tasks: board.tasks(for: column.id),
                            isEnabled: board.canMutateBoardActions,
                            onRename: { editingColumn = EditableColumn(column: column) },
                            onDelete: {
                                pendingColumnDeletion = EditableColumn(column: column)
                            },
                            onAddTask: { creatingTaskInColumn = CreateTaskTarget(columnID: column.id) },
                            onEditTask: { task in editingTask = EditableTask(columnID: column.id, task: task) },
                            onDeleteTask: { task in
                                pendingTaskDeletion = EditableTask(columnID: column.id, task: task)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if board.isLoading {
                ProgressView("board.loading")
                    .controlSize(.small)
            }

            if !board.statusMessage.isEmpty {
                Text(board.statusMessage)
                    .font(.caption)
                    .foregroundStyle(board.statusIsError ? .red : .green)
                    .textSelection(.enabled)
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
            }

            Spacer(minLength: 0)
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
}

private struct ColumnCard: View {
    let column: KanbanColumn
    let tasks: [KanbanTask]
    let isEnabled: Bool
    let onRename: () -> Void
    let onDelete: () -> Void
    let onAddTask: () -> Void
    let onEditTask: (KanbanTask) -> Void
    let onDeleteTask: (KanbanTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(column.title)
                    .font(.headline)
                Spacer()
                Text(Strings.f("board.column.task_count", tasks.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tasks, id: \.id) { task in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
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
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Button("board.task.add", action: onAddTask)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!isEnabled)
        }
        .padding(12)
        .frame(width: 280, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

#Preview {
    ContentView()
}
