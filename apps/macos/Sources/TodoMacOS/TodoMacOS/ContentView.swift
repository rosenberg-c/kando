//
//  ContentView.swift
//  TodoMacOS
//
//  Created by christian on 2026-04-18.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthSessionViewModel()
    @AppStorage("signin.keepSignedIn") private var keepSignedIn = true

    private var canSubmit: Bool {
        !auth.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !auth.password.isEmpty && !auth.isSigningIn
    }

    var body: some View {
        Group {
            if auth.isSignedIn {
                LoggedInView(email: auth.signedInEmail) {
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
        .task {
            await auth.restoreSessionIfNeeded()
        }
    }
}

private struct LoggedInView: View {
    let email: String
    let onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("loggedin.title")
                .font(.largeTitle.weight(.semibold))

            Text(Strings.f("loggedin.subtitle", email))
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("loggedin.signout", action: onSignOut)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .padding(24)
        .frame(width: 420)
    }
}

#Preview {
    ContentView()
}
