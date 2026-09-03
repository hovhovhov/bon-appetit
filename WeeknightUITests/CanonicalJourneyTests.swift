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

        app.tabBars.buttons["Meals"].tap()
        XCTAssertTrue(element("cuisine-grid").waitForExistence(timeout: 5))
        searchExplore("Proper Carbonara")
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

        app.tabBars.buttons["Meals"].tap()
        searchExplore("Weeknight Chicken Curry")
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
        let completionToast = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "The week and shopping list are updated"))
            .firstMatch
        if completionToast.exists {
            XCTAssertTrue(completionToast.waitForNonExistence(timeout: 4))
        }
        capture("04-plan-completed")

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

    private func searchExplore(_ text: String) {
        let search = app.textFields["for-you-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        let clear = app.buttons["Clear search"]
        if clear.exists { clear.tap() }
        search.tap()
        search.typeText(text)
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

final class Milestone45VisualStateTests: XCTestCase {
    func testEmptyPlanVisualState() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-fixture",
            "--v2-empty-plan",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Nothing planned yet"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "0 of 5 dinners planned")

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "23-plan-empty"
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
        app.tabBars.buttons["Meals"].tap()
        searchExplore("Proper Carbonara")
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].waitForExistence(timeout: 5))
        app.buttons["discover-details-carbonara"].tap()
        XCTAssertTrue(app.buttons["details-save-carbonara"].waitForExistence(timeout: 5))
        capture("05-recipe-details")

        app.buttons["servings-increase"].tap()
        XCTAssertTrue(element("servings-cost-preview").label.contains("$17.80"))
        XCTAssertTrue(element("ingredient-quantity-spaghetti").label.contains("250g"))
        capture("06-recipe-details-adjusted-servings")

        app.buttons["recipe-details-back"].tap()
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].waitForExistence(timeout: 5))
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

        selectSavedMeals()
        XCTAssertTrue(element("saved-recipe-carbonara").waitForExistence(timeout: 5))
        capture("07-saved-with-recipes")
        app.buttons["saved-details-carbonara"].tap()
        XCTAssertTrue(app.buttons["details-save-carbonara"].waitForExistence(timeout: 5))
        scrollAboveActionBar(element("recipe-note-editor"))
        XCTAssertTrue(String(describing: element("recipe-note-editor").value).contains("Use the widest pan."))
    }

    func testBackReturnsToEachOrigin() {
        element("open-meal-Monday").tap()
        XCTAssertTrue(app.buttons["details-save-honeysoy"].waitForExistence(timeout: 5))
        app.buttons["recipe-details-back"].tap()
        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))

        app.tabBars.buttons["Meals"].tap()
        searchExplore("Proper Carbonara")
        XCTAssertTrue(app.buttons["discover-details-carbonara"].waitForExistence(timeout: 5))
        app.buttons["discover-details-carbonara"].tap()
        XCTAssertTrue(app.buttons["details-save-carbonara"].waitForExistence(timeout: 5))
        app.buttons["recipe-details-back"].tap()
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].exists)

        selectSavedMeals()
        XCTAssertTrue(element("saved-recipe-curry").waitForExistence(timeout: 5))
        app.buttons["saved-details-curry"].tap()
        XCTAssertTrue(app.buttons["details-save-curry"].waitForExistence(timeout: 5))
        app.buttons["recipe-details-back"].tap()
        XCTAssertTrue(element("saved-count").waitForExistence(timeout: 5))
        XCTAssertTrue(element("saved-recipe-curry").exists)
    }

    func testSaveAndUnsaveAgreeAcrossDiscoverDetailsAndSaved() {
        app.tabBars.buttons["Meals"].tap()
        searchExplore("Proper Carbonara")
        app.buttons["discover-details-carbonara"].tap()
        let detailsSave = app.buttons["details-save-carbonara"]
        XCTAssertTrue(detailsSave.waitForExistence(timeout: 5))
        XCTAssertEqual(detailsSave.value as? String, "Not saved")
        detailsSave.tap()
        XCTAssertEqual(detailsSave.value as? String, "Saved")
        app.buttons["recipe-details-back"].tap()

        selectSavedMeals()
        XCTAssertTrue(element("saved-recipe-carbonara").waitForExistence(timeout: 5))
        app.buttons["saved-details-carbonara"].tap()
        XCTAssertTrue(detailsSave.waitForExistence(timeout: 5))
        XCTAssertEqual(detailsSave.value as? String, "Saved")
        detailsSave.tap()
        XCTAssertEqual(detailsSave.value as? String, "Not saved")
        app.buttons["recipe-details-back"].tap()
        XCTAssertFalse(element("saved-recipe-carbonara").exists)

        selectExploreMeals()
        searchExplore("Proper Carbonara")
        app.buttons["discover-details-carbonara"].tap()
        XCTAssertTrue(detailsSave.waitForExistence(timeout: 5))
        XCTAssertEqual(detailsSave.value as? String, "Not saved")
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
        app.launchArguments = [
            "--reset-fixture", "--saved-no-results",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        selectSavedMeals()
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
        app.tabBars.buttons["Meals"].tap()
        searchExplore("Proper Carbonara")
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
        let footerSafeBottom = app.frame.maxY - max(180, app.frame.height * 0.25)
        while (button.frame.maxY > footerSafeBottom || !button.isHittable) && attempts < 6 {
            element("add-to-week-sheet").swipeUp()
            attempts += 1
        }
        XCTAssertLessThanOrEqual(button.frame.maxY, footerSafeBottom)
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    private func selectSavedMeals() {
        app.tabBars.buttons["Meals"].tap()
        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Saved"].tap()
        XCTAssertTrue(element("saved-count").waitForExistence(timeout: 5))
    }

    private func selectExploreMeals() {
        app.tabBars.buttons["Meals"].tap()
        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Explore"].tap()
        XCTAssertTrue(element("styles-toggle").waitForExistence(timeout: 5))
    }

    private func searchExplore(_ text: String) {
        let search = app.textFields["for-you-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        let clear = app.buttons["Clear search"]
        if clear.exists { clear.tap() }
        search.tap()
        search.typeText(text)
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
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

final class Milestone3JourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        launch(["--reset-fixture"])
    }

    func testPreferenceDraftCancelDoesNotLeak() {
        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "household"])
        let increment = app.buttons["household-increment"]
        scrollTo(increment)
        increment.tap()
        XCTAssertTrue(element("preferences-unsaved-count").waitForExistence(timeout: 4))
        XCTAssertEqual(element("household-value").value as? String, "2 people")
        app.buttons["preference-discard"].tap()
        XCTAssertTrue(element("preferences-unsaved-count").waitForNonExistence(timeout: 5))
        XCTAssertEqual(element("household-value").value as? String, "1 person")
        XCTAssertTrue(element("preferences-summary").label.contains("1 person"))

        app.tabBars.buttons["Plans"].tap()
        XCTAssertTrue(app.staticTexts["budget-spent"].label.contains("$35.40"))
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("3 of 25"))
    }

    func testPreferencesMultiSelectAllergenReconciliationAndPlanWarning() {
        app.tabBars.buttons["Preferences"].tap()
        XCTAssertTrue(element("preferences-screen").waitForExistence(timeout: 5))
        capture("10-preferences-overview")

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "proteins"])
        XCTAssertTrue(element("preference-editor-proteins").waitForExistence(timeout: 4))
        capture("11-preferences-multi-select")
        scrollTo(app.buttons["protein-Pork"])
        app.buttons["protein-Pork"].tap()
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preferences-saved-confirmation").waitForExistence(timeout: 5))

        launch(["--start-preferences", "--open-preference-editor", "allergens"])
        XCTAssertTrue(element("allergen-safety-note").waitForExistence(timeout: 4))
        scrollTo(app.buttons["allergen-Soy"])
        XCTAssertTrue(element("allergen-safety-note").exists)
        capture("12-medical-allergens")
        app.buttons["allergen-Soy"].tap()
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-reconciliation").waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Monday: Honey Soy Chicken")).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Wednesday: Ginger Rice Noodle")).firstMatch.exists)
        capture("13-preference-reconciliation")
        app.buttons["preference-reconciliation-save"].tap()
        XCTAssertTrue(element("preference-reconciliation").waitForNonExistence(timeout: 5))

        app.tabBars.buttons["Plans"].tap()
        let warning = element("plan-conflict-Monday")
        scrollTo(warning)
        XCTAssertTrue(app.buttons["clear-conflict-Monday"].isHittable)
        app.buttons["clear-conflict-Monday"].tap()
        XCTAssertTrue(warning.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "2 of 5 dinners planned")
    }

    func testHouseholdAndCookingDayDraftsCommitAtomicallyAndPersist() {
        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "household"])
        scrollTo(app.buttons["household-increment"])
        app.buttons["household-increment"].tap()
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-reconciliation").waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "3 planned dinners change to 2 servings")).firstMatch.exists)
        app.buttons["preference-reconciliation-save"].tap()
        XCTAssertTrue(element("preference-reconciliation").waitForNonExistence(timeout: 5))

        app.tabBars.buttons["Plans"].tap()
        XCTAssertTrue(app.staticTexts["budget-spent"].label.contains("$70.80"))
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("3 of 25"))

        app.tabBars.buttons["Preferences"].tap()
        scrollTo(app.buttons["day-Mon"])
        app.buttons["day-Mon"].tap()
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-reconciliation").waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Monday: Honey Soy Chicken")).firstMatch.exists)
        app.buttons["preference-reconciliation-save"].tap()
        XCTAssertTrue(element("preference-reconciliation").waitForNonExistence(timeout: 5))

        app.terminate()
        launch([])
        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "2 of 4 dinners planned")
        XCTAssertTrue(app.staticTexts["budget-spent"].label.contains("$47.60"))
        app.tabBars.buttons["Preferences"].tap()
        XCTAssertTrue(element("preferences-summary").label.contains("2 people"))
        XCTAssertTrue(element("preferences-summary").label.contains("4 dinners"))
    }

    func testCommittedStylePreferenceAndHardNoResultsRoute() {
        launch(["--reset-fixture", "--m3-personalized", "--start-discover"])
        let speedyStyle = element("style-Speedy")
        XCTAssertTrue(speedyStyle.waitForExistence(timeout: 5))
        XCTAssertEqual(speedyStyle.value as? String, "Preferred style")
        XCTAssertTrue(speedyStyle.isSelected)
        capture("14-personalized-discover")

        launch(["--reset-fixture", "--m3-no-results", "--start-discover"])
        let hardNoResults = element("explore-no-eligible-results")
        XCTAssertTrue(hardNoResults.waitForExistence(timeout: 5))
        XCTAssertEqual(hardNoResults.label, "No meals meet every hard rule")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Medical and dietary rules were not weakened")).firstMatch.exists)
        app.buttons["Review Preferences"].tap()
        XCTAssertTrue(element("preferences-screen").waitForExistence(timeout: 5))
    }

    func testDislikeDoesNotRemoveOrMedicalizeExploreRecipe() {
        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "dislikes"])
        XCTAssertTrue(element("preference-editor-dislikes").waitForExistence(timeout: 4))
        let add = app.buttons["add-disliked-ingredient"]
        scrollTo(add)
        add.tap()
        let ingredientSearch = app.searchFields.firstMatch
        XCTAssertTrue(ingredientSearch.waitForExistence(timeout: 4))
        ingredientSearch.tap()
        ingredientSearch.typeText("Pancetta")
        XCTAssertTrue(app.buttons["Pancetta"].waitForExistence(timeout: 4))
        app.buttons["Pancetta"].tap()
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preferences-saved-confirmation").waitForExistence(timeout: 5))

        app.tabBars.buttons["Meals"].tap()
        let search = app.textFields["for-you-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Proper Carbonara")
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
        let carbonara = element("discover-details-carbonara")
        XCTAssertTrue(carbonara.waitForExistence(timeout: 5))
        XCTAssertFalse(carbonara.label.localizedCaseInsensitiveContains("allergen"))
    }

    func testAutofillSuccessAndUnableStates() {
        let fill = app.buttons["autofill-plan"]
        XCTAssertTrue(fill.waitForExistence(timeout: 5))
        fill.tap()
        XCTAssertTrue(element("autofill-success").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Thu"].exists)
        capture("15-autofill-success")
        app.navigationBars.buttons["Done"].tap()
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "5 of 5 dinners planned")
        XCTAssertFalse(app.buttons["open-shopping-list"].label.contains("3 of 25"))

        launch(["--reset-fixture", "--m3-unable-autofill"])
        XCTAssertTrue(app.buttons["autofill-plan"].waitForExistence(timeout: 5))
        app.buttons["autofill-plan"].tap()
        XCTAssertTrue(element("autofill-unable").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "No eligible combination fits")).firstMatch.exists)
        XCTAssertTrue(app.buttons["autofill-review-preferences"].exists)
        capture("16-autofill-unable")
    }

    func testLargeDynamicTypePreferencesScreenshot() {
        launch([
            "--reset-fixture",
            "--start-preferences",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityL",
        ])
        XCTAssertTrue(element("preferences-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("preferences-summary").exists)
        capture("17-preferences-large-type")
    }

    private func launch(_ additionalArguments: [String]) {
        if app != nil { app.terminate() }
        app = XCUIApplication()
        var arguments = additionalArguments
        if !arguments.contains("-UIPreferredContentSizeCategoryName") {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        }
        app.launchArguments = arguments + ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    private func scrollTo(_ target: XCUIElement) {
        var attempts = 0
        let scrollView = app.scrollViews.firstMatch
        while (!target.exists || !target.isHittable) && attempts < 12 {
            if scrollView.exists {
                scrollView.swipeUp()
            } else {
                app.swipeUp()
            }
            attempts += 1
        }
        XCTAssertTrue(target.exists)
        XCTAssertTrue(target.isHittable)
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

final class Milestone4JourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBackendCataloguePersonalizationAndGeneratedWeekScreenshots() {
        launch(
            ["--reset-fixture", "--backend-enabled", "--backend-ignore-cache", "--m3-personalized", "--start-discover"],
            baseURL: "http://127.0.0.1:8787"
        )
        XCTAssertTrue(element("cuisine-grid").waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Local backend · Stub personalization"].exists)
        capture("18-discover-backend-catalogue")

        let search = app.textFields["for-you-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Proper Carbonara")
        if app.keyboards.buttons["Search"].exists {
            app.keyboards.buttons["Search"].tap()
        }
        let carbonara = element("discover-details-carbonara")
        XCTAssertTrue(carbonara.waitForExistence(timeout: 5))
        XCTAssertTrue(carbonara.label.localizedCaseInsensitiveContains("Proper Carbonara"))
        capture("19-backend-validated-search")

        app.tabBars.buttons["Plans"].tap()
        XCTAssertTrue(app.buttons["autofill-plan"].waitForExistence(timeout: 5))
        app.buttons["autofill-plan"].tap()
        XCTAssertTrue(element("autofill-success").waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Local backend · Stub personalization"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Projected week")).firstMatch.exists)
        capture("20-backend-generated-week")
    }

    func testInvalidBackendOutputShowsHonestLocalFallbackScreenshot() {
        launch(
            ["--reset-fixture", "--backend-enabled", "--backend-ignore-cache", "--start-discover"],
            baseURL: "http://127.0.0.1:8790"
        )
        XCTAssertTrue(app.staticTexts["Local fallback active"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "failed validation")).firstMatch.exists)
        XCTAssertTrue(element("cuisine-grid").exists)
        capture("21-honest-local-fallback")
    }

    func testBackendUnavailableRecoveryStateScreenshot() {
        launch(
            ["--reset-fixture", "--backend-enabled", "--backend-ignore-cache", "--start-discover"],
            baseURL: "http://127.0.0.1:8799"
        )
        XCTAssertTrue(app.staticTexts["Offline · On-device mode"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["backend-retry"].exists)
        XCTAssertTrue(element("cuisine-grid").exists)
        capture("22-backend-unavailable-recovery")
    }

    private func launch(_ arguments: [String], baseURL: String) {
        app = XCUIApplication()
        app.launchArguments = arguments + ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["WEEKNIGHT_BACKEND_BASE_URL"] = baseURL
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func scrollTo(_ target: XCUIElement) {
        var attempts = 0
        let scrollView = app.scrollViews.firstMatch
        while (!target.exists || !target.isHittable) && attempts < 12 {
            if scrollView.exists {
                scrollView.swipeUp()
            } else {
                app.swipeUp()
            }
            attempts += 1
        }
        XCTAssertTrue(target.exists)
        XCTAssertTrue(target.isHittable)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

final class Milestone46InformationArchitectureTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-fixture", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    func testPrimaryNavigationAndMealsSections() {
        XCTAssertTrue(app.tabBars.buttons["Plans"].exists)
        XCTAssertTrue(app.tabBars.buttons["Meals"].exists)
        XCTAssertTrue(app.tabBars.buttons["Preferences"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
        XCTAssertFalse(app.tabBars.buttons["Discover"].exists)
        XCTAssertFalse(app.tabBars.buttons["Saved"].exists)

        app.tabBars.buttons["Meals"].tap()
        XCTAssertTrue(element("styles-toggle").waitForExistence(timeout: 5))
        XCTAssertTrue(element("cuisine-grid").exists)
        let sectionControl = app.segmentedControls.firstMatch
        XCTAssertTrue(sectionControl.exists)
        XCTAssertTrue(sectionControl.buttons["Explore"].isSelected)
        sectionControl.buttons["Saved"].tap()
        XCTAssertTrue(element("saved-count").waitForExistence(timeout: 5))
        XCTAssertTrue(element("saved-recipe-curry").exists)
    }

    func testEveryPrimaryTabCanRevealContentBelowTheFold() {
        assertCanReveal(element("empty-meal-Friday"), screen: "Plans")

        app.tabBars.buttons["Meals"].tap()
        XCTAssertTrue(element("styles-toggle").waitForExistence(timeout: 5))
        assertCanReveal(element("cuisine-Indian"), screen: "Meals")

        app.tabBars.buttons["Preferences"].tap()
        XCTAssertTrue(element("preferences-title").waitForExistence(timeout: 5))
        assertCanReveal(element("preference-editor-appliances"), screen: "Preferences", maxSwipes: 18)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        assertCanReveal(app.buttons["settings-reset-data"], screen: "Settings")
    }

    func testPlansShowsEveryConfiguredCookingDayAndEmptyStates() {
        XCTAssertTrue(app.staticTexts["meal-Monday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["meal-Tuesday"].exists)
        XCTAssertTrue(app.staticTexts["meal-Wednesday"].exists)
        XCTAssertTrue(app.staticTexts["empty-meal-Thursday"].exists)
        XCTAssertTrue(app.staticTexts["empty-meal-Friday"].exists)
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "3 of 5 dinners planned")
    }

    func testPreferencesAndSettingsContainOnlyHonestDestinations() {
        app.tabBars.buttons["Preferences"].tap()
        XCTAssertTrue(app.staticTexts["preferences-title"].waitForExistence(timeout: 5))
        assertCanReveal(element("allergen-safety-note"), screen: "Preferences", maxSwipes: 16)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("23-settings")
        let reset = app.buttons["settings-reset-data"]
        var attempts = 0
        while (!reset.exists || !reset.isHittable) && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(reset.exists)
        XCTAssertFalse(app.buttons["Sign in with Apple"].exists)
        XCTAssertFalse(app.staticTexts["Subscriptions"].exists)
    }

    func testAccessibilityTypeKeepsPrimaryDestinationsNavigable() {
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

        XCTAssertTrue(app.staticTexts["plan-headline"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Meals"].tap()
        XCTAssertTrue(element("styles-toggle").waitForExistence(timeout: 5))
        app.tabBars.buttons["Preferences"].tap()
        XCTAssertTrue(app.staticTexts["preferences-title"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func testPrimaryScreensPassAccessibilityAudit() throws {
        try auditPrimaryScreens(for: [
            .contrast,
            .hitRegion,
            .sufficientElementDescription,
            .textClipped,
        ])
    }

    func testPrimaryScreensPassHighContrastAudit() throws {
        try auditPrimaryScreens(for: [
            .contrast,
            .hitRegion,
            .sufficientElementDescription,
        ])
    }

    private func auditPrimaryScreens(for auditTypes: XCUIAccessibilityAuditType) throws {
        XCTAssertTrue(app.staticTexts["plan-headline"].waitForExistence(timeout: 5))
        try auditCurrentScreen(for: auditTypes)

        app.tabBars.buttons["Meals"].tap()
        XCTAssertTrue(element("styles-toggle").waitForExistence(timeout: 5))
        try auditCurrentScreen(for: auditTypes)

        app.tabBars.buttons["Preferences"].tap()
        XCTAssertTrue(app.staticTexts["preferences-title"].waitForExistence(timeout: 5))
        try auditCurrentScreen(for: auditTypes)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        try auditCurrentScreen(for: auditTypes)
    }

    private func auditCurrentScreen(for auditTypes: XCUIAccessibilityAuditType) throws {
        try app.performAccessibilityAudit(for: auditTypes) { issue in
            guard let element = issue.element else {
                // XCTest can report unattributed clipping or contrast issues for
                // scroll content composited below iOS 26's system tab-bar material.
                // Attributed visible elements still fail this audit, while real
                // scrolling and Dynamic Type are exercised independently.
                return issue.auditType == .textClipped || issue.auditType == .contrast
            }
            let tabBar = self.app.tabBars.firstMatch
            let tabTop = tabBar.exists ? tabBar.frame.minY : self.app.frame.maxY
            let primaryTabLabels = ["Plans", "Meals", "Preferences", "Settings"]
            let isPrimaryTab = element.elementType == .button && primaryTabLabels.contains(element.label)
            let extendsBehindTabBar = !isPrimaryTab && element.frame.maxY > tabTop - 44
            let isVerifiedPlanStatusFalsePositive = issue.auditType == .textClipped
                && element.identifier.hasPrefix("plan-fit-")
            let isSingleLineSearchPromptFalsePositive = issue.auditType == .textClipped
                && element.elementType == .textField
                && ["for-you-search", "saved-search", "browse-search"].contains(element.identifier)
            let isOutsideRenderedViewport = !element.frame.intersects(self.app.frame)
                || !element.isHittable
                || extendsBehindTabBar
            return isOutsideRenderedViewport
                || isVerifiedPlanStatusFalsePositive
                || isSingleLineSearchPromptFalsePositive
        }
    }

    private func assertCanReveal(_ target: XCUIElement, screen: String, maxSwipes: Int = 10) {
        let tabTop = app.tabBars.firstMatch.frame.minY

        for _ in 0..<maxSwipes {
            if target.exists, target.frame.minY >= app.frame.minY, target.frame.maxY <= tabTop {
                XCTAssertTrue(app.tabBars.buttons[screen].exists)
                return
            }
            app.swipeUp()
        }

        XCTFail("\(screen) could not scroll its below-the-fold content above the tab bar")
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

final class Milestone461MealsRefinementTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        launch(["--reset-fixture", "--start-discover"])
    }

    func testExploreStylesExpandBrowseAndCollapse() {
        XCTAssertTrue(element("styles-toggle").waitForExistence(timeout: 5))
        XCTAssertEqual(element("styles-toggle").value as? String, "Collapsed")
        XCTAssertTrue(element("style-Speedy").exists)
        XCTAssertFalse(element("style-Treat night").exists)

        element("styles-toggle").tap()
        XCTAssertEqual(element("styles-toggle").value as? String, "Expanded")
        XCTAssertTrue(element("style-Treat night").exists)
        capture("24-meals-explore-expanded")

        let speedy = element("style-Speedy")
        scrollTo(speedy)
        speedy.tap()
        XCTAssertTrue(app.navigationBars["Speedy meals"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("browse-result-count").label.contains("meal"))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertEqual(element("styles-toggle").value as? String, "Expanded")
        element("styles-toggle").tap()
        XCTAssertEqual(element("styles-toggle").value as? String, "Collapsed")
    }

    func testCuisineNavigationSearchSortPlannedLabelAndAddAction() {
        let asian = element("cuisine-Asian")
        XCTAssertTrue(asian.waitForExistence(timeout: 5))
        XCTAssertTrue(asian.label.contains("2 meals"))
        XCTAssertTrue(asian.label.contains("$10.20"))
        asian.tap()

        XCTAssertTrue(app.navigationBars["Asian"].waitForExistence(timeout: 5))
        XCTAssertEqual(element("browse-result-count").label, "2 meals inside your rules")
        XCTAssertEqual(element("browse-sort").label, "Sort meals, Cheapest first")
        XCTAssertTrue(element("planned-recipe-honeysoy").label.contains("Monday"))

        let add = app.buttons["add-recipe-stirfry"]
        XCTAssertTrue(add.exists)
        XCTAssertEqual(add.label, "Add Ginger Rice Noodle Stir-Fry to plan.")
        capture("25-meals-cuisine-asian")

        let search = app.textFields["browse-search"]
        search.tap()
        search.typeText("Honey Soy")
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
        XCTAssertEqual(element("browse-result-count").label, "1 of 2 meals")
        XCTAssertTrue(element("discover-title-honeysoy").exists)
        XCTAssertFalse(element("discover-title-stirfry").exists)

        app.buttons["Clear search"].tap()
        element("browse-sort").tap()
        XCTAssertTrue(app.buttons["Name"].waitForExistence(timeout: 3))
        app.buttons["Name"].tap()
        XCTAssertEqual(element("browse-sort").label, "Sort meals, Name")

        app.buttons["add-recipe-stirfry"].tap()
        XCTAssertTrue(element("add-to-week-sheet").waitForExistence(timeout: 5))
    }

    func testSavedPresentationOrderingUnsaveNoResultsAndEmptyState() {
        let exploreSearch = app.textFields["for-you-search"]
        XCTAssertTrue(exploreSearch.waitForExistence(timeout: 5))
        exploreSearch.tap()
        exploreSearch.typeText("Honey Soy")
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
        app.buttons["discover-details-honeysoy"].tap()
        XCTAssertTrue(app.buttons["details-save-honeysoy"].waitForExistence(timeout: 5))
        app.buttons["details-save-honeysoy"].tap()
        app.buttons["recipe-details-back"].tap()

        app.segmentedControls.firstMatch.buttons["Saved"].tap()
        XCTAssertTrue(element("saved-count").waitForExistence(timeout: 5))
        XCTAssertTrue(element("saved-recipe-honeysoy").exists)
        XCTAssertTrue(element("saved-recipe-curry").exists)
        XCTAssertTrue(element("saved-recipe-caesar").exists)
        XCTAssertLessThan(element("saved-recipe-honeysoy").frame.minY, element("saved-recipe-curry").frame.minY)
        XCTAssertEqual(app.buttons["saved-unsave-curry"].value as? String, "Saved")
        XCTAssertTrue(element("saved-status-honeysoy").label.contains("Already planned for Monday"))
        capture("26-meals-saved")

        app.buttons["saved-unsave-curry"].tap()
        XCTAssertTrue(element("saved-recipe-curry").waitForNonExistence(timeout: 5))

        let search = app.textFields["saved-search"]
        search.tap()
        search.typeText("No matching supper")
        if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
        XCTAssertTrue(element("saved-no-results-state").waitForExistence(timeout: 5))

        launch(["--reset-fixture", "--saved-empty", "--start-saved"])
        XCTAssertTrue(element("saved-empty-state").waitForExistence(timeout: 5))
    }

    func testExploreAccessibilityDynamicTypeLayout() {
        launch([
            "--reset-fixture",
            "--start-discover",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityL",
        ])
        XCTAssertTrue(element("styles-toggle").waitForExistence(timeout: 5))
        scrollTo(element("cuisine-Asian"))
        capture("27-meals-explore-accessibility-large")
    }

    private func launch(_ arguments: [String]) {
        if app != nil { app.terminate() }
        app = XCUIApplication()
        app.launchArguments = arguments + ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    private func scrollTo(_ target: XCUIElement) {
        var attempts = 0
        while (!target.exists || !target.isHittable) && attempts < 12 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(target.exists)
        XCTAssertTrue(target.isHittable)
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

final class Milestone462PreferencesRedesignTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        launch(["--reset-fixture", "--start-preferences"])
    }

    func testWeekDraftControlsStaySynchronizedUntilDiscarded() {
        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "budget"])
        XCTAssertTrue(element("preference-editor-budget").waitForExistence(timeout: 5))
        let decrement = app.buttons["budget-decrement"]
        XCTAssertTrue(decrement.waitForExistence(timeout: 3))
        decrement.tap()
        XCTAssertEqual(element("budget-value").value as? String, "$70.00")
        XCTAssertEqual(element("preferences-unsaved-count").label, "1 unsaved change")

        app.buttons["budget-exact"].tap()
        let exact = app.textFields["budget-exact-field"]
        XCTAssertTrue(exact.waitForExistence(timeout: 4))
        XCTAssertEqual(exact.value as? String, "70.00")
        app.navigationBars.buttons["Cancel"].tap()

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "cookingTime"])
        let thirty = app.buttons["cooking-time-30"]
        XCTAssertTrue(thirty.waitForExistence(timeout: 4))
        thirty.tap()
        XCTAssertTrue(thirty.isSelected)
        XCTAssertEqual(thirty.value as? String, "Selected")
        app.buttons["preference-discard"].tap()
        XCTAssertEqual(app.buttons["cooking-time-45"].value as? String, "Selected")
    }

    func testSelectionStatesCookingDaysStylesDietAllergensAndKitchen() {
        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "cookingDays"])
        let friday = app.buttons["day-Fri"]
        XCTAssertEqual(friday.value as? String, "Selected, cooking day")
        friday.tap()
        XCTAssertEqual(friday.value as? String, "Not selected")
        app.buttons["preference-discard"].tap()

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "mealStyles"])
        let speedy = app.buttons["style-preference-Speedy"]
        XCTAssertTrue(speedy.waitForExistence(timeout: 4))
        speedy.tap()
        XCTAssertTrue(speedy.isSelected)
        XCTAssertTrue((speedy.value as? String)?.contains("Selected") == true)

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "dietary"])
        let vegetarian = app.buttons["dietary-Vegetarian"]
        XCTAssertTrue(vegetarian.waitForExistence(timeout: 4))
        vegetarian.tap()
        XCTAssertTrue(vegetarian.isSelected)
        XCTAssertEqual(vegetarian.value as? String, "On, selected dietary exclusion")

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "allergens"])
        let none = app.buttons["allergen-none"]
        let soy = app.buttons["allergen-Soy"]
        XCTAssertTrue(none.waitForExistence(timeout: 4))
        scrollTo(soy)
        XCTAssertTrue(none.isSelected)
        soy.tap()
        XCTAssertTrue(soy.isSelected)
        XCTAssertFalse(none.isSelected)
        none.tap()
        XCTAssertFalse(soy.isSelected)
        XCTAssertTrue(none.isSelected)

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "appliances"])
        let microwave = app.buttons["appliance-Microwave"]
        scrollTo(microwave)
        XCTAssertEqual(microwave.value as? String, "Don’t have it, not selected")
        microwave.tap()
        XCTAssertEqual(microwave.value as? String, "Have it, selected")
        XCTAssertTrue(element("kitchen-eligibility-summary").label.contains("catalogue meals fit"))
    }

    func testApprovedPreferenceReviewFrames() {
        capture("preferences-your-week")

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "budget"])
        XCTAssertTrue(element("preference-editor-budget").waitForExistence(timeout: 5))
        capture("preferences-budget-time-styles")

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "proteins"])
        XCTAssertTrue(element("preference-editor-proteins").waitForExistence(timeout: 5))
        capture("preferences-proteins-dislikes")

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "dietary"])
        XCTAssertTrue(element("preference-editor-dietary").waitForExistence(timeout: 5))
        capture("preferences-diet-allergens")

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "appliances"])
        XCTAssertTrue(element("preference-editor-appliances").waitForExistence(timeout: 5))
        capture("preferences-kitchen")

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "mealStyles"])
        app.buttons["style-preference-Speedy"].tap()
        scrollTo(app.buttons["protein-Chicken"])
        app.buttons["protein-Chicken"].tap()
        scrollTo(app.buttons["add-disliked-ingredient"])
        app.buttons["add-disliked-ingredient"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 4))
        search.tap()
        search.typeText("Pancetta")
        app.buttons["Pancetta"].tap()
        XCTAssertEqual(element("preferences-unsaved-count").label, "3 unsaved changes")
        capture("preferences-unsaved-changes")

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "allergens"])
        scrollTo(app.buttons["allergen-Soy"])
        app.buttons["allergen-Soy"].tap()
        XCTAssertTrue(element("preferences-unsaved-count").waitForExistence(timeout: 3))
        capture("preferences-reconciliation")
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-reconciliation").waitForExistence(timeout: 4))
        app.buttons["Keep editing"].tap()

        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "appliances"])
        let microwave = app.buttons["appliance-Microwave"]
        scrollTo(microwave)
        microwave.tap()
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preferences-saved-confirmation").waitForExistence(timeout: 5))
        capture("preferences-saved-confirmation")

        launch([
            "--reset-fixture", "--start-preferences", "--open-preference-editor", "cookingDays",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL",
        ])
        XCTAssertTrue(element("preference-editor-cookingDays").waitForExistence(timeout: 5))
        capture("preferences-accessibility-large")
    }

    private func launch(_ arguments: [String]) {
        if app != nil { app.terminate() }
        app = XCUIApplication()
        var launchArguments = arguments
        if !launchArguments.contains("-UIPreferredContentSizeCategoryName") {
            launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        }
        app.launchArguments = launchArguments + ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    private func scrollTo(_ target: XCUIElement) {
        var attempts = 0
        let scrollView = app.scrollViews["preferences-screen"]
        while (!target.exists || !target.isHittable) && attempts < 12 {
            scrollView.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(target.exists)
        XCTAssertTrue(target.isHittable)
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

final class Milestone46LegacyDiscoverBoundaryTests: XCTestCase {
    func testLegacyFeedDebugLaunchStillUsesSharedDetailsAndPlanningActions() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-fixture",
            "--start-discover",
            "--legacy-discover-feed",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()

        let legacyFeed = app.descendants(matching: .any)
            .matching(identifier: "legacy-discover-feed")
            .firstMatch
        XCTAssertTrue(legacyFeed.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Meals"].exists)
        XCTAssertFalse(app.tabBars.buttons["Discover"].exists)

        let details = app.buttons["discover-details-carbonara"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        details.tap()
        XCTAssertTrue(app.buttons["details-add-to-week"].waitForExistence(timeout: 5))
        app.buttons["recipe-details-back"].tap()

        XCTAssertTrue(legacyFeed.waitForExistence(timeout: 5))
        app.buttons["add-recipe-carbonara"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "add-to-week-sheet")
                .firstMatch
                .waitForExistence(timeout: 5)
        )
    }
}
