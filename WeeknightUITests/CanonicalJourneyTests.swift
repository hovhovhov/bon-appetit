import XCTest

final class CanonicalJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-fixture", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    func testCanonicalCoreLoop() throws {
        XCTAssertTrue(app.otherElements["plan-screen"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "3 of 5 dinners planned")
        XCTAssertEqual(app.otherElements["budget-spent"].label, "$35.40, of $80.00")
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("3 of 25"))

        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].waitForExistence(timeout: 5))
        app.buttons["add-recipe-carbonara"].tap()

        XCTAssertTrue(app.otherElements["add-to-week-sheet"].waitForExistence(timeout: 3))
        app.buttons["day-Thursday"].tap()
        XCTAssertEqual(app.staticTexts["assignment-preview-spend"].label, "$44.30 of $80.00")
        XCTAssertEqual(app.staticTexts["assignment-preview-remaining"].label, "$35.70 remaining")
        app.buttons["add-confirm"].tap()

        XCTAssertTrue(app.otherElements["plan-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["meal-Thursday"].label.contains("Proper Carbonara"))
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "4 of 5 dinners planned")
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("3 of 31"))

        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.staticTexts["discover-title-curry"].waitForExistence(timeout: 5))
        app.buttons["add-recipe-curry"].tap()
        app.buttons["day-Friday"].tap()
        XCTAssertEqual(app.staticTexts["assignment-preview-spend"].label, "$56.70 of $80.00")
        XCTAssertEqual(app.staticTexts["assignment-preview-remaining"].label, "$23.30 remaining")
        app.buttons["add-confirm"].tap()

        XCTAssertTrue(app.staticTexts["plan-headline"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["plan-headline"].label, "Your week is ready to shop")
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "5 of 5 dinners planned")
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("3 of 36"))

        app.buttons["open-shopping-list"].tap()
        XCTAssertTrue(app.otherElements["shopping-list-screen"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["shopping-list-progress"].label, "3 of 36 items")
        app.buttons["shopping-item-broccoli"].tap()
        XCTAssertEqual(app.staticTexts["shopping-list-progress"].label, "4 of 36 items")
        XCTAssertEqual(app.staticTexts["aisle-progress-Produce"].label, "2/11")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.otherElements["plan-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("4 of 36"))
    }
}

