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
        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "3 of 5 dinners planned")
        let budgetLabel = app.staticTexts["budget-spent"].label
        XCTAssertTrue(budgetLabel.contains("$35.40") && budgetLabel.contains("$80.00"))
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("3 of 25"))
        capture("01-initial-plan")

        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].waitForExistence(timeout: 5))
        capture("02-discover-carbonara")
        app.buttons["add-recipe-carbonara"].tap()

        XCTAssertTrue(element("add-to-week-sheet").waitForExistence(timeout: 3))
        tapDay("Thursday")
        XCTAssertEqual(app.staticTexts["assignment-preview-spend"].label, "$44.30 of $80.00")
        XCTAssertEqual(app.staticTexts["assignment-preview-remaining"].label, "$35.70 remaining")
        capture("03-add-carbonara-thursday")
        app.buttons["add-confirm"].tap()

        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["meal-Thursday"].label.contains("Proper Carbonara"))
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "4 of 5 dinners planned")
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("3 of 31"))

        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.staticTexts["discover-title-curry"].waitForExistence(timeout: 5))
        app.buttons["add-recipe-curry"].tap()
        tapDay("Friday")
        XCTAssertEqual(app.staticTexts["assignment-preview-spend"].label, "$56.70 of $80.00")
        XCTAssertEqual(app.staticTexts["assignment-preview-remaining"].label, "$23.30 remaining")
        app.buttons["add-confirm"].tap()

        XCTAssertTrue(app.staticTexts["plan-headline"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["plan-headline"].label, "Your week is ready to shop")
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "5 of 5 dinners planned")
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("3 of 36"))

        app.buttons["open-shopping-list"].tap()
        XCTAssertTrue(element("shopping-list-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("shopping-list-progress").label.contains("3 of 36"))
        app.buttons["shopping-item-broccoli"].tap()
        XCTAssertTrue(element("shopping-list-progress").label.contains("4 of 36"))
        XCTAssertEqual(element("aisle-progress-Produce").label, "2/11")
        capture("04-updated-shopping-list")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("4 of 36"))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func tapDay(_ name: String) {
        let button = app.buttons["day-\(name)"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))

        var attempts = 0
        let footerSafeBottom = app.frame.maxY - max(180, app.frame.height * 0.25)
        while (button.frame.maxY > footerSafeBottom || !button.isHittable) && attempts < 5 {
            element("add-to-week-sheet").swipeUp()
            attempts += 1
        }

        XCTAssertLessThanOrEqual(button.frame.maxY, footerSafeBottom, "\(name) should scroll above the pinned projection footer")
        XCTAssertTrue(button.isHittable, "\(name) should be reachable by scrolling the assignment sheet")
        button.tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
