import Foundation

enum AppEnvironmentKey {
    static let uiTestMode = "TODO_UITEST_MODE"
    static let testMode = "TODO_TEST_MODE"
    static let disableKeychain = "TODO_DISABLE_KEYCHAIN"
    static let mockBoard = "TODO_UITEST_MOCK_BOARD"
    static let signedIn = "TODO_UITEST_SIGNED_IN"
    static let email = "TODO_UITEST_EMAIL"
    static let workTaskCount = "TODO_UITEST_WORK_TASK_COUNT"
    static let columnCount = "TODO_UITEST_COLUMN_COUNT"
    static let spreadTasksAcrossColumns = "TODO_UITEST_SPREAD_TASKS"
    static let mockDelayMs = "TODO_UITEST_MOCK_DELAY_MS"
    static let resetTaskControlDefaults = "TODO_UITEST_RESET_TASK_CONTROL_DEFAULTS"
    static let kanbanRepository = "KANBAN_REPOSITORY"
    static let kanbanRepositoryOverride = "TODO_KANBAN_REPOSITORY"
    static let devUsers = "TODO_DEV_USERS"
}

enum RuntimeFlags {
    struct DevUser: Equatable {
        let email: String
        let password: String
    }

    static func resolvedBackendStorage(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        if shouldUseMockBoard(environment: environment) {
            return "memory"
        }
        let configuredRepository = environment[AppEnvironmentKey.kanbanRepositoryOverride]
            ?? environment[AppEnvironmentKey.kanbanRepository]
        let normalizedRepository = configuredRepository?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch normalizedRepository {
        case "appwrite":
            return "appwrite"
        case "memory":
            return "memory"
        case "sqlite", "":
            return "sqlite"
        default:
            return normalizedRepository ?? "sqlite"
        }
    }

    static func devUsers(environment: [String: String] = ProcessInfo.processInfo.environment) -> [DevUser] {
        guard let raw = environment[AppEnvironmentKey.devUsers] else { return [] }
        return raw
            .split(separator: ",")
            .compactMap { pair in
                let segments = pair.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                guard segments.count == 2, !segments[0].isEmpty, !segments[1].isEmpty else {
                    return nil
                }
                return DevUser(email: segments[0], password: segments[1])
            }
    }

    static func shouldUseMockBoard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isXCTestRuntime: Bool = isRunningXCTest()
    ) -> Bool {
        environment[AppEnvironmentKey.mockBoard] == "1"
            || environment[AppEnvironmentKey.uiTestMode] == "1"
            || environment[AppEnvironmentKey.testMode] == "1"
            || isXCTestRuntime
    }

    static func shouldDisableKeychain(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isXCTestRuntime: Bool = isRunningXCTest()
    ) -> Bool {
        environment[AppEnvironmentKey.disableKeychain] == "1"
            || environment[AppEnvironmentKey.uiTestMode] == "1"
            || environment[AppEnvironmentKey.testMode] == "1"
            || isXCTestRuntime
    }

    private static func isRunningXCTest() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil {
            return true
        }

        if NSClassFromString("XCTestCase") != nil {
            return true
        }

        return ProcessInfo.processInfo.processName.lowercased().contains("xctest")
    }
}
