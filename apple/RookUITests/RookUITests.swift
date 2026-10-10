import XCTest

final class RookUITests: XCTestCase {
    @MainActor
    func testExampleWorkoutPersistsAndFinishesIntoHistory() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ROOK_TEST_ID"] = UUID().uuidString
        app.launch()
        let example = app.buttons["add-example"]
        XCTAssertTrue(example.waitForExistence(timeout: 20))
        example.tap()
        let start = app.buttons["start-workout"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let complete = app.buttons["complete-0-0"]
        XCTAssertTrue(complete.waitForExistence(timeout: 10))
        complete.tap()
        XCTAssertTrue(app.staticTexts["rest-clock"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        let resume = app.buttons["resume-workout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 20))
        resume.tap()
        XCTAssertTrue(app.buttons["complete-0-0"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["complete-0-0"].value as? String, "Completed")
        app.buttons["finish-workout"].tap()
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 10))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Upper body"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "1 sets")).firstMatch.exists)
    }

    @MainActor
    func testEmptyFirstRunHasNoFabricatedHistory() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ROOK_TEST_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["add-example"].waitForExistence(timeout: 20))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Your story starts with a session"].exists)
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Progress needs a starting point"].exists)
    }

    @MainActor
    func testInvalidRoutineShowsAnActionableErrorAboveTheEditor() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ROOK_TEST_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["create-first-routine"].waitForExistence(timeout: 20))
        app.buttons["create-first-routine"].tap()
        XCTAssertTrue(app.buttons["save-routine"].waitForExistence(timeout: 10))
        app.buttons["save-routine"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor
    func testEditedSetValuesAutosaveBeforeCompletion() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ROOK_TEST_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["add-example"].waitForExistence(timeout: 20))
        app.buttons["add-example"].tap()
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
        app.buttons["start-workout"].tap()
        let weight = app.textFields["weight-0-0"]
        XCTAssertTrue(weight.waitForExistence(timeout: 10))
        // Tap beyond the centered value so deletion starts after its last digit.
        weight.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "62.5")
        XCTAssertEqual(weight.value as? String, "62.5")
        app.toolbars.buttons["Done"].tap()
        sleep(1)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["resume-workout"].waitForExistence(timeout: 20))
        app.buttons["resume-workout"].tap()
        XCTAssertTrue(app.textFields["weight-0-0"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["weight-0-0"].value as? String, "62.5")
    }

    @MainActor
    func testCaptureRouteMarkersLightDarkAndLargeText() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ROOK_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["ROOK_TEST_APPEARANCE"] = "light"
        app.launch()
        XCTAssertTrue(app.buttons["add-example"].waitForExistence(timeout: 20))
        capture(app, name: "phone-empty")
        app.buttons["add-example"].tap()
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
        app.buttons["start-workout"].tap()
        XCTAssertTrue(app.buttons["complete-0-0"].waitForExistence(timeout: 10))
        app.buttons["complete-0-0"].tap()
        XCTAssertTrue(app.staticTexts["rest-clock"].waitForExistence(timeout: 10))
        capture(app, name: "phone-light")
        app.terminate()
        app.launchEnvironment["ROOK_TEST_APPEARANCE"] = "dark"
        app.launch()
        XCTAssertTrue(app.buttons["resume-workout"].waitForExistence(timeout: 20))
        app.buttons["resume-workout"].tap()
        XCTAssertTrue(app.staticTexts["rest-clock"].waitForExistence(timeout: 10))
        capture(app, name: "phone-dark")
        app.terminate()
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["resume-workout"].waitForExistence(timeout: 20))
        app.buttons["resume-workout"].tap()
        XCTAssertTrue(app.staticTexts["rest-clock"].waitForExistence(timeout: 10))
        capture(app, name: "phone-large")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
