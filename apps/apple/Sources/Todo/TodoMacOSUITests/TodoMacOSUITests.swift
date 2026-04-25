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
    func testBoardLoadingOverlayAppearsDuringSlowLoad() throws {
        // Requirements: UX-009, UX-011
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.mockDelayMs: "1500"])

        let editModeToggle = app.buttons["board-edit-mode-toggle"]
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: 6), "Expected edit mode toggle after initial board load")
        XCTAssertTrue(waitUntil(timeout: 6) { editModeToggle.isEnabled }, "Expected board interactions to be enabled before refresh")

        let settingsButton = app.buttons["board-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3), "Expected settings button")
        settingsButton.tap()

        let refreshButton = preferredElement(
            primary: app.buttons["board-refresh-button"],
            fallback: app.buttons["Refresh"],
            waitTimeout: 3
        )
        XCTAssertTrue(refreshButton.exists, "Expected refresh button")
        refreshButton.tap()

        let loadingOverlay = app.otherElements["board-loading-overlay"]
        XCTAssertTrue(loadingOverlay.waitForExistence(timeout: 2), "Expected board loading overlay during pending refresh")
        XCTAssertTrue(waitUntil(timeout: 2) { !editModeToggle.isHittable }, "Expected interactions blocked while overlay is visible")

        XCTAssertTrue(
            waitUntil(timeout: 8) { !loadingOverlay.exists },
            "Expected board loading overlay to disappear after refresh completes"
        )
        XCTAssertTrue(waitUntil(timeout: 3) { editModeToggle.isHittable }, "Expected interactions to be re-enabled after loading")
    }

    @MainActor
    func testSettingsButtonAnchorsTopRightAndShowsActions() throws {
        // Requirements: UX-010, UX-011, UX-012, UX-022
        let app = launchSignedInApp()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Expected app window")

        let settingsButton = app.buttons["board-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Expected settings button")

        let rightInset = window.frame.maxX - settingsButton.frame.maxX
        let topInsetCandidates = [
            window.frame.maxY - settingsButton.frame.maxY,
            settingsButton.frame.minY - window.frame.minY
        ].filter { $0 >= 0 }
        let topInset = max(0, topInsetCandidates.min() ?? 0)
        let rightInsetRatio = rightInset / max(window.frame.width, 1)
        let topInsetRatio = topInset / max(window.frame.height, 1)

        XCTAssertGreaterThanOrEqual(rightInset, 0)
        XCTAssertGreaterThanOrEqual(topInset, 0)
        XCTAssertLessThan(rightInsetRatio, 0.2)
        XCTAssertLessThan(topInsetRatio, 0.25)

        settingsButton.tap()

        let refreshButton = preferredElement(
            primary: app.buttons["board-refresh-button"],
            fallback: app.buttons["Refresh"],
            waitTimeout: 3
        )
        let signOutButton = preferredElement(
            primary: app.buttons["board-settings-signout-button"],
            fallback: app.buttons["Sign out"],
            waitTimeout: 3
        )
        let exportButton = preferredElement(
            primary: app.buttons["board-settings-export-button"],
            fallback: app.buttons["Export tasks"],
            waitTimeout: 5
        )
        let importButton = preferredElement(
            primary: app.buttons["board-settings-import-button"],
            fallback: app.buttons["Import tasks"],
            waitTimeout: 5
        )
        let shortcutsSection = app.otherElements["board-settings-shortcuts-section"]
        let shortcutsTitle = app.staticTexts["board-settings-shortcuts-title"]
        let shortcutsSelect = app.staticTexts["board-settings-shortcuts-select"]
        let shortcutsClear = app.staticTexts["board-settings-shortcuts-clear"]
        let shortcutsTopBottom = app.staticTexts["board-settings-shortcuts-top-bottom"]
        let shortcutsUpDown = app.staticTexts["board-settings-shortcuts-up-down"]
        let shortcutsEditDelete = app.staticTexts["board-settings-shortcuts-edit-delete"]

        XCTAssertTrue(refreshButton.exists, "Expected refresh action in settings")
        XCTAssertTrue(signOutButton.exists, "Expected sign-out action in settings")
        XCTAssertTrue(exportButton.exists, "Expected export action in settings")
        XCTAssertTrue(importButton.exists, "Expected import action in settings")
        XCTAssertTrue(shortcutsSection.exists, "Expected shortcuts section in settings")
        XCTAssertTrue(shortcutsTitle.exists, "Expected shortcuts title in settings")
        XCTAssertTrue(shortcutsSelect.exists, "Expected shortcuts select guidance")
        XCTAssertTrue(shortcutsClear.exists, "Expected shortcuts clear-selection guidance")
        XCTAssertTrue(shortcutsTopBottom.exists, "Expected shortcuts top/bottom guidance")
        XCTAssertTrue(shortcutsUpDown.exists, "Expected shortcuts up/down guidance")
        XCTAssertTrue(shortcutsEditDelete.exists, "Expected shortcuts edit/delete guidance")
    }

    @MainActor
    func testCreateAndRenameBoardFromHeaderAndEditBoardPanel() throws {
        // Requirements: BOARD-009, BOARD-010, BOARD-011, UX-014, UX-016, UX-017
        let app = launchSignedInApp()

        let boardSelector = app.popUpButtons["board-selector-picker"]
        let createButton = app.buttons["board-create-button"]
        let editModeToggle = app.buttons["board-edit-mode-toggle"]
        let titleLabel = app.staticTexts["workspace-board-title"]

        XCTAssertTrue(boardSelector.waitForExistence(timeout: 5), "Expected board selector")
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Expected create-board button")
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: 5), "Expected edit-board button")
        XCTAssertTrue(titleLabel.waitForExistence(timeout: 5), "Expected workspace title")

        createButton.tap()

        let boardEditorTitleInput = preferredElement(
            primary: app.textFields["board-editor-title-input"],
            fallback: app.textFields["Board title"],
            waitTimeout: 3
        )
        let boardEditorSubmit = preferredElement(
            primary: app.buttons["board-editor-submit"],
            fallback: app.buttons["Create"],
            waitTimeout: 3
        )
        if !boardEditorTitleInput.waitForExistence(timeout: 3) {
            app.activate()
            if createButton.exists {
                createButton.tap()
            }
        }
        XCTAssertTrue(boardEditorTitleInput.waitForExistence(timeout: 3), "Expected board title input")
        XCTAssertTrue(boardEditorSubmit.waitForExistence(timeout: 3), "Expected board editor submit button")

        boardEditorTitleInput.tap()
        boardEditorTitleInput.typeText("New Board")
        boardEditorSubmit.tap()

        XCTAssertTrue(
            app.staticTexts["New Board"].waitForExistence(timeout: 3),
            "Expected new board title after create"
        )

        editModeToggle.tap()
        let renameButton = app.buttons["board-edit-rename-button"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: 3), "Expected rename-board button in edit board panel")
        renameButton.tap()
        if !boardEditorTitleInput.waitForExistence(timeout: 3) {
            app.activate()
            if editModeToggle.exists {
                editModeToggle.tap()
            }
            if renameButton.exists {
                renameButton.tap()
            }
        }
        XCTAssertTrue(boardEditorTitleInput.waitForExistence(timeout: 3), "Expected board title input for rename")

        boardEditorTitleInput.click()
        boardEditorTitleInput.typeKey("a", modifierFlags: .command)
        boardEditorTitleInput.typeText("Board Renamed")
        let renameSubmit = preferredElement(
            primary: app.buttons["board-editor-submit"],
            fallback: app.buttons["Save"],
            waitTimeout: 2
        )
        renameSubmit.tap()

        XCTAssertTrue(
            app.staticTexts["Board Renamed"].waitForExistence(timeout: 3),
            "Expected board title after rename"
        )
    }

    @MainActor
    func testEditBoardPanelCloseDismissesEditMode() throws {
        // Requirement: UX-018
        let app = launchSignedInApp()

        let editModeToggle = app.buttons["board-edit-mode-toggle"]
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: 5), "Expected edit-board button")

        editModeToggle.tap()

        let closeButton = app.buttons["board-edit-close-button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Expected close button in edit board panel")
        closeButton.tap()

        XCTAssertTrue(
            waitUntil(timeout: 3) { !closeButton.exists },
            "Expected edit board panel to dismiss after close"
        )
    }

    @MainActor
    func testDeleteBoardAvailableOnlyWhenBoardHasNoTasks() throws {
        // Requirements: BOARD-013, UX-019
        let app = launchSignedInApp()

        let createButton = app.buttons["board-create-button"]
        let editModeToggle = app.buttons["board-edit-mode-toggle"]

        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Expected create-board button")
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: 5), "Expected edit-board button")

        editModeToggle.tap()
        let deleteButton = app.buttons["board-edit-delete-button"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Expected delete-board button in edit board panel")
        XCTAssertFalse(deleteButton.isEnabled, "Expected delete-board action disabled when board has tasks")

        let closeButton = app.buttons["board-edit-close-button"]
        if closeButton.waitForExistence(timeout: 2) {
            closeButton.tap()
        }

        createButton.tap()
        let boardEditorTitleInput = preferredElement(
            primary: app.textFields["board-editor-title-input"],
            fallback: app.textFields["Board title"],
            waitTimeout: 3
        )
        let boardEditorSubmit = preferredElement(
            primary: app.buttons["board-editor-submit"],
            fallback: app.buttons["Create"],
            waitTimeout: 3
        )
        XCTAssertTrue(boardEditorTitleInput.waitForExistence(timeout: 3), "Expected board title input")
        boardEditorTitleInput.tap()
        boardEditorTitleInput.typeText("Board To Delete")
        boardEditorSubmit.tap()

        XCTAssertTrue(app.staticTexts["Board To Delete"].waitForExistence(timeout: 3), "Expected created board title")

        editModeToggle.tap()
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Expected delete-board button")
        XCTAssertTrue(deleteButton.isEnabled, "Expected delete-board action enabled on empty board")
        deleteButton.tap()

        let deleteConfirm = app.sheets.firstMatch.buttons["Delete"].firstMatch
        XCTAssertTrue(deleteConfirm.waitForExistence(timeout: 3), "Expected delete confirmation action")
        deleteConfirm.tap()

        XCTAssertTrue(
            waitUntil(timeout: 3) { app.staticTexts["UI Test Board"].exists },
            "Expected fallback board title after deleting empty board"
        )
    }

    @MainActor
    func testArchivedBoardDeleteRequiresConfirmation() throws {
        // Requirements: BOARD-017, UX-021
        let app = launchSignedInApp()

        let createButton = app.buttons["board-create-button"]
        let editModeToggle = app.buttons["board-edit-mode-toggle"]
        let settingsButton = app.buttons["board-settings-button"]

        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Expected create-board button")
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: 5), "Expected edit-board button")
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Expected settings button")

        createButton.tap()
        let boardEditorTitleInput = preferredElement(
            primary: app.textFields["board-editor-title-input"],
            fallback: app.textFields["Board title"],
            waitTimeout: 3
        )
        let boardEditorSubmit = preferredElement(
            primary: app.buttons["board-editor-submit"],
            fallback: app.buttons["Create"],
            waitTimeout: 3
        )
        XCTAssertTrue(boardEditorTitleInput.waitForExistence(timeout: 3), "Expected board title input")
        boardEditorTitleInput.tap()
        boardEditorTitleInput.typeText("Archive Me")
        boardEditorSubmit.tap()
        XCTAssertTrue(app.staticTexts["Archive Me"].waitForExistence(timeout: 3), "Expected created board title")

        editModeToggle.tap()
        let archiveButton = app.buttons["board-edit-archive-button"]
        XCTAssertTrue(archiveButton.waitForExistence(timeout: 3), "Expected archive button")
        archiveButton.tap()

        XCTAssertTrue(
            waitUntil(timeout: 3) { app.staticTexts["UI Test Board"].exists },
            "Expected fallback board after archive"
        )
        XCTAssertTrue(
            app.staticTexts["board-status-message"].waitForExistence(timeout: 3),
            "Expected board status message after archive"
        )
        XCTAssertTrue(
            waitUntil(timeout: 3) { !archiveButton.exists },
            "Expected edit board panel to close after archive"
        )

        settingsButton.tap()
        let archivedDeleteButton = app.buttons["board-archived-delete-row-0"]
        XCTAssertTrue(archivedDeleteButton.waitForExistence(timeout: 5), "Expected archived delete button")

        archivedDeleteButton.tap()
        let deletePermanent = app.sheets.firstMatch.buttons["Delete permanently"]
        XCTAssertTrue(deletePermanent.waitForExistence(timeout: 3), "Expected delete confirmation action")
        let cancelDelete = app.sheets.firstMatch.buttons["Cancel"]
        XCTAssertTrue(cancelDelete.waitForExistence(timeout: 2), "Expected cancel action in confirmation")
        cancelDelete.tap()

        XCTAssertTrue(archivedDeleteButton.waitForExistence(timeout: 2), "Expected archived board to remain after cancel")

        archivedDeleteButton.tap()
        XCTAssertTrue(deletePermanent.waitForExistence(timeout: 3), "Expected delete confirmation action")
        deletePermanent.tap()

        XCTAssertTrue(
            waitUntil(timeout: 3) { !archivedDeleteButton.exists },
            "Expected archived board delete button to disappear after confirmation"
        )
    }

    @MainActor
    func testExportFromSettingsShowsSavePanel() throws {
        // Requirements: UX-012, UX-013
        let app = launchSignedInApp(extraEnvironment: [
            UITestEnvKey.columnCount: "4",
            UITestEnvKey.workTaskCount: "50",
            UITestEnvKey.spreadTasksAcrossColumns: "1"
        ])

        XCTAssertTrue(app.staticTexts["column-title-column-1"].waitForExistence(timeout: 5), "Expected column 1")
        XCTAssertTrue(app.staticTexts["column-title-column-2"].waitForExistence(timeout: 5), "Expected column 2")
        XCTAssertTrue(app.staticTexts["column-title-column-3"].waitForExistence(timeout: 5), "Expected column 3")
        XCTAssertTrue(app.staticTexts["column-title-column-4"].waitForExistence(timeout: 5), "Expected column 4")

        let settingsButton = app.buttons["board-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Expected settings button")

        settingsButton.tap()

        let exportButton = preferredElement(
            primary: app.buttons["board-settings-export-button"],
            fallback: app.buttons["Export tasks"],
            waitTimeout: 5
        )
        XCTAssertTrue(exportButton.exists, "Expected export action in settings")

        exportButton.tap()

        XCTAssertTrue(
            waitUntil(timeout: 5) {
                !app.otherElements["board-settings-sheet"].exists
            },
            "Expected settings sheet to dismiss after tapping export"
        )

        let exportSubmitButton = preferredElement(
            primary: app.buttons["Export"],
            fallback: app.buttons["Save"],
            waitTimeout: 5
        )
        XCTAssertTrue(exportSubmitButton.exists, "Expected export save panel submit button")

        let savePanelContainer: XCUIElement
        if app.dialogs.firstMatch.exists {
            savePanelContainer = app.dialogs.firstMatch
        } else {
            savePanelContainer = app.sheets.firstMatch
        }

        let cancelButton = savePanelContainer.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Expected cancel button on export save panel")
        cancelButton.tap()
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
    func testTaskMoveButtonsReorderWithinColumn() throws {
        // Requirement: TASK-008
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "3"])
        let uiTimeout: TimeInterval = 8

        let firstTaskTitle = app.staticTexts["task-title-task-1"]
        let secondTaskTitle = app.staticTexts["task-title-task-2"]
        let moveDownButton = app.buttons["task-move-down-task-1"]
        let moveUpButton = app.buttons["task-move-up-task-1"]

        XCTAssertTrue(firstTaskTitle.waitForExistence(timeout: uiTimeout), "Expected first task title")
        XCTAssertTrue(secondTaskTitle.waitForExistence(timeout: uiTimeout), "Expected second task title")
        XCTAssertTrue(moveDownButton.waitForExistence(timeout: uiTimeout), "Expected move-down button for first task")
        XCTAssertTrue(moveUpButton.waitForExistence(timeout: uiTimeout), "Expected move-up button for first task")

        XCTAssertTrue(moveDownButton.isEnabled, "Expected move-down enabled for first task")
        XCTAssertFalse(moveUpButton.isEnabled, "Expected move-up disabled for first task at top")
        XCTAssertLessThan(firstTaskTitle.frame.minY, secondTaskTitle.frame.minY, "Expected task-1 above task-2 before move")

        moveDownButton.tap()

        XCTAssertTrue(
            waitUntil(timeout: 3) { firstTaskTitle.frame.minY > secondTaskTitle.frame.minY },
            "Expected task-1 below task-2 after moving down"
        )
    }

    @MainActor
    func testTaskTopBottomButtonsMoveTaskToColumnExtremes() throws {
        // Requirement: TASK-009
        // Requirement: TASK-010
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "4"])
        let uiTimeout: TimeInterval = 8

        let taskOneTitle = app.staticTexts["task-title-task-1"]
        let taskThreeTitle = app.staticTexts["task-title-task-3"]
        let taskFourTitle = app.staticTexts["task-title-task-4"]
        let taskThreeCard = taskCardElement(in: app, taskID: "task-3", waitTimeout: uiTimeout)
        let moveTopButton = app.buttons["task-move-top-task-3"]
        let moveBottomButton = app.buttons["task-move-bottom-task-3"]
        let taskOneMoveTopButton = app.buttons["task-move-top-task-1"]
        let taskFourMoveBottomButton = app.buttons["task-move-bottom-task-4"]

        XCTAssertTrue(taskOneTitle.waitForExistence(timeout: uiTimeout), "Expected task-1 title")
        XCTAssertTrue(taskThreeTitle.waitForExistence(timeout: uiTimeout), "Expected task-3 title")
        XCTAssertTrue(taskFourTitle.waitForExistence(timeout: uiTimeout), "Expected task-4 title")
        XCTAssertTrue(taskThreeCard.waitForExistence(timeout: uiTimeout), "Expected task-3 card")
        XCTAssertTrue(moveTopButton.waitForExistence(timeout: uiTimeout), "Expected move-top button for task-3")
        XCTAssertTrue(moveBottomButton.waitForExistence(timeout: uiTimeout), "Expected move-bottom button for task-3")
        XCTAssertTrue(taskOneMoveTopButton.waitForExistence(timeout: uiTimeout), "Expected move-top button for task-1")
        XCTAssertTrue(taskFourMoveBottomButton.waitForExistence(timeout: uiTimeout), "Expected move-bottom button for task-4")

        XCTAssertTrue(moveTopButton.isEnabled, "Expected move-top enabled for middle task")
        XCTAssertTrue(moveBottomButton.isEnabled, "Expected move-bottom enabled for middle task")
        XCTAssertFalse(taskOneMoveTopButton.isEnabled, "Expected move-top disabled for first task")
        XCTAssertFalse(taskFourMoveBottomButton.isEnabled, "Expected move-bottom disabled for last task")
        XCTAssertLessThan(moveTopButton.frame.minX, moveBottomButton.frame.minX, "Expected move-top to be left of move-bottom")
        XCTAssertLessThan(moveTopButton.frame.midX, taskThreeCard.frame.midX, "Expected move-top near left side of task card")
        XCTAssertGreaterThan(moveBottomButton.frame.midX, taskThreeCard.frame.midX, "Expected move-bottom near right side of task card")
        XCTAssertLessThan(moveTopButton.frame.maxY, taskThreeTitle.frame.minY, "Expected move-top above task title")
        XCTAssertLessThan(moveBottomButton.frame.maxY, taskThreeTitle.frame.minY, "Expected move-bottom above task title")
        XCTAssertGreaterThan(taskThreeTitle.frame.minY, taskOneTitle.frame.minY, "Expected task-3 below task-1 before move")

        moveTopButton.tap()

        XCTAssertTrue(
            waitUntil(timeout: 3) { taskThreeTitle.frame.minY < taskOneTitle.frame.minY },
            "Expected task-3 above task-1 after moving to top"
        )

        moveBottomButton.tap()

        XCTAssertTrue(
            waitUntil(timeout: 3) { taskThreeTitle.frame.minY > taskFourTitle.frame.minY },
            "Expected task-3 below task-4 after moving to bottom"
        )
    }

    @MainActor
    func testTaskSelectionEnablesTopBottomKeyboardShortcuts() throws {
        // Requirements: TASK-012, TASK-013
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "4"])
        let uiTimeout: TimeInterval = 8

        let taskOneTitle = app.staticTexts["task-title-task-1"]
        let taskThreeTitle = app.staticTexts["task-title-task-3"]
        let taskFourTitle = app.staticTexts["task-title-task-4"]
        let taskThreeCard = taskCardElement(in: app, taskID: "task-3", waitTimeout: uiTimeout)

        XCTAssertTrue(taskOneTitle.waitForExistence(timeout: uiTimeout), "Expected task-1 title")
        XCTAssertTrue(taskThreeTitle.waitForExistence(timeout: uiTimeout), "Expected task-3 title")
        XCTAssertTrue(taskFourTitle.waitForExistence(timeout: uiTimeout), "Expected task-4 title")
        XCTAssertTrue(taskThreeCard.waitForExistence(timeout: uiTimeout), "Expected task-3 card")

        taskThreeCard.click()
        app.typeKey("t", modifierFlags: [])

        XCTAssertTrue(
            waitUntil(timeout: 3) { taskThreeTitle.frame.minY < taskOneTitle.frame.minY },
            "Expected task-3 above task-1 after pressing t"
        )

        taskThreeCard.click()
        app.typeKey("b", modifierFlags: [])

        XCTAssertTrue(
            waitUntil(timeout: 3) { taskThreeTitle.frame.minY > taskFourTitle.frame.minY },
            "Expected task-3 below task-4 after pressing b"
        )
    }

    @MainActor
    func testTaskSelectionEnablesUpDownKeyboardShortcuts() throws {
        // Requirements: TASK-015, TASK-016
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "4"])
        let uiTimeout: TimeInterval = 8

        let taskTwoTitle = app.staticTexts["task-title-task-2"]
        let taskThreeTitle = app.staticTexts["task-title-task-3"]
        let taskThreeCard = taskCardElement(in: app, taskID: "task-3", waitTimeout: uiTimeout)

        XCTAssertTrue(taskTwoTitle.waitForExistence(timeout: uiTimeout), "Expected task-2 title")
        XCTAssertTrue(taskThreeTitle.waitForExistence(timeout: uiTimeout), "Expected task-3 title")
        XCTAssertTrue(taskThreeCard.waitForExistence(timeout: uiTimeout), "Expected task-3 card")
        XCTAssertGreaterThan(taskThreeTitle.frame.minY, taskTwoTitle.frame.minY, "Expected task-3 below task-2 before shortcuts")

        taskThreeCard.click()
        app.typeKey("u", modifierFlags: [])

        XCTAssertTrue(
            waitUntil(timeout: 3) { taskThreeTitle.frame.minY < taskTwoTitle.frame.minY },
            "Expected task-3 above task-2 after pressing u"
        )

        taskThreeCard.click()
        app.typeKey("d", modifierFlags: [])

        XCTAssertTrue(
            waitUntil(timeout: 3) { taskThreeTitle.frame.minY > taskTwoTitle.frame.minY },
            "Expected task-3 below task-2 after pressing d"
        )
    }

    @MainActor
    func testTaskSelectionEnablesEditDeleteKeyboardShortcuts() throws {
        // Requirements: TASK-017, TASK-018
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "4"])
        let uiTimeout: TimeInterval = 8

        let taskOneCard = taskCardElement(in: app, taskID: "task-1", waitTimeout: uiTimeout)
        let editSheet = preferredElement(
            primary: app.otherElements["task-editor-sheet"],
            fallback: app.staticTexts["Edit task"],
            waitTimeout: uiTimeout
        )

        XCTAssertTrue(taskOneCard.waitForExistence(timeout: uiTimeout), "Expected task-1 card")

        taskOneCard.click()
        app.typeKey("e", modifierFlags: [])
        XCTAssertTrue(editSheet.waitForExistence(timeout: uiTimeout), "Expected edit task sheet after pressing e")

        let cancelEditButton = preferredElement(
            primary: app.buttons["task-editor-cancel"],
            fallback: app.buttons["Cancel"],
            waitTimeout: uiTimeout
        )
        XCTAssertTrue(cancelEditButton.waitForExistence(timeout: uiTimeout), "Expected cancel action in edit sheet")
        cancelEditButton.tap()

        taskOneCard.click()
        app.typeKey("x", modifierFlags: [])

        let deleteAction = preferredElement(
            primary: app.buttons["task-delete-confirm-action"],
            fallback: app.sheets.firstMatch.buttons["Delete task"],
            waitTimeout: uiTimeout
        )
        XCTAssertTrue(deleteAction.waitForExistence(timeout: uiTimeout), "Expected delete confirmation after pressing x")

        let cancelDeleteButton = preferredElement(
            primary: app.buttons["task-delete-confirm-cancel"],
            fallback: app.sheets.firstMatch.buttons["Cancel"],
            waitTimeout: uiTimeout
        )
        XCTAssertTrue(cancelDeleteButton.waitForExistence(timeout: uiTimeout), "Expected cancel action in delete confirmation")
        cancelDeleteButton.tap()
    }

    @MainActor
    func testEscapeClearsTaskSelectionForKeyboardShortcuts() throws {
        // Requirement: TASK-014
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "4"])
        let uiTimeout: TimeInterval = 8

        let taskOneTitle = app.staticTexts["task-title-task-1"]
        let taskThreeTitle = app.staticTexts["task-title-task-3"]
        let taskThreeCard = taskCardElement(in: app, taskID: "task-3", waitTimeout: uiTimeout)

        XCTAssertTrue(taskOneTitle.waitForExistence(timeout: uiTimeout), "Expected task-1 title")
        XCTAssertTrue(taskThreeTitle.waitForExistence(timeout: uiTimeout), "Expected task-3 title")
        XCTAssertTrue(taskThreeCard.waitForExistence(timeout: uiTimeout), "Expected task-3 card")
        XCTAssertGreaterThan(taskThreeTitle.frame.minY, taskOneTitle.frame.minY, "Expected task-3 below task-1 before shortcuts")

        taskThreeCard.click()
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        app.typeKey("t", modifierFlags: [])

        XCTAssertFalse(
            waitUntil(timeout: 1.5) { taskThreeTitle.frame.minY < taskOneTitle.frame.minY },
            "Expected task-3 not to move after escape clears selection"
        )
    }

    @MainActor
    func testCreateTaskAppearsInSelectedColumn() throws {
        // Requirement: TASK-011
        let app = launchSignedInApp()
        let uiTimeout: TimeInterval = 8

        let emptyColumnTaskCount = app.staticTexts["column-task-count-column-empty"]
        let addTaskButton = app.buttons["task-add-column-empty"]
        let createSheetTitle = preferredElement(
            primary: app.otherElements["task-editor-sheet"],
            fallback: app.staticTexts["Create task"],
            waitTimeout: uiTimeout
        )
        let taskTitleField = preferredElement(
            primary: app.textFields["task-editor-title-input"],
            fallback: app.textFields["Task title"],
            waitTimeout: uiTimeout
        )
        let createButton = preferredElement(
            primary: app.buttons["task-editor-submit"],
            fallback: app.buttons["Create"],
            waitTimeout: uiTimeout
        )
        let createdTaskTitle = "Created in empty column"

        XCTAssertTrue(emptyColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected empty column task count")
        XCTAssertTrue(addTaskButton.waitForExistence(timeout: uiTimeout), "Expected add-task button for empty column")
        XCTAssertTrue(waitForCountValue(element: emptyColumnTaskCount, equals: 0, timeout: 3), "Expected empty column to start with zero tasks")

        addTaskButton.tap()

        XCTAssertTrue(createSheetTitle.waitForExistence(timeout: uiTimeout), "Expected create-task sheet title")
        XCTAssertTrue(taskTitleField.waitForExistence(timeout: uiTimeout), "Expected task title input")

        taskTitleField.tap()
        taskTitleField.typeText(createdTaskTitle)
        createButton.tap()

        XCTAssertTrue(
            waitForCountValue(element: emptyColumnTaskCount, equals: 1, timeout: 3),
            "Expected empty column task count to increase after creating task"
        )
        XCTAssertTrue(
            app.staticTexts[createdTaskTitle].waitForExistence(timeout: uiTimeout),
            "Expected created task title to be visible"
        )
    }

    @MainActor
    func testCreateTaskWithHundredExistingTasksKeepsTaskInSelectedColumn() throws {
        // Requirement: TASK-011
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "100"])
        let uiTimeout: TimeInterval = 8

        let workColumnTaskCount = app.staticTexts["column-task-count-column-work"]
        let emptyColumnTaskCount = app.staticTexts["column-task-count-column-empty"]
        let addTaskButton = app.buttons["task-add-column-empty"]
        let taskTitleField = preferredElement(
            primary: app.textFields["task-editor-title-input"],
            fallback: app.textFields["Task title"],
            waitTimeout: uiTimeout
        )
        let createButton = preferredElement(
            primary: app.buttons["task-editor-submit"],
            fallback: app.buttons["Create"],
            waitTimeout: uiTimeout
        )
        let createdTaskTitle = "Created with 100 tasks"

        XCTAssertTrue(workColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected work column task count")
        XCTAssertTrue(emptyColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected empty column task count")
        XCTAssertTrue(addTaskButton.waitForExistence(timeout: uiTimeout), "Expected add-task button for empty column")
        XCTAssertTrue(waitForCountValue(element: workColumnTaskCount, equals: 100, timeout: 3), "Expected work column to start with 100 tasks")
        XCTAssertTrue(waitForCountValue(element: emptyColumnTaskCount, equals: 0, timeout: 3), "Expected empty column to start with 0 tasks")

        addTaskButton.tap()

        XCTAssertTrue(taskTitleField.waitForExistence(timeout: uiTimeout), "Expected task title input")
        taskTitleField.tap()
        taskTitleField.typeText(createdTaskTitle)
        createButton.tap()

        XCTAssertTrue(
            waitForCountValue(element: emptyColumnTaskCount, equals: 1, timeout: 3),
            "Expected empty column count to increment after create"
        )
        XCTAssertTrue(
            waitForCountValue(element: workColumnTaskCount, equals: 100, timeout: 3),
            "Expected work column count to remain unchanged after create in empty column"
        )
        XCTAssertTrue(
            app.staticTexts[createdTaskTitle].waitForExistence(timeout: uiTimeout),
            "Expected created task to be visible in selected column"
        )
    }

    @MainActor
    func testReorderColumnsFromEditBoardModal() throws {
        // Requirement: COL-MOVE-009
        let app = launchSignedInApp()
        let uiTimeout: TimeInterval = 8
        let perElementTimeout: TimeInterval = 2

        let workColumnCard = columnDropZoneElement(in: app, columnID: "column-work", fallbackIndex: 0, waitTimeout: perElementTimeout)
        let emptyColumnCard = columnDropZoneElement(in: app, columnID: "column-empty", fallbackIndex: 1, waitTimeout: perElementTimeout)
        let editModeToggle = app.buttons["board-edit-mode-toggle"]
        let openReorderButton = app.buttons["board-edit-reorder-button"]
        let reorderSheet = app.sheets.firstMatch
        let reorderContainer = app.otherElements["board-reorder-sheet"]
        let moveLeftButton = app.descendants(matching: .button).matching(identifier: "board-reorder-move-left-column-empty").firstMatch
        let doneButton = preferredElement(
            primary: app.buttons["board-reorder-done"],
            fallback: app.buttons["Done"],
            waitTimeout: 2
        )

        XCTAssertTrue(workColumnCard.waitForExistence(timeout: uiTimeout), "Expected work column card")
        XCTAssertTrue(emptyColumnCard.waitForExistence(timeout: uiTimeout), "Expected empty column card")
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: uiTimeout), "Expected board edit mode toggle")
        XCTAssertTrue(waitUntil(timeout: uiTimeout) { editModeToggle.isEnabled }, "Expected board edit mode toggle to be enabled")
        editModeToggle.tap()
        XCTAssertTrue(openReorderButton.waitForExistence(timeout: uiTimeout), "Expected reorder action in edit board sheet")
        openReorderButton.tap()
        XCTAssertTrue(
            reorderSheet.waitForExistence(timeout: uiTimeout) || reorderContainer.waitForExistence(timeout: uiTimeout),
            "Expected reorder sheet"
        )
        XCTAssertTrue(moveLeftButton.waitForExistence(timeout: uiTimeout), "Expected move-left button for empty column. UI:\n\(app.debugDescription)")
        XCTAssertGreaterThan(emptyColumnCard.frame.minX, workColumnCard.frame.minX)

        moveLeftButton.tap()
        XCTAssertTrue(doneButton.waitForExistence(timeout: uiTimeout), "Expected Done button in reorder sheet")
        doneButton.tap()
        XCTAssertTrue(
            waitUntil(timeout: 3) { !moveLeftButton.exists && !reorderContainer.exists },
            "Expected reorder modal to dismiss after tapping Done"
        )

        XCTAssertTrue(
            waitUntil(timeout: 3) { emptyColumnCard.frame.minX < workColumnCard.frame.minX },
            "Expected empty column to move before work column after modal reorder"
        )
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

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    private func preferredElement(primary: XCUIElement, fallback: XCUIElement, waitTimeout: TimeInterval) -> XCUIElement {
        primary.waitForExistence(timeout: waitTimeout) ? primary : fallback
    }

    private func sourceTaskDragElement(in app: XCUIApplication, waitTimeout: TimeInterval) -> XCUIElement? {
        let sourceTaskCard = taskCardElement(in: app, taskID: "task-1", waitTimeout: waitTimeout)
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

    private func taskCardElement(in app: XCUIApplication, taskID: String, waitTimeout: TimeInterval) -> XCUIElement {
        preferredElement(
            primary: app.otherElements["task-card-\(taskID)"],
            fallback: app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "task-card-")).firstMatch,
            waitTimeout: waitTimeout
        )
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
