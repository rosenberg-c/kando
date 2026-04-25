import XCTest

enum UITestEnvKey {
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
}

func configuredAppForUITests(resetTaskControlDefaults: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += [
        "-ApplePersistenceIgnoreState", "YES",
        "-AppleLanguages", "(en)",
        "-AppleLocale", "en_US"
    ]
    app.launchEnvironment[UITestEnvKey.uiTestMode] = "1"
    app.launchEnvironment[UITestEnvKey.testMode] = "1"
    app.launchEnvironment[UITestEnvKey.disableKeychain] = "1"
    app.launchEnvironment[UITestEnvKey.mockBoard] = "1"
    app.launchEnvironment[UITestEnvKey.resetTaskControlDefaults] = resetTaskControlDefaults ? "1" : "0"
    return app
}
