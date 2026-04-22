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
        let app = configuredAppForUITests()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Requirement: TEST-UI-002
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = configuredAppForUITests()
            app.launch()
        }
    }

    @MainActor
    func testDeleteTaskConfirmationCancelAndConfirm() throws {
        // Requirements: TASK-DEL-001, TASK-DEL-002, TASK-DEL-003, TASK-DEL-004, UX-003
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
    func testWorkspaceAnchorsTopLeading() throws {
        // Requirement: UX-001
        let app = launchSignedInApp()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Expected app window")

        let title = app.staticTexts["workspace-board-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Expected workspace title")

        let horizontalInset = title.frame.minX - window.frame.minX
        let topInset = window.frame.maxY - title.frame.maxY
        let horizontalInsetRatio = horizontalInset / max(window.frame.width, 1)
        let topInsetRatio = topInset / max(window.frame.height, 1)

        XCTAssertGreaterThanOrEqual(horizontalInset, 0)
        XCTAssertGreaterThanOrEqual(topInset, 0)
        XCTAssertLessThan(horizontalInsetRatio, 0.2)
        XCTAssertLessThan(topInsetRatio, 0.25)
    }

    @MainActor
    func testDeleteColumnConfirmationCancelAndConfirm() throws {
        // Requirements: COL-DEL-001, COL-DEL-002, COL-DEL-003, COL-DEL-004, UX-003
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
    func testDragTaskToAnotherColumn() throws {
        // Requirement: UX-005
        let app = launchSignedInApp()
        let uiTimeout: TimeInterval = 8

        let sourceTaskCard = app.descendants(matching: .any).matching(identifier: "task-card-task-1").firstMatch
        let sourceColumn = app.otherElements["column-drop-zone-column-work"]
        let destinationColumn = app.otherElements["column-drop-zone-column-empty"]

        XCTAssertTrue(app.staticTexts["workspace-board-title"].waitForExistence(timeout: uiTimeout), "Expected board workspace title")
        XCTAssertTrue(sourceTaskCard.waitForExistence(timeout: uiTimeout), "Expected draggable source task card")
        XCTAssertTrue(sourceColumn.waitForExistence(timeout: uiTimeout), "Expected source column drop zone")
        XCTAssertTrue(destinationColumn.waitForExistence(timeout: uiTimeout), "Expected destination column drop zone")

        let initialSourceCount = taskCount(from: sourceColumn)
        let initialDestinationCount = taskCount(from: destinationColumn)
        XCTAssertNotNil(initialSourceCount, "Expected parseable source column count")
        XCTAssertNotNil(initialDestinationCount, "Expected parseable destination column count")
        let expectedSourceCount = (initialSourceCount ?? 0) - 1
        let expectedDestinationCount = (initialDestinationCount ?? 0) + 1

        sourceTaskCard.press(forDuration: 0.5, thenDragTo: destinationColumn)

        let movedTask = app.descendants(matching: .any).matching(identifier: "task-card-task-1").firstMatch
        XCTAssertTrue(movedTask.waitForExistence(timeout: 3), "Expected moved task to remain visible")

        XCTAssertTrue(
            waitForCountValue(element: sourceColumn, equals: expectedSourceCount, timeout: 3),
            "Expected source column count to become \(expectedSourceCount)"
        )
        XCTAssertTrue(
            waitForCountValue(element: destinationColumn, equals: expectedDestinationCount, timeout: 3),
            "Expected destination column count to become \(expectedDestinationCount)"
        )
    }

    @MainActor
    private func launchSignedInApp() -> XCUIApplication {
        let app = configuredAppForUITests()
        app.launchEnvironment[UITestEnvKey.signedIn] = "1"
        app.launchEnvironment[UITestEnvKey.email] = "ui-test@example.com"
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), "Expected app window after launch")
        return app
    }

    private func taskCount(from element: XCUIElement) -> Int? {
        let text = (element.value as? String) ?? element.label
        let digits = text.split(whereSeparator: { !$0.isNumber })
        guard let first = digits.first else { return nil }
        return Int(first)
    }

    private func waitForCountValue(element: XCUIElement, equals expected: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let current = taskCount(from: element)
            if current == expected {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }
}
