import XCTest

enum UITestEnvKey {
    static let uiTestMode = "TODO_UITEST_MODE"
    static let testMode = "TODO_TEST_MODE"
    static let disableKeychain = "TODO_DISABLE_KEYCHAIN"
    static let mockBoard = "TODO_UITEST_MOCK_BOARD"
    static let signedIn = "TODO_UITEST_SIGNED_IN"
    static let email = "TODO_UITEST_EMAIL"
    static let workTaskCount = "TODO_UITEST_WORK_TASK_COUNT"
}

func configuredAppForUITests() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
    app.launchEnvironment[UITestEnvKey.uiTestMode] = "1"
    app.launchEnvironment[UITestEnvKey.testMode] = "1"
    app.launchEnvironment[UITestEnvKey.disableKeychain] = "1"
    app.launchEnvironment[UITestEnvKey.mockBoard] = "1"
    return app
}
