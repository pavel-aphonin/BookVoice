//
//  BookVoiceUITests.swift
//  BookVoiceUITests
//
//  Created by Павел Афонин on 22.02.2026.
//

import XCTest

final class BookVoiceUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testLaunch_displaysStartScreen() throws {
        let screen = StartScreenPage(app: app)

        XCTAssertTrue(screen.title.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.subtitle.exists)
        XCTAssertTrue(screen.newVoiceoverButton.exists)
    }

    @MainActor
    func testCreateProject_opensWizardContainer() throws {
        let start = StartScreenPage(app: app)
        XCTAssertTrue(start.newVoiceoverButton.waitForExistence(timeout: 5))
        start.newVoiceoverButton.click()

        let wizard = WizardPage(app: app)
        XCTAssertTrue(wizard.closeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(wizard.nextButton.exists)
        XCTAssertTrue(wizard.modelStep.exists)
    }

    @MainActor
    func testCloseWizardOnStepOne_returnsToStartScreen() throws {
        let start = StartScreenPage(app: app)
        XCTAssertTrue(start.newVoiceoverButton.waitForExistence(timeout: 5))
        start.newVoiceoverButton.click()

        let wizard = WizardPage(app: app)
        XCTAssertTrue(wizard.closeButton.waitForExistence(timeout: 5))
        wizard.closeButton.click()

        XCTAssertTrue(start.newVoiceoverButton.waitForExistence(timeout: 5))
    }
}

private struct StartScreenPage {
    let app: XCUIApplication

    var title: XCUIElement { app.staticTexts["BookVoice"] }
    var subtitle: XCUIElement { app.staticTexts["Превратите книги в аудиокниги"] }
    var newVoiceoverButton: XCUIElement { app.buttons["Новая озвучка"] }
}

private struct WizardPage {
    let app: XCUIApplication

    var closeButton: XCUIElement { app.buttons["Закрыть"] }
    var nextButton: XCUIElement { app.buttons["Далее"] }
    var modelStep: XCUIElement { app.staticTexts["Модель"] }
}
