import Foundation

enum RuntimeFlags {
    static func shouldUseMockBoard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isXCTestRuntime: Bool = isRunningXCTest()
    ) -> Bool {
        environment["TODO_UITEST_MOCK_BOARD"] == "1"
            || environment["TODO_UITEST_MODE"] == "1"
            || environment["TODO_TEST_MODE"] == "1"
            || isXCTestRuntime
    }

    static func shouldDisableKeychain(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isXCTestRuntime: Bool = isRunningXCTest()
    ) -> Bool {
        environment["TODO_DISABLE_KEYCHAIN"] == "1"
            || environment["TODO_UITEST_MODE"] == "1"
            || environment["TODO_TEST_MODE"] == "1"
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
