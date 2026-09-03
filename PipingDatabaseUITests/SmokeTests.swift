import XCTest

/// Layer 4 of docs/TESTING.md: thin smoke coverage of the real UI.
/// Every test launches with UITEST_RESET=1 so persisted preferences,
/// module order, and favorites/recents never leak between runs.
final class SmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchApp(module: String? = nil, tab: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        if let module { app.launchEnvironment["OPEN_MODULE"] = module }
        if let tab { app.launchEnvironment["OPEN_TAB"] = tab }
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

    /// BUG-0002 on the real keypad: the sign key negates the whole entry.
    func testCalculatorSignNegatesWholeEntry() {
        let app = launchApp(tab: "calculator")
        XCTAssertTrue(app.buttons["feet"].waitForExistence(timeout: 5))
        for key in ["AC", "5", "feet", "3", "Change sign"] { app.buttons[key].tap() }
        let display = app.descendants(matching: .any)["Calculator display: -5'-3\""]
        XCTAssertTrue(display.waitForExistence(timeout: 5))
    }

    /// BUG-0006 in the real search field: numbers match whole sizes only.
    func testSearchMatchesWholeNumbers() {
        let app = launchApp()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("sch 80 6")
        XCTAssertTrue(app.staticTexts["6\" Sch 80 Pipe"].waitForExistence(timeout: 5))
        // The 6" row leads; the 1/8" row (DN 6) may follow but 16" never appears.
        let firstRow = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstRow.staticTexts["6\" Sch 80 Pipe"].exists)
        XCTAssertFalse(app.staticTexts["16\" Sch 80 Pipe"].exists)
    }

    /// BUG-0003 on device-like navigation: a Lap Joint pick survives a jump
    /// to a B16.47 row by following the wheel to Weld Neck.
    func testFlangeTypeFollowsTheRow() {
        let app = launchApp(module: "flanges|cl=150&t=LJ&k=2")
        XCTAssertTrue(app.navigationBars["Flanges"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Weight (LJ)"].waitForExistence(timeout: 5))
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "30 A\"")
        XCTAssertTrue(app.staticTexts["Weight (WN)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["B16.47 Series A"].exists)
    }
}
