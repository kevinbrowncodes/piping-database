import XCTest

/// Layer 4 of docs/TESTING.md: thin smoke coverage of the real UI.
/// Every test launches with UITEST_RESET=1 so persisted preferences,
/// module order, and favorites/recents never leak between runs.
final class SmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchApp(module: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        if let module { app.launchEnvironment["OPEN_MODULE"] = module }
        app.launch()
        return app
    }

    func testModuleListShowsAllModules() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Pipe Schedule"].waitForExistence(timeout: 5))
        for title in ["Fittings", "Flanges", "Valves", "Branch Connections", "Line Blanks", "Gaskets"] {
            XCTAssertTrue(app.staticTexts[title].exists, title)
        }
    }

    func testPipeScheduleShowsDataAndTogglesUnits() {
        let app = launchApp(module: "pipe")
        XCTAssertTrue(app.navigationBars["Pipe Schedule"].waitForExistence(timeout: 5))
        // Default selection is 1/2" Sch 40 — golden: OD 0.840 in, wall 0.109 in.
        XCTAssertTrue(app.staticTexts["0.840 in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0.109 in"].exists)

        let unitButton = app.buttons["in"]
        XCTAssertTrue(unitButton.waitForExistence(timeout: 5))
        unitButton.tap()
        // 0.840 in = 21.34 mm
        XCTAssertTrue(app.staticTexts["21.34 mm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mm"].exists)
    }
}
