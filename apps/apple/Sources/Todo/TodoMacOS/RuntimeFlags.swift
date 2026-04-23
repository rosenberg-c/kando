import Foundation

enum AppEnvironmentKey {
    static let uiTestMode = "TODO_UITEST_MODE"
    static let testMode = "TODO_TEST_MODE"
    static let disableKeychain = "TODO_DISABLE_KEYCHAIN"
    static let mockBoard = "TODO_UITEST_MOCK_BOARD"
    static let signedIn = "TODO_UITEST_SIGNED_IN"
    static let email = "TODO_UITEST_EMAIL"
    static let workTaskCount = "TODO_UITEST_WORK_TASK_COUNT"
    static let mockDelayMs = "TODO_UITEST_MOCK_DELAY_MS"
}

enum RuntimeFlags {
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
