//
//  TodoMacOSUITests.swift
//  TodoMacOSUITests
//
//  Created by christian on 2026-04-18.
//

import XCTest

final class TodoMacOSUITests: XCTestCase {
    private enum UITimeout {
        static let launch: TimeInterval = 5
        static let ready: TimeInterval = 6
        static let standard: TimeInterval = 3
        static let extended: TimeInterval = 8
    }

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
        // @req TEST-UI-001
        // UI tests must launch the application that they test.
        let app = configuredAppForUITests()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // @req TEST-UI-002
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = configuredAppForUITests()
            app.launch()
        }
    }

    @MainActor
    func testDeleteTaskConfirmationCancelAndConfirm() throws {
        // @req TASK-DEL-001, TASK-DEL-002, TASK-DEL-003, TASK-DEL-004, UX-003
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
        // @req UX-001
        let app = launchSignedInApp()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: UITimeout.ready), "Expected app window")

        let title = app.staticTexts["workspace-board-title"]
        XCTAssertTrue(title.waitForExistence(timeout: UITimeout.ready), "Expected workspace title")

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
        // @req UX-009, UX-011
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.mockDelayMs: "1500"])

        let editModeToggle = app.buttons["board-edit-mode-toggle"]
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: 6), "Expected edit mode toggle after initial board load")
        XCTAssertTrue(waitUntil(timeout: 6) { editModeToggle.isEnabled }, "Expected board interactions to be enabled before refresh")

        let settingsButton = app.buttons["board-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3), "Expected settings button")
        XCTAssertTrue(openSettingsSheet(in: app, trigger: settingsButton), "Expected settings sheet")

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
        // @req UX-010, UX-011, UX-012, UX-022, UX-023, UX-043
        let app = launchSignedInApp()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: UITimeout.ready), "Expected app window")

        let settingsButton = app.buttons["board-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: UITimeout.ready), "Expected settings button")

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
        let shortcutsTitle = app.staticTexts["board-settings-shortcuts-title"]
        let shortcutsSelect = app.staticTexts["board-settings-shortcuts-select"]
        let shortcutsClear = app.staticTexts["board-settings-shortcuts-clear"]
        let shortcutsColumnPicker = app.staticTexts["board-settings-shortcuts-column-picker"]
        let shortcutsCreate = app.staticTexts["board-settings-shortcuts-create"]
        let shortcutsTopBottom = app.staticTexts["board-settings-shortcuts-top-bottom"]
        let shortcutsUpDown = app.staticTexts["board-settings-shortcuts-up-down"]
        let shortcutsEditDelete = app.staticTexts["board-settings-shortcuts-edit-delete"]
        let shortcutsArchivedActions = app.staticTexts["board-settings-shortcuts-archived-actions"]
        let taskControlsTitle = app.staticTexts["board-settings-task-controls-title"]
        let topBottomToggle = app.checkBoxes["board-settings-task-controls-top-bottom"]
        let upDownToggle = app.checkBoxes["board-settings-task-controls-up-down"]
        let editDeleteToggle = app.checkBoxes["board-settings-task-controls-edit-delete"]
        let archivedActionsToggle = app.checkBoxes["board-settings-task-controls-archived-actions"]

        XCTAssertTrue(refreshButton.exists, "Expected refresh action in settings")
        XCTAssertTrue(signOutButton.exists, "Expected sign-out action in settings")
        XCTAssertTrue(exportButton.exists, "Expected export action in settings")
        XCTAssertTrue(importButton.exists, "Expected import action in settings")
        XCTAssertTrue(shortcutsTitle.exists, "Expected shortcuts title in settings")
        XCTAssertTrue(shortcutsSelect.exists, "Expected shortcuts select guidance")
        XCTAssertTrue(shortcutsClear.exists, "Expected shortcuts clear-selection guidance")
        XCTAssertTrue(shortcutsColumnPicker.exists, "Expected shortcuts column-picker guidance")
        XCTAssertTrue(shortcutsCreate.exists, "Expected shortcuts create guidance")
        XCTAssertTrue(shortcutsTopBottom.exists, "Expected shortcuts top/bottom guidance")
        XCTAssertTrue(shortcutsUpDown.exists, "Expected shortcuts up/down guidance")
        XCTAssertTrue(shortcutsEditDelete.exists, "Expected shortcuts edit/delete guidance")
        XCTAssertTrue(shortcutsArchivedActions.exists, "Expected shortcuts archived actions guidance")
        XCTAssertTrue(taskControlsTitle.exists, "Expected task-controls title in settings")
        XCTAssertTrue(topBottomToggle.exists, "Expected top/bottom visibility toggle")
        XCTAssertTrue(upDownToggle.exists, "Expected up/down visibility toggle")
        XCTAssertTrue(editDeleteToggle.exists, "Expected edit/delete visibility toggle")
        XCTAssertTrue(archivedActionsToggle.exists, "Expected archived-action visibility toggle")
    }

    @MainActor
    func testCreateAndRenameBoardFromHeaderAndEditBoardPanel() throws {
        // @req BOARD-009, BOARD-010, BOARD-011, UX-014, UX-016, UX-017, UX-046
        let app = launchSignedInApp()

        let boardSelector = app.popUpButtons["board-selector-picker"]
        let createButton = app.buttons["board-create-button"]
        let editModeToggle = app.buttons["board-edit-mode-toggle"]
        let titleLabel = app.staticTexts["workspace-board-title"]

        XCTAssertTrue(boardSelector.waitForExistence(timeout: UITimeout.ready), "Expected board selector")
        XCTAssertTrue(createButton.waitForExistence(timeout: UITimeout.ready), "Expected create-board button")
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: UITimeout.ready), "Expected edit-board button")
        XCTAssertTrue(titleLabel.waitForExistence(timeout: UITimeout.ready), "Expected workspace title")

        createButton.tap()

        let boardEditorTitleInput = preferredElement(
            primary: app.textFields["board-editor-title-input"],
            fallback: app.textFields["Board title"],
            waitTimeout: UITimeout.standard
        )
        let boardEditorSubmit = preferredElement(
            primary: app.buttons["board-editor-submit"],
            fallback: app.buttons["Create"],
            waitTimeout: UITimeout.standard
        )
        if !boardEditorTitleInput.waitForExistence(timeout: UITimeout.standard) {
            app.activate()
            if createButton.exists {
                createButton.tap()
            }
        }
        XCTAssertTrue(boardEditorTitleInput.waitForExistence(timeout: UITimeout.standard), "Expected board title input")
        XCTAssertTrue(boardEditorSubmit.waitForExistence(timeout: UITimeout.standard), "Expected board editor submit button")

        boardEditorTitleInput.tap()
        boardEditorTitleInput.typeText("New Board")
        boardEditorSubmit.tap()

        XCTAssertTrue(
            app.staticTexts["New Board"].waitForExistence(timeout: UITimeout.standard),
            "Expected new board title after create"
        )
        XCTAssertTrue(
            waitUntil(timeout: 3) { titleLabel.label == "New Board" },
            "Expected newly created board to become active"
        )

        editModeToggle.tap()
        let renameButton = app.buttons["board-edit-rename-button"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: UITimeout.standard), "Expected rename-board button in edit board panel")
        renameButton.tap()
        if !boardEditorTitleInput.waitForExistence(timeout: UITimeout.standard) {
            app.activate()
            if editModeToggle.exists {
                editModeToggle.tap()
            }
            if renameButton.exists {
                renameButton.tap()
            }
        }
        XCTAssertTrue(boardEditorTitleInput.waitForExistence(timeout: UITimeout.standard), "Expected board title input for rename")

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
            app.staticTexts["Board Renamed"].waitForExistence(timeout: UITimeout.standard),
            "Expected board title after rename"
        )
    }

    @MainActor
    func testCreateBoardTitleInputEnterSubmitsCreate() throws {
        // @req BOARD-025
        let app = launchSignedInApp()
        let createButton = app.buttons["board-create-button"]

        XCTAssertTrue(createButton.waitForExistence(timeout: UITimeout.ready), "Expected create-board button")

        createButton.tap()

        let boardEditorTitleInput = preferredElement(
            primary: app.textFields["board-editor-title-input"],
            fallback: app.textFields["Board title"],
            waitTimeout: UITimeout.standard
        )
        XCTAssertTrue(boardEditorTitleInput.waitForExistence(timeout: UITimeout.standard), "Expected board title input")

        let boardTitle = "Board Created Via Enter"
        boardEditorTitleInput.tap()
        boardEditorTitleInput.typeText(boardTitle)
        boardEditorTitleInput.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])

        XCTAssertTrue(
            app.staticTexts[boardTitle].waitForExistence(timeout: UITimeout.standard),
            "Expected new board title after pressing enter in board title input"
        )
    }

    @MainActor
    func testEditBoardPanelCloseDismissesEditMode() throws {
        // @req UX-018
        let app = launchSignedInApp()

        let editModeToggle = app.buttons["board-edit-mode-toggle"]
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: UITimeout.ready), "Expected edit-board button")

        editModeToggle.tap()

        let closeButton = app.buttons["board-edit-close-button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: UITimeout.standard), "Expected close button in edit board panel")
        closeButton.tap()

        XCTAssertTrue(
            waitUntil(timeout: 3) { !closeButton.exists },
            "Expected edit board panel to dismiss after close"
        )
    }

    @MainActor
    func testDeleteBoardAvailableOnlyWhenBoardHasNoTasks() throws {
        // @req BOARD-013, UX-019
        let app = launchSignedInApp()

        let createButton = app.buttons["board-create-button"]
        let editModeToggle = app.buttons["board-edit-mode-toggle"]

        XCTAssertTrue(createButton.waitForExistence(timeout: UITimeout.ready), "Expected create-board button")
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: UITimeout.ready), "Expected edit-board button")

        editModeToggle.tap()
        let deleteButton = app.buttons["board-edit-delete-button"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: UITimeout.standard), "Expected delete-board button in edit board panel")
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
        // @req BOARD-017, UX-021
        let app = launchSignedInApp()

        let createButton = app.buttons["board-create-button"]
        let editModeToggle = app.buttons["board-edit-mode-toggle"]
        let settingsButton = app.buttons["board-settings-button"]

        XCTAssertTrue(createButton.waitForExistence(timeout: UITimeout.ready), "Expected create-board button")
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: UITimeout.ready), "Expected edit-board button")
        XCTAssertTrue(settingsButton.waitForExistence(timeout: UITimeout.ready), "Expected settings button")

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
            app.staticTexts["board-status-message"].waitForExistence(timeout: UITimeout.ready),
            "Expected status message after archive"
        )
        XCTAssertTrue(
            waitUntil(timeout: 3) { !archiveButton.exists },
            "Expected edit board panel to close after archive"
        )

        XCTAssertTrue(
            waitUntil(timeout: UITimeout.ready) { settingsButton.exists && settingsButton.isHittable },
            "Expected settings button to be hittable after archive"
        )
        XCTAssertTrue(openSettingsSheet(in: app, trigger: settingsButton), "Expected settings sheet")

        let settingsContainer = preferredElement(
            primary: app.sheets.firstMatch,
            fallback: app.otherElements["board-settings-sheet"],
            waitTimeout: UITimeout.standard
        )
        let archivedDeleteButton = preferredElement(
            primary: app.buttons["board-archived-delete-row-0"],
            fallback: settingsContainer.buttons.matching(NSPredicate(format: "label == %@", "Delete board")).firstMatch,
            waitTimeout: UITimeout.extended
        )
        XCTAssertTrue(archivedDeleteButton.exists, "Expected archived delete button. UI:\n\(app.debugDescription)")

        archivedDeleteButton.tap()
        let deletePermanent = preferredElement(
            primary: app.buttons["board-archived-delete-confirm-action"],
            fallback: preferredElement(
                primary: app.sheets.firstMatch.buttons["Delete permanently"],
                fallback: app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Delete")).firstMatch,
                waitTimeout: UITimeout.standard
            ),
            waitTimeout: UITimeout.standard
        )
        XCTAssertTrue(deletePermanent.exists, "Expected delete confirmation action")
        let cancelDelete = preferredElement(
            primary: app.buttons["board-archived-delete-confirm-cancel"],
            fallback: preferredElement(
                primary: app.sheets.firstMatch.buttons["Cancel"],
                fallback: app.buttons.matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch,
                waitTimeout: UITimeout.standard
            ),
            waitTimeout: UITimeout.standard
        )
        XCTAssertTrue(cancelDelete.exists, "Expected cancel action in confirmation")
        cancelDelete.tap()

        XCTAssertTrue(
            waitUntil(timeout: UITimeout.standard) { archivedDeleteButton.exists && archivedDeleteButton.isHittable },
            "Expected archived board to remain after cancel"
        )

        archivedDeleteButton.tap()
        XCTAssertTrue(deletePermanent.waitForExistence(timeout: UITimeout.standard), "Expected delete confirmation action")
        deletePermanent.tap()

        XCTAssertTrue(
            waitUntil(timeout: UITimeout.ready) { !archivedDeleteButton.exists },
            "Expected archived board delete button to disappear after confirmation"
        )
    }

    @MainActor
    func testRestoreArchivedBoardShowsTitleModePrompt() throws {
        // @req UX-027
        let app = launchSignedInApp()

        let createButton = app.buttons["board-create-button"]
        let editModeToggle = app.buttons["board-edit-mode-toggle"]
        let settingsButton = app.buttons["board-settings-button"]

        XCTAssertTrue(createButton.waitForExistence(timeout: UITimeout.ready), "Expected create-board button")
        XCTAssertTrue(editModeToggle.waitForExistence(timeout: UITimeout.ready), "Expected edit-board button")
        XCTAssertTrue(settingsButton.waitForExistence(timeout: UITimeout.ready), "Expected settings button")

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
        boardEditorTitleInput.typeText("Restore Me")
        boardEditorSubmit.tap()
        XCTAssertTrue(app.staticTexts["Restore Me"].waitForExistence(timeout: 3), "Expected created board title")

        editModeToggle.tap()
        let archiveButton = app.buttons["board-edit-archive-button"]
        XCTAssertTrue(archiveButton.waitForExistence(timeout: 3), "Expected archive button")
        archiveButton.tap()

        XCTAssertTrue(
            waitUntil(timeout: 3) { app.staticTexts["UI Test Board"].exists },
            "Expected fallback board after archive"
        )

        XCTAssertTrue(openSettingsSheet(in: app, trigger: settingsButton), "Expected settings sheet")
        let restoreButton = preferredElement(
            primary: app.buttons["board-archived-restore-row-0"],
            fallback: app.buttons["Restore"],
            waitTimeout: UITimeout.standard
        )
        XCTAssertTrue(restoreButton.exists, "Expected archived restore action")
        restoreButton.tap()

        let restoreSheet = preferredElement(
            primary: app.otherElements["board-restore-sheet"],
            fallback: app.sheets.firstMatch,
            waitTimeout: UITimeout.standard
        )
        XCTAssertTrue(restoreSheet.exists, "Expected restore mode prompt")
        XCTAssertTrue(
            waitUntil(timeout: UITimeout.standard) {
                app.otherElements["board-restore-title-mode-picker"].exists ||
                    restoreSheet.descendants(matching: .radioButton)["Keep archived title"].exists ||
                    restoreSheet.staticTexts["Restored title"].exists
            },
            "Expected restore title mode control"
        )

        let cancelButton = preferredElement(
            primary: app.buttons["board-restore-cancel-button"],
            fallback: app.buttons["Cancel"],
            waitTimeout: UITimeout.standard
        )
        XCTAssertTrue(cancelButton.exists, "Expected cancel button in restore prompt")
        cancelButton.tap()
    }

    @MainActor
    func testExportFromSettingsShowsSavePanel() throws {
        // @req UX-012, UX-013, UX-024, UX-026
        let app = launchSignedInApp(extraEnvironment: [
            UITestEnvKey.columnCount: "4",
            UITestEnvKey.workTaskCount: "50",
            UITestEnvKey.spreadTasksAcrossColumns: "1"
        ])

        XCTAssertTrue(app.staticTexts["column-title-column-1"].waitForExistence(timeout: UITimeout.ready), "Expected column 1")
        XCTAssertTrue(app.staticTexts["column-title-column-2"].waitForExistence(timeout: UITimeout.ready), "Expected column 2")
        XCTAssertTrue(app.staticTexts["column-title-column-3"].waitForExistence(timeout: UITimeout.ready), "Expected column 3")
        XCTAssertTrue(app.staticTexts["column-title-column-4"].waitForExistence(timeout: UITimeout.ready), "Expected column 4")

        let settingsButton = app.buttons["board-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: UITimeout.ready), "Expected settings button")

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

        let exportSelectionSheet = preferredElement(
            primary: app.otherElements["board-transfer-export-sheet"],
            fallback: app.sheets.firstMatch,
            waitTimeout: 5
        )
        XCTAssertTrue(exportSelectionSheet.exists, "Expected export board selection sheet")

        let exportSelectionSubmit = preferredElement(
            primary: app.buttons["board-transfer-export-submit-button"],
            fallback: preferredElement(
                primary: exportSelectionSheet.buttons["Continue"],
                fallback: app.buttons["Continue"],
                waitTimeout: 5
            ),
            waitTimeout: 5
        )
        XCTAssertTrue(exportSelectionSubmit.exists, "Expected export board selection submit button")
        XCTAssertTrue(exportSelectionSubmit.isEnabled, "Expected export board selection submit button to be enabled")
        exportSelectionSubmit.tap()

        let exportSubmitButton = preferredElement(
            primary: app.buttons["Export"],
            fallback: app.buttons["Save"],
            waitTimeout: 5
        )
        XCTAssertTrue(exportSubmitButton.waitForExistence(timeout: 5), "Expected export save panel submit button")

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
        // @req UX-008
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "28"])
        let uiTimeout = UITimeout.extended

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: uiTimeout), "Expected app window")

        let title = app.staticTexts["workspace-board-title"]
        XCTAssertTrue(title.waitForExistence(timeout: uiTimeout), "Expected workspace title")

        let workColumnTaskCount = app.staticTexts["column-task-count-column-work"]
        XCTAssertTrue(workColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected work column task count")
        XCTAssertTrue(waitForCountValue(element: workColumnTaskCount, equals: 28, timeout: uiTimeout), "Expected work column to contain 28 tasks")

        let taskList = app.scrollViews["column-task-list-column-work"]
        XCTAssertTrue(taskList.waitForExistence(timeout: uiTimeout), "Expected scrollable task list in work column")

        let firstTask = app.staticTexts["task-title-task-1"]
        XCTAssertTrue(firstTask.waitForExistence(timeout: uiTimeout), "Expected first task in work column")
        let initialFirstTaskMinY = firstTask.frame.minY
        XCTAssertTrue(
            scrollUntilMovedAwayFromInitialPosition(
                element: firstTask,
                in: taskList,
                initialMinY: initialFirstTaskMinY,
                maxSwipes: 12
            ),
            "Expected vertical task-list scrolling to move task content"
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
        // @req COL-DEL-001, COL-DEL-002, COL-DEL-003, COL-DEL-004, UX-003
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
        // @req UX-005
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended
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
        // @req UX-007
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended
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
        // @req TASK-008
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "3"])
        let uiTimeout = UITimeout.extended

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
        // @req TASK-009
        // @req TASK-010
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "4"])
        let uiTimeout = UITimeout.extended

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
    func testSettingsTaskControlTogglesHideButtonsAndPersistLocally() throws {
        // @req TASK-019, TASK-020, TASK-021, TASK-033, UX-023, UX-037, UX-043
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "4"])
        let uiTimeout = UITimeout.extended

        let moveTopButton = app.buttons["task-move-top-task-1"]
        let moveUpButton = app.buttons["task-move-up-task-1"]
        let editButton = app.buttons["task-edit-task-1"]
        let deleteButton = app.buttons["task-delete-task-1"]
        let archiveWorkTasksButton = app.buttons["column-archive-tasks-column-work"]
        let showArchivedToggle = app.checkBoxes["workspace-toggle-show-archived"]
        let archivedViewButton = app.buttons["archived-task-view-task-1"]
        let archivedRestoreButton = app.buttons["archived-task-restore-task-1"]
        let archivedDeleteButton = app.buttons["archived-task-delete-task-1"]

        XCTAssertTrue(moveTopButton.waitForExistence(timeout: uiTimeout), "Expected top button before toggle")
        XCTAssertTrue(moveUpButton.waitForExistence(timeout: uiTimeout), "Expected up button before toggle")
        XCTAssertTrue(editButton.waitForExistence(timeout: uiTimeout), "Expected edit button before toggle")
        XCTAssertTrue(deleteButton.waitForExistence(timeout: uiTimeout), "Expected delete button before toggle")
        XCTAssertTrue(archiveWorkTasksButton.waitForExistence(timeout: uiTimeout), "Expected archive tasks button")
        XCTAssertTrue(showArchivedToggle.waitForExistence(timeout: uiTimeout), "Expected show archived toggle")

        archiveWorkTasksButton.tap()
        showArchivedToggle.tap()

        XCTAssertTrue(archivedViewButton.waitForExistence(timeout: uiTimeout), "Expected archived view button before toggle")
        XCTAssertTrue(archivedRestoreButton.waitForExistence(timeout: uiTimeout), "Expected archived restore button before toggle")
        XCTAssertTrue(archivedDeleteButton.waitForExistence(timeout: uiTimeout), "Expected archived delete button before toggle")

        let settingsButton = app.buttons["board-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiTimeout), "Expected settings button")
        settingsButton.tap()

        let topBottomToggle = app.checkBoxes["board-settings-task-controls-top-bottom"]
        let upDownToggle = app.checkBoxes["board-settings-task-controls-up-down"]
        let editDeleteToggle = app.checkBoxes["board-settings-task-controls-edit-delete"]
        let archivedActionsToggle = app.checkBoxes["board-settings-task-controls-archived-actions"]
        let closeButton = preferredElement(
            primary: app.buttons["board-settings-close-button"],
            fallback: app.buttons["Close"],
            waitTimeout: uiTimeout
        )

        XCTAssertTrue(topBottomToggle.waitForExistence(timeout: uiTimeout), "Expected top/bottom toggle")
        XCTAssertTrue(upDownToggle.waitForExistence(timeout: uiTimeout), "Expected up/down toggle")
        XCTAssertTrue(editDeleteToggle.waitForExistence(timeout: uiTimeout), "Expected edit/delete toggle")
        XCTAssertTrue(archivedActionsToggle.waitForExistence(timeout: uiTimeout), "Expected archived actions toggle")
        XCTAssertTrue(closeButton.waitForExistence(timeout: uiTimeout), "Expected close action in settings")

        setCheckbox(topBottomToggle, to: false)
        setCheckbox(upDownToggle, to: false)
        setCheckbox(editDeleteToggle, to: false)
        setCheckbox(archivedActionsToggle, to: false)
        closeButton.click()

        XCTAssertTrue(waitUntil(timeout: UITimeout.ready) { !app.otherElements["board-settings-sheet"].exists }, "Expected settings sheet to dismiss")

        XCTAssertTrue(waitUntil(timeout: UITimeout.ready) { !moveTopButton.exists }, "Expected top button hidden after toggle")
        XCTAssertTrue(waitUntil(timeout: UITimeout.ready) { !moveUpButton.exists }, "Expected up button hidden after toggle")
        XCTAssertTrue(waitUntil(timeout: UITimeout.ready) { !editButton.exists }, "Expected edit button hidden after toggle")
        XCTAssertTrue(waitUntil(timeout: UITimeout.ready) { !deleteButton.exists }, "Expected delete button hidden after toggle")
        XCTAssertTrue(waitUntil(timeout: UITimeout.ready) { !archivedViewButton.exists }, "Expected archived view button hidden after toggle")
        XCTAssertTrue(waitUntil(timeout: UITimeout.ready) { !archivedRestoreButton.exists }, "Expected archived restore button hidden after toggle")
        XCTAssertTrue(waitUntil(timeout: UITimeout.ready) { !archivedDeleteButton.exists }, "Expected archived delete button hidden after toggle")

        app.terminate()

        let relaunchedApp = launchSignedInApp(
            extraEnvironment: [UITestEnvKey.workTaskCount: "4"],
            resetTaskControlDefaults: false
        )

        XCTAssertFalse(
            relaunchedApp.buttons["task-move-top-task-1"].waitForExistence(timeout: 2),
            "Expected top button hidden after relaunch"
        )
        XCTAssertFalse(
            relaunchedApp.buttons["task-move-up-task-1"].waitForExistence(timeout: 2),
            "Expected up button hidden after relaunch"
        )
        XCTAssertFalse(
            relaunchedApp.buttons["task-edit-task-1"].waitForExistence(timeout: 2),
            "Expected edit button hidden after relaunch"
        )
        XCTAssertFalse(
            relaunchedApp.buttons["task-delete-task-1"].waitForExistence(timeout: 2),
            "Expected delete button hidden after relaunch"
        )

        let relaunchedArchiveTasksButton = relaunchedApp.buttons["column-archive-tasks-column-work"]
        let relaunchedShowArchivedToggle = relaunchedApp.checkBoxes["workspace-toggle-show-archived"]
        XCTAssertTrue(relaunchedArchiveTasksButton.waitForExistence(timeout: uiTimeout), "Expected archive tasks button after relaunch")
        XCTAssertTrue(relaunchedShowArchivedToggle.waitForExistence(timeout: uiTimeout), "Expected show archived toggle after relaunch")
        relaunchedArchiveTasksButton.tap()
        relaunchedShowArchivedToggle.tap()

        XCTAssertFalse(
            relaunchedApp.buttons["archived-task-view-task-1"].waitForExistence(timeout: 2),
            "Expected archived view button hidden after relaunch"
        )
        XCTAssertFalse(
            relaunchedApp.buttons["archived-task-restore-task-1"].waitForExistence(timeout: 2),
            "Expected archived restore button hidden after relaunch"
        )
        XCTAssertFalse(
            relaunchedApp.buttons["archived-task-delete-task-1"].waitForExistence(timeout: 2),
            "Expected archived delete button hidden after relaunch"
        )
    }

    @MainActor
    func testTaskSelectionEnablesTopBottomKeyboardShortcuts() throws {
        // @req TASK-012, TASK-013
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "4"])
        let uiTimeout = UITimeout.extended

        let taskOneTitle = app.staticTexts["task-title-task-1"]
        let taskThreeTitle = app.staticTexts["task-title-task-3"]
        let taskFourTitle = app.staticTexts["task-title-task-4"]
        let taskThreeCard = taskCardElement(in: app, taskID: "task-3", waitTimeout: uiTimeout)

        XCTAssertTrue(taskOneTitle.waitForExistence(timeout: uiTimeout), "Expected task-1 title")
        XCTAssertTrue(taskThreeTitle.waitForExistence(timeout: uiTimeout), "Expected task-3 title")
        XCTAssertTrue(taskFourTitle.waitForExistence(timeout: uiTimeout), "Expected task-4 title")
        XCTAssertTrue(taskThreeCard.waitForExistence(timeout: uiTimeout), "Expected task-3 card")

        for _ in 0..<3 {
            selectTaskForKeyboardShortcuts(taskID: "task-3", card: taskThreeCard, app: app)
            app.typeKey("t", modifierFlags: [])
            if waitUntil(timeout: 1.2) { taskThreeTitle.frame.minY < taskOneTitle.frame.minY } {
                break
            }
            app.typeText("t")
            if waitUntil(timeout: 1.2) { taskThreeTitle.frame.minY < taskOneTitle.frame.minY } {
                break
            }
        }

        XCTAssertTrue(
            waitUntil(timeout: UITimeout.ready) { taskThreeTitle.frame.minY < taskOneTitle.frame.minY },
            "Expected task-3 above task-1 after pressing t"
        )

        for _ in 0..<3 {
            selectTaskForKeyboardShortcuts(taskID: "task-3", card: taskThreeCard, app: app)
            app.typeKey("b", modifierFlags: [])
            if waitUntil(timeout: 1.2) { taskThreeTitle.frame.minY > taskFourTitle.frame.minY } {
                break
            }
            app.typeText("b")
            if waitUntil(timeout: 1.2) { taskThreeTitle.frame.minY > taskFourTitle.frame.minY } {
                break
            }
        }

        XCTAssertTrue(
            waitUntil(timeout: UITimeout.ready) { taskThreeTitle.frame.minY > taskFourTitle.frame.minY },
            "Expected task-3 below task-4 after pressing b"
        )
    }

    @MainActor
    func testTaskSelectionEnablesUpDownKeyboardShortcuts() throws {
        // @req TASK-015, TASK-016
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "4"])
        let uiTimeout = UITimeout.extended

        let taskTwoTitle = app.staticTexts["task-title-task-2"]
        let taskThreeTitle = app.staticTexts["task-title-task-3"]
        let taskThreeCard = taskCardElement(in: app, taskID: "task-3", waitTimeout: uiTimeout)

        XCTAssertTrue(taskTwoTitle.waitForExistence(timeout: uiTimeout), "Expected task-2 title")
        XCTAssertTrue(taskThreeTitle.waitForExistence(timeout: uiTimeout), "Expected task-3 title")
        XCTAssertTrue(taskThreeCard.waitForExistence(timeout: uiTimeout), "Expected task-3 card")
        XCTAssertGreaterThan(taskThreeTitle.frame.minY, taskTwoTitle.frame.minY, "Expected task-3 below task-2 before shortcuts")

        for _ in 0..<3 {
            selectTaskForKeyboardShortcuts(taskID: "task-3", card: taskThreeCard, app: app)
            app.typeKey("u", modifierFlags: [])
            if waitUntil(timeout: 1.2) { taskThreeTitle.frame.minY < taskTwoTitle.frame.minY } {
                break
            }
            app.typeText("u")
            if waitUntil(timeout: 1.2) { taskThreeTitle.frame.minY < taskTwoTitle.frame.minY } {
                break
            }
        }

        XCTAssertTrue(
            waitUntil(timeout: UITimeout.ready) { taskThreeTitle.frame.minY < taskTwoTitle.frame.minY },
            "Expected task-3 above task-2 after pressing u"
        )

        for _ in 0..<3 {
            selectTaskForKeyboardShortcuts(taskID: "task-3", card: taskThreeCard, app: app)
            app.typeKey("d", modifierFlags: [])
            if waitUntil(timeout: 1.2) { taskThreeTitle.frame.minY > taskTwoTitle.frame.minY } {
                break
            }
            app.typeText("d")
            if waitUntil(timeout: 1.2) { taskThreeTitle.frame.minY > taskTwoTitle.frame.minY } {
                break
            }
        }

        XCTAssertTrue(
            waitUntil(timeout: UITimeout.ready) { taskThreeTitle.frame.minY > taskTwoTitle.frame.minY },
            "Expected task-3 below task-2 after pressing d"
        )
    }

    @MainActor
    func testTaskSelectionEnablesEditDeleteKeyboardShortcuts() throws {
        // @req TASK-017, TASK-018
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "4"])
        let uiTimeout = UITimeout.extended

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
        // @req TASK-014
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "4"])
        let uiTimeout = UITimeout.extended

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
        // @req TASK-011, TASK-044, UX-045
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended

        let emptyColumnTaskCount = app.staticTexts["column-task-count-column-empty"]
        let addTaskButton = app.buttons["task-add-column-empty"]
        let emptyColumnDropZone = columnDropZoneElement(in: app, columnID: "column-empty", fallbackIndex: 1, waitTimeout: uiTimeout)
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
        let createdTaskTitle = "Created in empty column"

        XCTAssertTrue(emptyColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected empty column task count")
        XCTAssertTrue(emptyColumnDropZone.waitForExistence(timeout: uiTimeout), "Expected empty column container")
        XCTAssertTrue(addTaskButton.waitForExistence(timeout: uiTimeout), "Expected add-task button for empty column")
        XCTAssertTrue(waitForCountValue(element: emptyColumnTaskCount, equals: 0, timeout: 3), "Expected empty column to start with zero tasks")
        XCTAssertGreaterThanOrEqual(
            addTaskButton.frame.minX,
            emptyColumnDropZone.frame.minX,
            "Expected add-task button to align with left edge of selected column"
        )
        XCTAssertLessThanOrEqual(
            addTaskButton.frame.minX,
            emptyColumnDropZone.frame.minX + 40,
            "Expected add-task button to stay near left edge of selected column"
        )

        addTaskButton.tap()

        if !createSheetTitle.waitForExistence(timeout: UITimeout.standard) {
            app.activate()
            if addTaskButton.exists {
                addTaskButton.tap()
            }
        }

        XCTAssertTrue(createSheetTitle.waitForExistence(timeout: uiTimeout), "Expected create-task sheet title")
        XCTAssertTrue(taskTitleField.waitForExistence(timeout: uiTimeout), "Expected task title input")
        let sheetPickers = app.otherElements["task-editor-sheet"].descendants(matching: .picker)
        XCTAssertEqual(sheetPickers.count, 0, "Expected create-task sheet opened from column action to have no column selector")
        let createButtonQuery = app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR label == %@", "task-editor-submit", "Create")
        )
        guard let createButton = firstHittableElement(in: createButtonQuery, timeout: uiTimeout) else {
            XCTFail("Expected create-task submit button")
            return
        }

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
    func testColumnShortcutPickerSelectsSecondColumnForKeyboardCreate() throws {
        // @req TASK-011, TASK-042, TASK-043
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended

        let workColumnTaskCount = app.staticTexts["column-task-count-column-work"]
        let emptyColumnTaskCount = app.staticTexts["column-task-count-column-empty"]
        let taskOneCard = taskCardElement(in: app, taskID: "task-1", waitTimeout: uiTimeout)
        let appWindow = app.windows.firstMatch
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
        let createdTaskTitle = "Created with shortcut target"

        XCTAssertTrue(workColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected work column task count")
        XCTAssertTrue(emptyColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected empty column task count")
        XCTAssertTrue(taskOneCard.waitForExistence(timeout: uiTimeout), "Expected task card for keyboard focus")
        XCTAssertTrue(waitForCountValue(element: workColumnTaskCount, equals: 1, timeout: 3), "Expected work column initial count")
        XCTAssertTrue(waitForCountValue(element: emptyColumnTaskCount, equals: 0, timeout: 3), "Expected empty column initial count")

        dismissBlockingSheetsIfPresent(app: app)
        app.activate()
        appWindow.click()
        selectTaskForKeyboardShortcuts(taskID: "task-1", card: taskOneCard, app: app)
        for _ in 0..<5 {
            dismissBlockingSheetsIfPresent(app: app)
            app.activate()
            appWindow.click()
            selectTaskForKeyboardShortcuts(taskID: "task-1", card: taskOneCard, app: app)
            sendKeyboardInputWithFallback("a", to: appWindow, attempts: 2)
            sendKeyboardInputWithFallback("s", to: appWindow, attempts: 2)
            sendKeyboardInputWithFallback(XCUIKeyboardKey.return.rawValue, to: appWindow, attempts: 2) {
                createSheetTitle.waitForExistence(timeout: 0.8)
            }
            if createSheetTitle.exists {
                break
            }
        }

        XCTAssertTrue(createSheetTitle.waitForExistence(timeout: uiTimeout), "Expected create-task sheet from keyboard shortcut flow")
        XCTAssertTrue(taskTitleField.waitForExistence(timeout: uiTimeout), "Expected task title input")

        taskTitleField.tap()
        taskTitleField.typeText(createdTaskTitle)
        sendKeyboardInputWithFallback(XCUIKeyboardKey.return.rawValue, to: appWindow, attempts: 4) {
            self.waitForCountValue(element: emptyColumnTaskCount, equals: 1, timeout: 1.2)
        }

        XCTAssertTrue(
            waitForCountValue(element: emptyColumnTaskCount, equals: 1, timeout: 3),
            "Expected task created in second column selected via keyboard picker"
        )
        XCTAssertTrue(
            waitForCountValue(element: workColumnTaskCount, equals: 1, timeout: 3),
            "Expected first column count unchanged when keyboard target is second column"
        )
        XCTAssertTrue(
            app.staticTexts[createdTaskTitle].waitForExistence(timeout: uiTimeout),
            "Expected shortcut-created task title visible"
        )
    }

    @MainActor
    func testCreateTaskTitleInputEnterSubmitsCreate() throws {
        // @req TASK-022
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended

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
        let createdTaskTitle = "Created via enter"

        XCTAssertTrue(emptyColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected empty column task count")
        XCTAssertTrue(addTaskButton.waitForExistence(timeout: uiTimeout), "Expected add-task button for empty column")
        XCTAssertTrue(waitForCountValue(element: emptyColumnTaskCount, equals: 0, timeout: 3), "Expected empty column to start with zero tasks")

        addTaskButton.tap()

        XCTAssertTrue(createSheetTitle.waitForExistence(timeout: uiTimeout), "Expected create-task sheet title")
        XCTAssertTrue(taskTitleField.waitForExistence(timeout: uiTimeout), "Expected task title input")

        taskTitleField.tap()
        taskTitleField.typeText(createdTaskTitle)
        taskTitleField.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])

        XCTAssertTrue(
            waitForCountValue(element: emptyColumnTaskCount, equals: 1, timeout: 3),
            "Expected empty column task count to increase after pressing enter in title input"
        )
        XCTAssertTrue(
            app.staticTexts[createdTaskTitle].waitForExistence(timeout: uiTimeout),
            "Expected task created via enter to be visible"
        )
    }

    @MainActor
    func testCreateTaskDescriptionInputEnterSubmitsAndShiftEnterDoesNot() throws {
        // @req TASK-022, TASK-045
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended

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
        let taskDescriptionInput = preferredElement(
            primary: app.textViews["task-editor-description-input"],
            fallback: app.textViews.firstMatch,
            waitTimeout: uiTimeout
        )
        let createdTaskTitle = "Created via description enter"

        XCTAssertTrue(emptyColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected empty column task count")
        XCTAssertTrue(addTaskButton.waitForExistence(timeout: uiTimeout), "Expected add-task button for empty column")
        XCTAssertTrue(waitForCountValue(element: emptyColumnTaskCount, equals: 0, timeout: 3), "Expected empty column to start with zero tasks")

        addTaskButton.tap()

        XCTAssertTrue(createSheetTitle.waitForExistence(timeout: uiTimeout), "Expected create-task sheet title")
        XCTAssertTrue(taskTitleField.waitForExistence(timeout: uiTimeout), "Expected task title input")
        XCTAssertTrue(taskDescriptionInput.waitForExistence(timeout: uiTimeout), "Expected task description input")

        taskTitleField.tap()
        taskTitleField.typeText(createdTaskTitle)

        taskDescriptionInput.tap()
        taskDescriptionInput.typeText("first line")
        taskDescriptionInput.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [.shift])
        taskDescriptionInput.typeText("second line")

        XCTAssertTrue(createSheetTitle.exists, "Expected create-task sheet to remain open after shift-enter in description")
        XCTAssertTrue(
            waitForCountValue(element: emptyColumnTaskCount, equals: 0, timeout: 1),
            "Expected shift-enter in description to avoid submit"
        )

        taskDescriptionInput.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])

        XCTAssertTrue(
            waitForCountValue(element: emptyColumnTaskCount, equals: 1, timeout: 3),
            "Expected enter in description input to submit create"
        )
        XCTAssertTrue(
            app.staticTexts[createdTaskTitle].waitForExistence(timeout: uiTimeout),
            "Expected task created via description enter to be visible"
        )
    }

    @MainActor
    func testCreateTaskWithHundredExistingTasksKeepsTaskInSelectedColumn() throws {
        // @req TASK-011
        let app = launchSignedInApp(extraEnvironment: [UITestEnvKey.workTaskCount: "100"])
        let uiTimeout = UITimeout.extended

        let workColumnTaskCount = app.staticTexts["column-task-count-column-work"]
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
        let createdTaskTitle = "Created with 100 tasks"

        XCTAssertTrue(workColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected work column task count")
        XCTAssertTrue(emptyColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected empty column task count")
        XCTAssertTrue(addTaskButton.waitForExistence(timeout: uiTimeout), "Expected add-task button for empty column")
        XCTAssertTrue(waitForCountValue(element: workColumnTaskCount, equals: 100, timeout: 3), "Expected work column to start with 100 tasks")
        XCTAssertTrue(waitForCountValue(element: emptyColumnTaskCount, equals: 0, timeout: 3), "Expected empty column to start with 0 tasks")

        addTaskButton.tap()

        if !createSheetTitle.waitForExistence(timeout: UITimeout.standard) {
            app.activate()
            if addTaskButton.exists {
                addTaskButton.tap()
            }
        }

        XCTAssertTrue(createSheetTitle.waitForExistence(timeout: uiTimeout), "Expected create-task sheet title")
        XCTAssertTrue(taskTitleField.waitForExistence(timeout: uiTimeout), "Expected task title input")
        let createButtonQuery = app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR label == %@", "task-editor-submit", "Create")
        )
        guard let createButton = firstHittableElement(in: createButtonQuery, timeout: uiTimeout) else {
            XCTFail("Expected create-task submit button")
            return
        }
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
    func testArchiveColumnTasksArchivesOnlySelectedColumn() throws {
        // @req COL-ARCH-002, COL-ARCH-003, COL-ARCH-004
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended

        let workColumnTaskCount = app.staticTexts["column-task-count-column-work"]
        let emptyColumnTaskCount = app.staticTexts["column-task-count-column-empty"]
        let archiveWorkTasksButton = app.buttons["column-archive-tasks-column-work"]

        XCTAssertTrue(workColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected work column task count")
        XCTAssertTrue(emptyColumnTaskCount.waitForExistence(timeout: uiTimeout), "Expected empty column task count")
        XCTAssertTrue(archiveWorkTasksButton.waitForExistence(timeout: uiTimeout), "Expected archive tasks button for work column")

        XCTAssertTrue(waitForCountValue(element: workColumnTaskCount, equals: 1, timeout: 3), "Expected work column initial task count")
        XCTAssertTrue(waitForCountValue(element: emptyColumnTaskCount, equals: 0, timeout: 3), "Expected empty column initial task count")

        archiveWorkTasksButton.tap()

        XCTAssertTrue(waitForCountValue(element: workColumnTaskCount, equals: 0, timeout: 3), "Expected selected column tasks to be archived")
        XCTAssertTrue(waitForCountValue(element: emptyColumnTaskCount, equals: 0, timeout: 3), "Expected other column task count unchanged")
    }

    @MainActor
    func testArchivedTasksToggleShowsColumnArchivedSections() throws {
        // @req TASK-024, UX-030, UX-032
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended

        let archiveWorkTasksButton = app.buttons["column-archive-tasks-column-work"]
        let showArchivedToggle = app.checkBoxes["workspace-toggle-show-archived"]
        let archivedSection = app.staticTexts["column-archived-section-column-work"]
        let archivedTaskTitle = app.staticTexts["archived-task-title-task-1"]

        XCTAssertTrue(archiveWorkTasksButton.waitForExistence(timeout: uiTimeout), "Expected archive tasks button")
        XCTAssertTrue(showArchivedToggle.waitForExistence(timeout: uiTimeout), "Expected show archived toggle")
        XCTAssertTrue(archivedSection.waitForExistence(timeout: uiTimeout), "Expected archived section label")

        archiveWorkTasksButton.tap()

        XCTAssertFalse(archivedTaskTitle.exists, "Archived task rows should stay collapsed by default")

        showArchivedToggle.tap()

        XCTAssertTrue(archivedTaskTitle.waitForExistence(timeout: uiTimeout), "Expected archived task row after enabling show archived tasks")
    }

    @MainActor
    func testArchivedTaskViewRestoreAndDelete() throws {
        // @req TASK-025, TASK-027, TASK-028, TASK-030, UX-033, UX-035
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended

        let archiveWorkTasksButton = app.buttons["column-archive-tasks-column-work"]
        let showArchivedToggle = app.checkBoxes["workspace-toggle-show-archived"]
        let archivedTaskTitle = app.staticTexts["archived-task-title-task-1"]
        let archivedTaskEditButton = app.buttons["task-edit-task-1"]
        let archivedTaskDeleteButton = app.buttons["task-delete-task-1"]
        let archivedTaskMoveUpButton = app.buttons["task-move-up-task-1"]
        let archivedTaskMoveDownButton = app.buttons["task-move-down-task-1"]
        let viewArchivedTaskButton = app.buttons["archived-task-view-task-1"]
        let restoreArchivedTaskButton = app.buttons["archived-task-restore-task-1"]
        let deleteArchivedTaskButton = app.buttons["archived-task-delete-task-1"]
        let workColumnTaskCount = app.staticTexts["column-task-count-column-work"]
        let workColumnTaskList = app.scrollViews["column-task-list-column-work"]

        XCTAssertTrue(archiveWorkTasksButton.waitForExistence(timeout: uiTimeout), "Expected archive tasks button")
        XCTAssertTrue(showArchivedToggle.waitForExistence(timeout: uiTimeout), "Expected show archived toggle")
        archiveWorkTasksButton.tap()
        showArchivedToggle.tap()

        XCTAssertTrue(archivedTaskTitle.waitForExistence(timeout: uiTimeout), "Expected archived task title")
        XCTAssertFalse(archivedTaskEditButton.exists, "Archived rows should not expose active-task edit controls")
        XCTAssertFalse(archivedTaskDeleteButton.exists, "Archived rows should not expose active-task delete controls")
        XCTAssertFalse(archivedTaskMoveUpButton.exists, "Archived rows should not expose active-task move-up controls")
        XCTAssertFalse(archivedTaskMoveDownButton.exists, "Archived rows should not expose active-task move-down controls")
        XCTAssertTrue(viewArchivedTaskButton.exists, "Expected archived view action")
        viewArchivedTaskButton.tap()

        dismissArchivedTaskViewSheet(in: app, timeout: uiTimeout)

        XCTAssertTrue(archivedTaskTitle.exists, "Expected archived task to remain after view action")

        XCTAssertTrue(restoreArchivedTaskButton.exists, "Expected archived restore action")
        XCTAssertTrue(workColumnTaskList.waitForExistence(timeout: uiTimeout), "Expected work column task list")
        XCTAssertTrue(
            scrollUntilHittable(element: restoreArchivedTaskButton, in: workColumnTaskList, maxSwipes: 3),
            "Expected archived restore action to be hittable"
        )
        restoreArchivedTaskButton.tap()
        XCTAssertTrue(waitUntil(timeout: uiTimeout) { !archivedTaskTitle.exists }, "Expected archived task row to disappear after restore")
        XCTAssertTrue(waitForCountValue(element: workColumnTaskCount, equals: 1, timeout: uiTimeout), "Expected active task count to increment after restore")

        archiveWorkTasksButton.tap()
        XCTAssertTrue(archivedTaskTitle.waitForExistence(timeout: uiTimeout), "Expected archived task row after re-archive")
        XCTAssertTrue(deleteArchivedTaskButton.exists, "Expected archived delete action")
        deleteArchivedTaskButton.tap()

        let confirmDeleteArchivedTask = app.buttons["archived-task-delete-confirm-action"]
        XCTAssertTrue(confirmDeleteArchivedTask.waitForExistence(timeout: uiTimeout), "Expected archived delete confirmation")
        confirmDeleteArchivedTask.tap()

        XCTAssertTrue(waitUntil(timeout: uiTimeout) { !archivedTaskTitle.exists }, "Expected archived task row to disappear after delete")
        XCTAssertTrue(waitForCountValue(element: workColumnTaskCount, equals: 0, timeout: 3), "Expected active task count to remain zero after archived delete")
    }

    @MainActor
    func testArchivedTaskSelectionEnablesKeyboardShortcuts() throws {
        // @req TASK-031, TASK-032, UX-036
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended

        let archiveWorkTasksButton = app.buttons["column-archive-tasks-column-work"]
        let showArchivedToggle = app.checkBoxes["workspace-toggle-show-archived"]
        let workColumnTaskCount = app.staticTexts["column-task-count-column-work"]

        XCTAssertTrue(archiveWorkTasksButton.waitForExistence(timeout: uiTimeout), "Expected archive tasks button")
        XCTAssertTrue(showArchivedToggle.waitForExistence(timeout: uiTimeout), "Expected show archived toggle")
        archiveWorkTasksButton.tap()
        showArchivedToggle.tap()

        XCTAssertTrue(
          waitUntil(timeout: uiTimeout) { self.archivedTaskRowExists(in: app, taskID: "task-1") },
            "Expected archived task row"
        )

        selectArchivedTaskForKeyboardShortcuts(taskID: "task-1", app: app)
        app.typeKey("v", modifierFlags: [])

        dismissArchivedTaskViewSheet(in: app, timeout: uiTimeout)

        selectArchivedTaskForKeyboardShortcuts(taskID: "task-1", app: app)
        app.typeKey("x", modifierFlags: [])

        let archivedDeleteConfirmation = app.buttons["archived-task-delete-confirm-action"]
        XCTAssertTrue(archivedDeleteConfirmation.waitForExistence(timeout: uiTimeout), "Expected archived delete confirmation after pressing x")

        let cancelArchivedDeleteButton = app.buttons["archived-task-delete-confirm-cancel"]
        XCTAssertTrue(cancelArchivedDeleteButton.waitForExistence(timeout: uiTimeout), "Expected archived delete cancel action")
        cancelArchivedDeleteButton.tap()

        selectArchivedTaskForKeyboardShortcuts(taskID: "task-1", app: app)
        app.typeKey("r", modifierFlags: [])
        XCTAssertTrue(
          waitUntil(timeout: uiTimeout) { !self.archivedTaskRowExists(in: app, taskID: "task-1") },
            "Expected archived row to disappear after pressing r"
        )
        XCTAssertTrue(waitForCountValue(element: workColumnTaskCount, equals: 1, timeout: uiTimeout), "Expected active task count to increment after pressing r")
    }

    @MainActor
    func testReorderColumnsFromEditBoardModal() throws {
        // @req COL-MOVE-009
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended
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
        // @req UX-007
        let app = launchSignedInApp()
        let uiTimeout = UITimeout.extended
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
    private func launchSignedInApp(
        extraEnvironment: [String: String] = [:],
        resetTaskControlDefaults: Bool = true
    ) -> XCUIApplication {
        let app = configuredAppForUITests(resetTaskControlDefaults: resetTaskControlDefaults)
        app.launchEnvironment[UITestEnvKey.signedIn] = "1"
        app.launchEnvironment[UITestEnvKey.email] = "ui-test@example.com"
        for (key, value) in extraEnvironment {
            app.launchEnvironment[key] = value
        }
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: UITimeout.launch), "Expected app window after launch")
        XCTAssertTrue(
            waitUntil(timeout: UITimeout.extended) {
                let titleReady = app.staticTexts["workspace-board-title"].exists
                let settingsReady = app.buttons["board-settings-button"].exists
                return titleReady && settingsReady
            },
            "Expected workspace controls ready after launch"
        )
        let loadingOverlay = app.otherElements["board-loading-overlay"]
        if loadingOverlay.exists {
            _ = waitUntil(timeout: UITimeout.ready) { !loadingOverlay.exists }
        }
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

    private func scrollUntilMovedAwayFromInitialPosition(
        element: XCUIElement,
        in scrollView: XCUIElement,
        initialMinY: CGFloat,
        maxSwipes: Int
    ) -> Bool {
        for _ in 0..<maxSwipes {
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            let finish = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
            start.press(forDuration: 0.05, thenDragTo: finish)
            scrollView.swipeUp()

            if element.waitForExistence(timeout: 0.2), element.frame.minY < initialMinY - 8 {
                return true
            }
            if !element.isHittable {
                return true
            }
        }

        return element.exists && (element.frame.minY < initialMinY - 8 || !element.isHittable)
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

    private func firstHittableElement(in query: XCUIElementQuery, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let candidate = query.allElementsBoundByIndex.first { $0.exists && $0.isHittable }
            if let candidate {
                return candidate
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return query.allElementsBoundByIndex.first { $0.exists }
    }

    private func preferredElement(primary: XCUIElement, fallback: XCUIElement, waitTimeout: TimeInterval) -> XCUIElement {
        primary.waitForExistence(timeout: waitTimeout) ? primary : fallback
    }

    private func openSettingsSheet(in app: XCUIApplication, trigger settingsButton: XCUIElement, attempts: Int = 3) -> Bool {
        let settingsSheet = app.otherElements["board-settings-sheet"]
        let settingsCloseButton = app.buttons["board-settings-close-button"]
        let shortcutsTitle = app.staticTexts["board-settings-shortcuts-title"]

        for _ in 0..<attempts {
            settingsButton.tap()
            if settingsCloseButton.waitForExistence(timeout: 1)
                || settingsSheet.waitForExistence(timeout: 1)
                || shortcutsTitle.waitForExistence(timeout: 1) {
                return true
            }
        }

        return false
    }

    private func dismissArchivedTaskViewSheet(in app: XCUIApplication, timeout: TimeInterval) {
        let archivedViewSheet = app.descendants(matching: .any).matching(identifier: "archived-task-view-sheet").firstMatch
        XCTAssertTrue(waitUntil(timeout: timeout) { archivedViewSheet.exists }, "Expected archived task view sheet")

        // Dismiss via Escape first because XCTest can expose sheet buttons
        // inconsistently across accessibility hierarchies.
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        if !waitUntil(timeout: 1.2) { !archivedViewSheet.exists } {
            let closeByID = app.descendants(matching: .any).matching(identifier: "archived-task-view-close").firstMatch
            let closeInSheetByLabel = archivedViewSheet.descendants(matching: .button).matching(NSPredicate(format: "label == %@", "Close")).firstMatch
            let closeButton = preferredElement(primary: closeByID, fallback: closeInSheetByLabel, waitTimeout: 1.2)
            if closeButton.exists {
                closeButton.tap()
            }
        }
        if !waitUntil(timeout: 1.2) { !archivedViewSheet.exists } {
            let closeByID = app.descendants(matching: .any).matching(identifier: "archived-task-view-close").firstMatch
            if closeByID.exists {
                closeByID.click()
            }
        }
        XCTAssertTrue(waitUntil(timeout: timeout) { !archivedViewSheet.exists }, "Expected archived task view sheet to dismiss")
    }

    private func setCheckbox(_ checkbox: XCUIElement, to isOn: Bool) {
        XCTAssertTrue(checkbox.waitForExistence(timeout: UITimeout.standard), "Expected checkbox to exist")

        for _ in 0..<3 {
            guard let current = checkboxValue(checkbox) else {
                checkbox.click()
                continue
            }
            if current == isOn {
                return
            }
            checkbox.click()
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        XCTAssertEqual(checkboxValue(checkbox), isOn, "Expected checkbox to match target state")
    }

    private func checkboxValue(_ checkbox: XCUIElement) -> Bool? {
        if let value = checkbox.value as? String {
            if value == "1" { return true }
            if value == "0" { return false }
        }
        if let value = checkbox.value as? NSNumber {
            return value.intValue != 0
        }
        return nil
    }

    private func sendKeyboardInputWithFallback(
        _ key: String,
        to window: XCUIElement,
        attempts: Int = 3,
        reachedCondition: (() -> Bool)? = nil
    ) {
        let condition = reachedCondition ?? { false }
        for _ in 0..<attempts {
            window.typeKey(key, modifierFlags: [])
            if condition() {
                return
            }
            window.typeText(key)
            if condition() {
                return
            }
        }
    }

    private func dismissBlockingSheetsIfPresent(app: XCUIApplication) {
        let blockingSheets = [
            app.otherElements["task-editor-sheet"],
            app.otherElements["board-settings-sheet"],
            app.otherElements["column-shortcut-picker-sheet"],
            app.sheets.firstMatch,
        ]

        for _ in 0..<3 {
            if blockingSheets.contains(where: { $0.exists }) {
                app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
                _ = waitUntil(timeout: 0.8) {
                    !blockingSheets.contains(where: { $0.exists })
                }
            }
        }
    }

    private func selectTaskForKeyboardShortcuts(taskID: String, card: XCUIElement, app: XCUIApplication) {
        guard card.waitForExistence(timeout: UITimeout.standard) else { return }
        let taskTitle = app.staticTexts["task-title-\(taskID)"]

        for _ in 0..<3 {
            card.click()
            RunLoop.current.run(until: Date().addingTimeInterval(0.08))
            if (card.value as? String) == "selected" {
                return
            }
            if taskTitle.exists {
                taskTitle.click()
                RunLoop.current.run(until: Date().addingTimeInterval(0.08))
                if (card.value as? String) == "selected" {
                    return
                }
            }
        }

        app.windows.firstMatch.click()
        card.click()

        if (card.value as? String) == "selected" {
            return
        }

        _ = waitUntil(timeout: 0.6) {
            ((card.value as? String) == "selected")
                || app.descendants(matching: .any).matching(
                    NSPredicate(format: "identifier == %@ AND value == %@", "task-card-\(taskID)", "selected")
                ).firstMatch.exists
        }
    }

    private func selectArchivedTaskForKeyboardShortcuts(taskID: String, app: XCUIApplication) {
        let row = archivedTaskRowElement(in: app, taskID: taskID, waitTimeout: UITimeout.standard)
        guard row.waitForExistence(timeout: UITimeout.standard) else { return }
        let rowTitle = app.staticTexts["archived-task-title-\(taskID)"]

        for _ in 0..<3 {
            row.click()
            RunLoop.current.run(until: Date().addingTimeInterval(0.08))
            if isArchivedTaskSelected(taskID: taskID, row: row, app: app) {
                return
            }
            if rowTitle.exists {
                rowTitle.click()
                RunLoop.current.run(until: Date().addingTimeInterval(0.08))
                if isArchivedTaskSelected(taskID: taskID, row: row, app: app) {
                    return
                }
            }
        }

        app.windows.firstMatch.click()
        row.click()

        if isArchivedTaskSelected(taskID: taskID, row: row, app: app) {
            return
        }

      _ = waitUntil(timeout: 0.6) { self.isArchivedTaskSelected(taskID: taskID, row: row, app: app) }
    }

    private func isArchivedTaskSelected(taskID: String, row: XCUIElement, app: XCUIApplication) -> Bool {
        if (row.value as? String) == "selected" {
            return true
        }
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ AND value == %@", "archived-task-row-\(taskID)", "selected")
        ).firstMatch.exists
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
        let exactCard = app.otherElements["task-card-\(taskID)"]
        if exactCard.waitForExistence(timeout: waitTimeout) {
            return exactCard
        }

        let exactDescendant = app.descendants(matching: .any).matching(identifier: "task-card-\(taskID)").firstMatch
        if exactDescendant.waitForExistence(timeout: 0.5) {
            return exactDescendant
        }

        return exactCard
    }

    private func archivedTaskRowElement(in app: XCUIApplication, taskID: String, waitTimeout: TimeInterval) -> XCUIElement {
        let exactRow = app.otherElements["archived-task-row-\(taskID)"]
        if exactRow.waitForExistence(timeout: waitTimeout) {
            return exactRow
        }

        let exactDescendant = app.descendants(matching: .any).matching(identifier: "archived-task-row-\(taskID)").firstMatch
        if exactDescendant.waitForExistence(timeout: waitTimeout) {
            return exactDescendant
        }

        let rowTitle = app.staticTexts["archived-task-title-\(taskID)"]
        if rowTitle.waitForExistence(timeout: waitTimeout) {
            return rowTitle
        }

        return exactRow
    }

    private func archivedTaskRowExists(in app: XCUIApplication, taskID: String) -> Bool {
        let exactRow = app.descendants(matching: .any).matching(identifier: "archived-task-row-\(taskID)").firstMatch
        if exactRow.exists {
            return true
        }
        let exactTitle = app.staticTexts["archived-task-title-\(taskID)"]
        return exactTitle.exists
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
