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

final class Milestone2JourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-fixture", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    func testRecipeDetailsDraftCancelThenAddWithSelectedServings() {
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].waitForExistence(timeout: 5))
        app.buttons["discover-details-carbonara"].tap()
        XCTAssertTrue(app.buttons["details-save-carbonara"].waitForExistence(timeout: 5))
        capture("05-recipe-details")

        app.buttons["servings-increase"].tap()
        XCTAssertTrue(element("servings-cost-preview").label.contains("$17.80"))
        XCTAssertTrue(element("ingredient-quantity-spaghetti").label.contains("250g"))
        capture("06-recipe-details-adjusted-servings")

        app.buttons["recipe-details-back"].tap()
        XCTAssertTrue(element("discover-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].exists)

        app.buttons["discover-details-carbonara"].tap()
        XCTAssertTrue(app.buttons["details-save-carbonara"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("servings-cost-preview").label.contains("$8.90"), "Back must discard the uncommitted serving draft")
        app.buttons["servings-increase"].tap()
        app.buttons["details-add-to-week"].tap()
        XCTAssertTrue(element("add-to-week-sheet").waitForExistence(timeout: 4))
        tapDay("Thursday")
        XCTAssertEqual(app.staticTexts["assignment-preview-spend"].label, "$53.20 of $80.00")
        app.buttons["add-confirm"].tap()

        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("open-meal-Thursday").label.contains("Proper Carbonara"))
        XCTAssertTrue(app.staticTexts["budget-spent"].label.contains("$53.20"))
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("3 of 31"))
    }

    func testSavedNotePlanAndShoppingPersistAcrossRelaunch() {
        addTwoServingCarbonaraToThursday()
        app.buttons["open-shopping-list"].tap()
        XCTAssertTrue(element("shopping-list-screen").waitForExistence(timeout: 5))
        app.buttons["shopping-item-broccoli"].tap()
        XCTAssertEqual(app.buttons["shopping-item-broccoli"].value as? String, "Bought")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))
        element("open-meal-Thursday").tap()
        XCTAssertTrue(app.buttons["details-save-carbonara"].waitForExistence(timeout: 5))
        app.buttons["details-save-carbonara"].tap()
        enterNote("Use the widest pan.")

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "4 of 5 dinners planned")
        XCTAssertTrue(app.staticTexts["budget-spent"].label.contains("$53.20"))
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("4 of 31"))

        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(element("saved-recipe-carbonara").waitForExistence(timeout: 5))
        capture("07-saved-with-recipes")
        element("saved-recipe-carbonara").tap()
        XCTAssertTrue(app.buttons["details-save-carbonara"].waitForExistence(timeout: 5))
        scrollAboveActionBar(element("recipe-note-editor"))
        XCTAssertTrue(String(describing: element("recipe-note-editor").value).contains("Use the widest pan."))
    }

    func testBackReturnsToEachOrigin() {
        element("open-meal-Monday").tap()
        XCTAssertTrue(app.buttons["details-save-honeysoy"].waitForExistence(timeout: 5))
        app.buttons["recipe-details-back"].tap()
        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))

        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.buttons["discover-details-carbonara"].waitForExistence(timeout: 5))
        app.buttons["discover-details-carbonara"].tap()
        XCTAssertTrue(app.buttons["details-save-carbonara"].waitForExistence(timeout: 5))
        app.buttons["recipe-details-back"].tap()
        XCTAssertTrue(element("discover-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].exists)

        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(element("saved-recipe-curry").waitForExistence(timeout: 5))
        element("saved-recipe-curry").tap()
        XCTAssertTrue(app.buttons["details-save-curry"].waitForExistence(timeout: 5))
        app.buttons["recipe-details-back"].tap()
        XCTAssertTrue(element("saved-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("saved-recipe-curry").exists)
    }

    func testSaveAndUnsaveAgreeAcrossDiscoverDetailsAndSaved() {
        app.tabBars.buttons["Discover"].tap()
        let discoverSave = app.buttons["discover-save-carbonara"]
        XCTAssertTrue(discoverSave.waitForExistence(timeout: 5))
        XCTAssertEqual(discoverSave.value as? String, "Not saved")
        discoverSave.tap()
        XCTAssertEqual(discoverSave.value as? String, "Saved")

        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(element("saved-recipe-carbonara").waitForExistence(timeout: 5))
        element("saved-recipe-carbonara").tap()
        let detailsSave = app.buttons["details-save-carbonara"]
        XCTAssertTrue(detailsSave.waitForExistence(timeout: 5))
        XCTAssertEqual(detailsSave.value as? String, "Saved")
        detailsSave.tap()
        XCTAssertEqual(detailsSave.value as? String, "Not saved")
        app.buttons["recipe-details-back"].tap()
        XCTAssertFalse(element("saved-recipe-carbonara").exists)

        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(discoverSave.waitForExistence(timeout: 5))
        XCTAssertEqual(discoverSave.value as? String, "Not saved")
    }

    func testSwapReusesPlanMutationAndDerivedTotals() {
        element("open-meal-Monday").tap()
        XCTAssertTrue(app.buttons["swap-meal"].waitForExistence(timeout: 5))
        app.buttons["swap-meal"].tap()
        XCTAssertTrue(element("swap-meal-sheet").waitForExistence(timeout: 4))
        app.buttons["swap-candidate-carbonara"].tap()
        app.buttons["swap-confirm"].tap()

        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("open-meal-Monday").label.contains("Proper Carbonara"))
        XCTAssertTrue(app.staticTexts["budget-spent"].label.contains("$32.70"))
    }

    func testSavedNoResultsScreenshot() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--reset-fixture", "--saved-no-results", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(element("saved-no-results-state").waitForExistence(timeout: 5))
        capture("08-saved-no-results")
    }

    func testLargeDynamicTypeRecipeDetailsScreenshot() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "--reset-fixture",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityL",
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US",
        ]
        app.launch()
        let monday = element("open-meal-Monday")
        scrollTo(monday)
        monday.tap()
        XCTAssertTrue(app.buttons["details-save-honeysoy"].waitForExistence(timeout: 5))
        capture("09-recipe-details-large-type")
    }

    private func addTwoServingCarbonaraToThursday() {
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.buttons["discover-details-carbonara"].waitForExistence(timeout: 5))
        app.buttons["discover-details-carbonara"].tap()
        XCTAssertTrue(app.buttons["details-save-carbonara"].waitForExistence(timeout: 5))
        app.buttons["servings-increase"].tap()
        app.buttons["details-add-to-week"].tap()
        XCTAssertTrue(element("add-to-week-sheet").waitForExistence(timeout: 4))
        tapDay("Thursday")
        app.buttons["add-confirm"].tap()
        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))
    }

    private func enterNote(_ note: String) {
        let editor = element("recipe-note-editor")
        scrollAboveActionBar(editor)
        editor.tap()
        editor.typeText(note)
        let save = app.buttons["save-recipe-note"]
        scrollAboveActionBar(save)
        save.tap()
    }

    private func scrollAboveActionBar(_ target: XCUIElement) {
        var attempts = 0
        let safeBottom = app.frame.maxY - 220
        while (!target.exists || target.frame.maxY > safeBottom || !target.isHittable) && attempts < 12 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(target.exists)
        XCTAssertLessThanOrEqual(target.frame.maxY, safeBottom)
        XCTAssertTrue(target.isHittable)
    }

    private func scrollTo(_ target: XCUIElement) {
        var attempts = 0
        while (!target.exists || !target.isHittable) && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(target.exists)
        XCTAssertTrue(target.isHittable)
    }

    private func tapDay(_ name: String) {
        let button = app.buttons["day-\(name)"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        var attempts = 0
        while !button.isHittable && attempts < 6 {
            element("add-to-week-sheet").swipeUp()
            attempts += 1
        }
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
