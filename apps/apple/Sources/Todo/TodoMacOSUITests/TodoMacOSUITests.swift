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
        let topInsetCandidates = [
            window.frame.maxY - title.frame.maxY,
            title.frame.minY - window.frame.minY
        ].filter { $0 >= 0 }
        let topInset = max(0, topInsetCandidates.min() ?? 0)
        let horizontalInsetRatio = horizontalInset / max(window.frame.width, 1)
        let topInsetRatio = topInset / max(window.frame.height, 1)

        XCTAssertGreaterThanOrEqual(horizontalInset, 0)
        XCTAssertGreaterThanOrEqual(topInset, 0)
        XCTAssertLessThan(horizontalInsetRatio, 0.2)
        XCTAssertLessThan(topInsetRatio, 0.25)
    }

    @MainActor
    func testOverflowingColumnTaskListScrollsWithoutPushingWorkspaceOutOfBounds() throws {
        // Requirement: UX-008
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "28"])
        let uiTimeout: TimeInterval = 8

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: uiTimeout), "Expected app window")

        let title = app.staticTexts["workspace-board-title"]
        XCTAssertTrue(title.waitForExistence(timeout: uiTimeout), "Expected workspace title")

        let taskList = app.scrollViews["column-task-list-column-work"]
        XCTAssertTrue(taskList.waitForExistence(timeout: uiTimeout), "Expected scrollable task list in work column")

        let firstTask = app.staticTexts["task-title-task-1"]
        let overflowTask = app.staticTexts["task-title-task-28"]
        XCTAssertTrue(firstTask.waitForExistence(timeout: uiTimeout), "Expected first task in work column")
        XCTAssertTrue(
            scrollUntilHittable(element: overflowTask, in: taskList, maxSwipes: 12),
            "Expected deep task to become hittable via vertical scrolling"
        )

        let horizontalInset = title.frame.minX - window.frame.minX
        let topInsetCandidates = [
            window.frame.maxY - title.frame.maxY,
            title.frame.minY - window.frame.minY
        ].filter { $0 >= 0 }
        let topInset = max(0, topInsetCandidates.min() ?? 0)
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
        let perElementTimeout: TimeInterval = 2
        let taskCardPrefix = "task-card-"
        let taskTitlePrefix = "task-title-"
        let columnDropZonePrefix = "column-drop-zone-"
        let columnTaskCountPrefix = "column-task-count-"
        let sourceTaskCardID = "\(taskCardPrefix)task-1"
        let sourceTaskTitleID = "\(taskTitlePrefix)task-1"
        let sourceColumnDropZoneID = "\(columnDropZonePrefix)column-work"
        let destinationColumnDropZoneID = "\(columnDropZonePrefix)column-empty"
        let sourceColumnCountID = "\(columnTaskCountPrefix)column-work"
        let destinationColumnCountID = "\(columnTaskCountPrefix)column-empty"

        let sourceTaskCardByID = app.descendants(matching: .any).matching(identifier: sourceTaskCardID).firstMatch
        let sourceTaskCardFallback = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", taskCardPrefix)).element(boundBy: 0)
        let sourceTaskCard = preferredElement(primary: sourceTaskCardByID, fallback: sourceTaskCardFallback, waitTimeout: perElementTimeout)
        let sourceTaskTitleByID = app.descendants(matching: .any).matching(identifier: sourceTaskTitleID).firstMatch
        let sourceTaskTitleFallback = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", taskTitlePrefix)).firstMatch
        let sourceTaskTitle = preferredElement(primary: sourceTaskTitleByID, fallback: sourceTaskTitleFallback, waitTimeout: perElementTimeout)

        let columnDropZones = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", columnDropZonePrefix))
        let sourceColumnByID = app.descendants(matching: .any).matching(identifier: sourceColumnDropZoneID).firstMatch
        let destinationColumnByID = app.descendants(matching: .any).matching(identifier: destinationColumnDropZoneID).firstMatch
        let sourceColumnFallback = columnDropZones.element(boundBy: 0)
        let destinationColumnFallback = columnDropZones.element(boundBy: 1)
        let sourceColumn = preferredElement(primary: sourceColumnByID, fallback: sourceColumnFallback, waitTimeout: perElementTimeout)
        let destinationColumn = preferredElement(primary: destinationColumnByID, fallback: destinationColumnFallback, waitTimeout: perElementTimeout)

        let columnTaskCounts = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", columnTaskCountPrefix))
        let sourceColumnCountByID = app.staticTexts[sourceColumnCountID]
        let destinationColumnCountByID = app.staticTexts[destinationColumnCountID]
        let sourceColumnCountFallback = columnTaskCounts.element(boundBy: 0)
        let destinationColumnCountFallback = columnTaskCounts.element(boundBy: 1)
        let sourceColumnCount = preferredElement(primary: sourceColumnCountByID, fallback: sourceColumnCountFallback, waitTimeout: perElementTimeout)
        let destinationColumnCount = preferredElement(primary: destinationColumnCountByID, fallback: destinationColumnCountFallback, waitTimeout: perElementTimeout)

        XCTAssertTrue(app.staticTexts["workspace-board-title"].waitForExistence(timeout: uiTimeout), "Expected board workspace title")
        guard columnDropZones.count >= 2 else {
            XCTFail("Expected at least two board columns. UI:\n\(app.debugDescription)")
            return
        }
        guard sourceTaskCard.exists || sourceTaskTitle.exists else {
            XCTFail("Expected draggable source task. UI:\n\(app.debugDescription)")
            return
        }
        XCTAssertTrue(sourceColumn.waitForExistence(timeout: uiTimeout), "Expected source column drop zone")
        XCTAssertTrue(destinationColumn.waitForExistence(timeout: uiTimeout), "Expected destination column drop zone")
        XCTAssertGreaterThanOrEqual(columnTaskCounts.count, 2, "Expected task counters for both columns")

        let dragSource = sourceTaskCard.exists ? sourceTaskCard : sourceTaskTitle

        let initialSourceCount = taskCount(from: sourceColumnCount)
        let initialDestinationCount = taskCount(from: destinationColumnCount)
        XCTAssertNotNil(initialSourceCount, "Expected parseable source column count")
        XCTAssertNotNil(initialDestinationCount, "Expected parseable destination column count")
        let expectedSourceCount = (initialSourceCount ?? 0) - 1
        let expectedDestinationCount = (initialDestinationCount ?? 0) + 1

        dragSource.press(forDuration: 0.5, thenDragTo: destinationColumn)

        XCTAssertTrue(
            waitForCountValue(element: sourceColumnCount, equals: expectedSourceCount, timeout: 3),
            "Expected source column count to become \(expectedSourceCount)"
        )
        XCTAssertTrue(
            waitForCountValue(element: destinationColumnCount, equals: expectedDestinationCount, timeout: 3),
            "Expected destination column count to become \(expectedDestinationCount)"
        )
    }

    @MainActor
    func testDropTaskOnColumnHeaderDoesNotFail() throws {
        // Requirement: UX-007
        let app = launchSignedInApp()
        let uiTimeout: TimeInterval = 8
        let perElementTimeout: TimeInterval = 2

        let sourceColumn = columnDropZoneElement(in: app, columnID: "column-work", fallbackIndex: 0, waitTimeout: perElementTimeout)
        let sourceColumnHeader = columnHeaderElement(in: app, columnID: "column-work", fallbackIndex: 0, waitTimeout: perElementTimeout)
        let sourceColumnCount = columnTaskCountElement(in: app, columnID: "column-work", fallbackIndex: 0, waitTimeout: perElementTimeout)

        XCTAssertTrue(app.staticTexts["workspace-board-title"].waitForExistence(timeout: uiTimeout), "Expected board workspace title")
        guard let dragSource = sourceTaskDragElement(in: app, waitTimeout: perElementTimeout) else {
            XCTFail("Expected draggable source task. UI:\n\(app.debugDescription)")
            return
        }
        XCTAssertTrue(sourceColumn.waitForExistence(timeout: uiTimeout), "Expected source column drop zone")
        XCTAssertTrue(sourceColumnHeader.waitForExistence(timeout: uiTimeout), "Expected source column header")

        let initialSourceCount = taskCount(from: sourceColumnCount)
        XCTAssertNotNil(initialSourceCount, "Expected parseable source column count")

        dragSource.press(forDuration: 0.5, thenDragTo: sourceColumnHeader)

        XCTAssertTrue(
            waitForCountValue(element: sourceColumnCount, equals: initialSourceCount ?? 0, timeout: 3),
            "Expected source column count to remain stable after dropping on source column header"
        )
        assertNoDropError(in: app, context: "same-column header drop")
    }

    @MainActor
    func testDropTaskOnDestinationColumnHeaderDoesNotFail() throws {
        // Requirement: UX-007
        let app = launchSignedInApp()
        let uiTimeout: TimeInterval = 8
        let perElementTimeout: TimeInterval = 2

        let destinationColumnHeader = columnHeaderElement(in: app, columnID: "column-empty", fallbackIndex: 1, waitTimeout: perElementTimeout)
        let sourceColumnCount = columnTaskCountElement(in: app, columnID: "column-work", fallbackIndex: 0, waitTimeout: perElementTimeout)
        let destinationColumnCount = columnTaskCountElement(in: app, columnID: "column-empty", fallbackIndex: 1, waitTimeout: perElementTimeout)

        XCTAssertTrue(app.staticTexts["workspace-board-title"].waitForExistence(timeout: uiTimeout), "Expected board workspace title")
        guard let dragSource = sourceTaskDragElement(in: app, waitTimeout: perElementTimeout) else {
            XCTFail("Expected draggable source task. UI:\n\(app.debugDescription)")
            return
        }
        XCTAssertTrue(destinationColumnHeader.waitForExistence(timeout: uiTimeout), "Expected destination column header")

        let initialSourceCount = taskCount(from: sourceColumnCount)
        let initialDestinationCount = taskCount(from: destinationColumnCount)
        XCTAssertNotNil(initialSourceCount, "Expected parseable source column count")
        XCTAssertNotNil(initialDestinationCount, "Expected parseable destination column count")

        dragSource.press(forDuration: 0.5, thenDragTo: destinationColumnHeader)

        XCTAssertTrue(
            waitForCountValue(element: sourceColumnCount, equals: (initialSourceCount ?? 0) - 1, timeout: 3),
            "Expected source column count to decrement after dropping on destination column header"
        )
        XCTAssertTrue(
            waitForCountValue(element: destinationColumnCount, equals: (initialDestinationCount ?? 0) + 1, timeout: 3),
            "Expected destination column count to increment after dropping on destination column header"
        )
        assertNoDropError(in: app, context: "destination-header drop")
    }

    @MainActor
    private func launchSignedInApp(extraEnvironment: [String: String] = [:]) -> XCUIApplication {
        let app = configuredAppForUITests()
        app.launchEnvironment[UITestEnvKey.signedIn] = "1"
        app.launchEnvironment[UITestEnvKey.email] = "ui-test@example.com"
        for (key, value) in extraEnvironment {
            app.launchEnvironment[key] = value
        }
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), "Expected app window after launch")
        return app
    }

    private func scrollUntilHittable(element: XCUIElement, in scrollView: XCUIElement, maxSwipes: Int) -> Bool {
        if element.waitForExistence(timeout: 0.2), element.isHittable {
            return true
        }

        for _ in 0..<maxSwipes {
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            let finish = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
            start.press(forDuration: 0.05, thenDragTo: finish)
            if !element.isHittable {
                scrollView.swipeUp()
            }
            if element.waitForExistence(timeout: 0.2), element.isHittable {
                return true
            }
        }

        return element.exists && element.isHittable
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

    private func preferredElement(primary: XCUIElement, fallback: XCUIElement, waitTimeout: TimeInterval) -> XCUIElement {
        primary.waitForExistence(timeout: waitTimeout) ? primary : fallback
    }

    private func sourceTaskDragElement(in app: XCUIApplication, waitTimeout: TimeInterval) -> XCUIElement? {
        let sourceTaskCard = preferredElement(
            primary: app.descendants(matching: .any).matching(identifier: "task-card-task-1").firstMatch,
            fallback: app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "task-card-")).element(boundBy: 0),
            waitTimeout: waitTimeout
        )
        if sourceTaskCard.exists {
            return sourceTaskCard
        }

        let sourceTaskTitle = preferredElement(
            primary: app.descendants(matching: .any).matching(identifier: "task-title-task-1").firstMatch,
            fallback: app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "task-title-")).firstMatch,
            waitTimeout: waitTimeout
        )
        return sourceTaskTitle.exists ? sourceTaskTitle : nil
    }

    private func columnDropZoneElement(in app: XCUIApplication, columnID: String, fallbackIndex: Int, waitTimeout: TimeInterval) -> XCUIElement {
        preferredElement(
            primary: app.descendants(matching: .any).matching(identifier: "column-drop-zone-\(columnID)").firstMatch,
            fallback: app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "column-drop-zone-")).element(boundBy: fallbackIndex),
            waitTimeout: waitTimeout
        )
    }

    private func columnHeaderElement(in app: XCUIApplication, columnID: String, fallbackIndex: Int, waitTimeout: TimeInterval) -> XCUIElement {
        preferredElement(
            primary: app.staticTexts["column-title-\(columnID)"],
            fallback: app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "column-title-")).element(boundBy: fallbackIndex),
            waitTimeout: waitTimeout
        )
    }

    private func columnTaskCountElement(in app: XCUIApplication, columnID: String, fallbackIndex: Int, waitTimeout: TimeInterval) -> XCUIElement {
        preferredElement(
            primary: app.staticTexts["column-task-count-\(columnID)"],
            fallback: app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "column-task-count-")).element(boundBy: fallbackIndex),
            waitTimeout: waitTimeout
        )
    }

    private func assertNoDropError(in app: XCUIApplication, context: String) {
        XCTAssertFalse(
            app.otherElements["board-dev-diagnostics"].waitForExistence(timeout: 1),
            "Expected no error diagnostics after \(context)"
        )
        let statusMessage = app.staticTexts["board-status-message"]
        if statusMessage.waitForExistence(timeout: 0.2) {
            XCTAssertFalse(
                statusMessage.label.localizedCaseInsensitiveContains("invalid input"),
                "Expected status message to avoid invalid-input errors after \(context): \(statusMessage.label)"
            )
        }
    }
}
