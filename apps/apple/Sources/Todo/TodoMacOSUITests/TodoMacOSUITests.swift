//
//  TodoMacOSUITests.swift
//  TodoMacOSUITests
//
//  Created by christian on 2026-04-18.
//

import XCTest

final class TodoMacOSUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // Requirement: TEST-UI-001
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Requirement: TEST-UI-002
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testDeleteTaskConfirmationCancelAndConfirm() throws {
        // Requirements: TASK-DEL-001, TASK-DEL-002, TASK-DEL-003, TASK-DEL-004
        let app = launchSignedInApp()

        let taskDeleteButton = app.buttons["task-delete-task-1"]
        guard taskDeleteButton.waitForExistence(timeout: 8) else {
            XCTFail("Expected task delete button not found. UI:\n\(app.debugDescription)")
            return
        }

        let taskTitle = app.staticTexts["Example task"]
        XCTAssertTrue(taskTitle.exists)
        taskDeleteButton.tap()

        let deleteAction = app.sheets.firstMatch.buttons["Delete task"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 2))
        XCTAssertTrue(app.sheets.firstMatch.staticTexts["Delete task?"].exists)

        let cancelAction = app.sheets.firstMatch.buttons["Cancel"]
        cancelAction.tap()
        XCTAssertFalse(deleteAction.exists)
        XCTAssertTrue(taskTitle.exists)

        taskDeleteButton.tap()
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 2))
        deleteAction.tap()
        XCTAssertFalse(taskTitle.waitForExistence(timeout: 2))
    }

    @MainActor
    func testDeleteColumnConfirmationCancelAndConfirm() throws {
        // Requirements: COL-DEL-001, COL-DEL-002, COL-DEL-003, COL-DEL-004
        let app = launchSignedInApp()

        let columnDeleteButton = app.buttons["column-delete-column-empty"]
        guard columnDeleteButton.waitForExistence(timeout: 8) else {
            XCTFail("Expected column delete button not found. UI:\n\(app.debugDescription)")
            return
        }

        let columnTitle = app.staticTexts["Empty"]
        XCTAssertTrue(columnTitle.exists)
        columnDeleteButton.tap()

        let deleteAction = app.sheets.firstMatch.buttons["Delete column"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 2))
        XCTAssertTrue(app.sheets.firstMatch.staticTexts["Delete column?"].exists)

        let cancelAction = app.sheets.firstMatch.buttons["Cancel"]
        cancelAction.tap()
        XCTAssertFalse(deleteAction.exists)
        XCTAssertTrue(columnTitle.exists)

        columnDeleteButton.tap()
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 2))
        deleteAction.tap()
        XCTAssertFalse(columnTitle.waitForExistence(timeout: 2))
    }

    @MainActor
    private func launchSignedInApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["TODO_UITEST_MODE"] = "1"
        app.launchEnvironment["TODO_DISABLE_KEYCHAIN"] = "1"
        app.launchEnvironment["TODO_UITEST_SIGNED_IN"] = "1"
        app.launchEnvironment["TODO_UITEST_MOCK_BOARD"] = "1"
        app.launchEnvironment["TODO_UITEST_EMAIL"] = "ui-test@example.com"
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), "Expected app window after launch")
        return app
    }
}
