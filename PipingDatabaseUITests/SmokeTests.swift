import XCTest

/// Layer 4 of docs/TESTING.md: thin smoke coverage of the real UI.
final class SmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testModuleListShowsAllModules() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Pipe Schedule"].waitForExistence(timeout: 5))
        for title in ["Fittings", "Flanges", "Valves", "Branch Connections", "Line Blanks", "Gaskets"] {
            XCTAssertTrue(app.staticTexts[title].exists, title)
        }
    }

    func testPipeScheduleShowsDataAndTogglesUnits() {
        let app = XCUIApplication()
        app.launchEnvironment["OPEN_MODULE"] = "pipe"
        app.launch()
        XCTAssertTrue(app.navigationBars["Pipe Schedule"].waitForExistence(timeout: 5))
        // Default selection is 1/2" Sch 40 — golden: OD 0.840 in, wall 0.109 in.
        XCTAssertTrue(app.staticTexts["0.840 in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0.109 in"].exists)

        let unitButton = app.buttons["in"]
        XCTAssertTrue(unitButton.exists)
        unitButton.tap()
        // 0.840 in = 21.34 mm
        XCTAssertTrue(app.staticTexts["21.34 mm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mm"].exists)
        app.buttons["mm"].tap() // restore
    }
}
