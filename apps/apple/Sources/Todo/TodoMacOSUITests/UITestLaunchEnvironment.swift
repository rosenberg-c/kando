import XCTest

enum UITestEnvKey {
    static let uiTestMode = "KANDO_UITEST_MODE"
    static let testMode = "KANDO_TEST_MODE"
    static let disableKeychain = "KANDO_DISABLE_KEYCHAIN"
    static let mockBoard = "KANDO_UITEST_MOCK_BOARD"
    static let signedIn = "KANDO_UITEST_SIGNED_IN"
    static let email = "KANDO_UITEST_EMAIL"
    static let workTaskCount = "KANDO_UITEST_WORK_TASK_COUNT"
    static let columnCount = "KANDO_UITEST_COLUMN_COUNT"
    static let spreadTasksAcrossColumns = "KANDO_UITEST_SPREAD_TASKS"
    static let mockDelayMs = "KANDO_UITEST_MOCK_DELAY_MS"
    static let resetTaskControlDefaults = "KANDO_UITEST_RESET_TASK_CONTROL_DEFAULTS"
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
