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
}

enum UITestDefaultsKey {
    static let showTopBottomTaskButtons = "board.settings.task_controls.show_top_bottom"
    static let showUpDownTaskButtons = "board.settings.task_controls.show_up_down"
    static let showEditDeleteTaskButtons = "board.settings.task_controls.show_edit_delete"
}

func configuredAppForUITests(resetTaskControlDefaults: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    var launchArguments = [
        "-ApplePersistenceIgnoreState", "YES",
        "-AppleLanguages", "(en)",
        "-AppleLocale", "en_US"
    ]
    if resetTaskControlDefaults {
        launchArguments += [
            "-\(UITestDefaultsKey.showTopBottomTaskButtons)", "YES",
            "-\(UITestDefaultsKey.showUpDownTaskButtons)", "YES",
            "-\(UITestDefaultsKey.showEditDeleteTaskButtons)", "YES"
        ]
    }
    app.launchArguments += launchArguments
    app.launchEnvironment[UITestEnvKey.uiTestMode] = "1"
    app.launchEnvironment[UITestEnvKey.testMode] = "1"
    app.launchEnvironment[UITestEnvKey.disableKeychain] = "1"
    app.launchEnvironment[UITestEnvKey.mockBoard] = "1"
    return app
}
