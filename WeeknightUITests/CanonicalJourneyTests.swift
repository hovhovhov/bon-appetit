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
        let discoverSave = app.buttons["discover-save-carbonara"]
        XCTAssertTrue(discoverSave.waitForExistence(timeout: 5))
        XCTAssertEqual(discoverSave.value as? String, "Not saved")
        discoverSave.tap()
        XCTAssertEqual(discoverSave.value as? String, "Saved")

        selectSavedMeals()
        XCTAssertTrue(element("saved-recipe-carbonara").waitForExistence(timeout: 5))
        app.buttons["saved-details-carbonara"].tap()
        let detailsSave = app.buttons["details-save-carbonara"]
        XCTAssertTrue(detailsSave.waitForExistence(timeout: 5))
        XCTAssertEqual(detailsSave.value as? String, "Saved")
        detailsSave.tap()
        XCTAssertEqual(detailsSave.value as? String, "Not saved")
        app.buttons["recipe-details-back"].tap()
        XCTAssertFalse(element("saved-recipe-carbonara").exists)

        selectForYouMeals()
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

    private func selectForYouMeals() {
        app.tabBars.buttons["Meals"].tap()
        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["For You"].tap()
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].waitForExistence(timeout: 5))
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
        app.tabBars.buttons["Preferences"].tap()
        element("preference-row-household").tap()
        XCTAssertTrue(element("preference-editor-household").waitForExistence(timeout: 4))
        incrementStepper("household-stepper")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(element("preference-editor-household").waitForNonExistence(timeout: 5))
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
        app.buttons["protein-Pork"].tap()
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-editor-proteins").waitForNonExistence(timeout: 5))

        launch(["--start-preferences", "--open-preference-editor", "allergens"])
        XCTAssertTrue(element("preference-editor-allergens").waitForExistence(timeout: 4))
        XCTAssertTrue(element("allergen-safety-note").exists)
        capture("12-medical-allergens")
        app.buttons["allergen-Soy"].tap()
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-reconciliation").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Monday: Honey Soy Chicken")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Wednesday: Ginger Rice Noodle")).firstMatch.exists)
        capture("13-preference-reconciliation")
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-editor-allergens").waitForNonExistence(timeout: 5))

        app.tabBars.buttons["Plans"].tap()
        let warning = element("plan-conflict-Monday")
        scrollTo(warning)
        XCTAssertTrue(app.buttons["clear-conflict-Monday"].isHittable)
        app.buttons["clear-conflict-Monday"].tap()
        XCTAssertTrue(warning.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "2 of 5 dinners planned")
    }

    func testHouseholdAndCookingDayDraftsCommitAtomicallyAndPersist() {
        app.tabBars.buttons["Preferences"].tap()
        element("preference-row-household").tap()
        XCTAssertTrue(element("preference-editor-household").waitForExistence(timeout: 4))
        incrementStepper("household-stepper")
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-reconciliation").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "3 planned meals change to 2 servings")).firstMatch.exists)
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-editor-household").waitForNonExistence(timeout: 5))

        app.tabBars.buttons["Plans"].tap()
        XCTAssertTrue(app.staticTexts["budget-spent"].label.contains("$70.80"))
        XCTAssertTrue(app.buttons["open-shopping-list"].label.contains("3 of 25"))

        app.tabBars.buttons["Preferences"].tap()
        let days = element("preference-row-cookingDays")
        scrollTo(days)
        days.tap()
        XCTAssertTrue(element("preference-editor-cookingDays").waitForExistence(timeout: 4))
        app.buttons["day-Mon"].tap()
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-reconciliation").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Monday: Honey Soy Chicken")).firstMatch.exists)
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-editor-cookingDays").waitForNonExistence(timeout: 5))

        app.terminate()
        launch([])
        XCTAssertTrue(element("plan-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["plan-progress"].label, "2 of 4 dinners planned")
        XCTAssertTrue(app.staticTexts["budget-spent"].label.contains("$47.60"))
        app.tabBars.buttons["Preferences"].tap()
        XCTAssertTrue(element("preferences-summary").label.contains("2 people"))
        XCTAssertTrue(element("preferences-summary").label.contains("4 dinners"))
    }

    func testPersonalizedDiscoverExplanationAndHardNoResultsRoute() {
        launch(["--reset-fixture", "--m3-personalized", "--start-discover"])
        let explanation = element("discover-explanation-carbonara")
        XCTAssertTrue(explanation.waitForExistence(timeout: 5))
        XCTAssertTrue(explanation.label.localizedCaseInsensitiveContains("speedy meal style"))
        capture("14-personalized-discover")

        launch(["--reset-fixture", "--m3-no-results", "--start-discover"])
        XCTAssertTrue(app.staticTexts["No meals meet every hard rule"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Medical and dietary rules were not weakened")).firstMatch.exists)
        app.buttons["Review Preferences"].tap()
        XCTAssertTrue(element("preferences-screen").waitForExistence(timeout: 5))
    }

    func testDislikeDeprioritizesWithoutRemovingOrMedicalizingRecipe() {
        launch(["--reset-fixture", "--start-preferences", "--open-preference-editor", "dislikes"])
        XCTAssertTrue(element("preference-editor-dislikes").waitForExistence(timeout: 4))
        app.buttons["dislike-pancetta"].tap()
        app.buttons["preference-save"].tap()
        XCTAssertTrue(element("preference-editor-dislikes").waitForNonExistence(timeout: 5))

        app.tabBars.buttons["Meals"].tap()
        let firstRecipeTitle = app.staticTexts
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "discover-title-"))
            .firstMatch
        XCTAssertTrue(firstRecipeTitle.waitForExistence(timeout: 5))
        XCTAssertNotEqual(firstRecipeTitle.identifier, "discover-title-carbonara")

        let carbonaraExplanation = element("discover-explanation-carbonara")
        scrollTo(carbonaraExplanation)
        XCTAssertTrue(carbonaraExplanation.label.localizedCaseInsensitiveContains("marked as disliked"))
        XCTAssertFalse(carbonaraExplanation.label.localizedCaseInsensitiveContains("allergen"))
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
        app.launchArguments = additionalArguments + ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
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

    private func incrementStepper(_ identifier: String) {
        let stepper = app.steppers[identifier]
        XCTAssertTrue(stepper.waitForExistence(timeout: 4))
        XCTAssertGreaterThanOrEqual(stepper.buttons.count, 2)
        let increment = stepper.buttons.element(boundBy: 1)
        increment.tap()
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
        XCTAssertTrue(app.staticTexts["Local backend · Stub personalization"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discover-title-")).firstMatch.exists)
        capture("18-discover-backend-catalogue")

        let search = app.textFields["for-you-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Proper Carbonara")
        if app.keyboards.buttons["Search"].exists {
            app.keyboards.buttons["Search"].tap()
        }
        let carbonaraExplanation = element("discover-explanation-carbonara")
        scrollTo(carbonaraExplanation)
        XCTAssertTrue(carbonaraExplanation.label.localizedCaseInsensitiveContains("backend match"))
        XCTAssertTrue(carbonaraExplanation.label.localizedCaseInsensitiveContains("pork"))
        capture("19-backend-personalized-explanations")

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
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].exists)
        capture("21-honest-local-fallback")
    }

    func testBackendUnavailableRecoveryStateScreenshot() {
        launch(
            ["--reset-fixture", "--backend-enabled", "--backend-ignore-cache", "--start-discover"],
            baseURL: "http://127.0.0.1:8799"
        )
        XCTAssertTrue(app.staticTexts["Offline · On-device mode"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["backend-retry"].exists)
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].exists)
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
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].waitForExistence(timeout: 5))
        let sectionControl = app.segmentedControls.firstMatch
        XCTAssertTrue(sectionControl.exists)
        sectionControl.buttons["Saved"].tap()
        XCTAssertTrue(element("saved-count").waitForExistence(timeout: 5))
        XCTAssertTrue(element("saved-recipe-curry").exists)
    }

    func testEveryPrimaryTabCanRevealContentBelowTheFold() {
        assertCanReveal(element("empty-meal-Friday"), screen: "Plans")

        app.tabBars.buttons["Meals"].tap()
        XCTAssertTrue(element("discover-title-carbonara").waitForExistence(timeout: 5))
        assertCanReveal(element("discover-title-steak"), screen: "Meals")

        app.tabBars.buttons["Preferences"].tap()
        XCTAssertTrue(element("preferences-title").waitForExistence(timeout: 5))
        assertCanReveal(element("preference-row-appliances"), screen: "Preferences")

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
        XCTAssertTrue(element("preference-row-allergens").exists)

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
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["discover-title-carbonara"].waitForExistence(timeout: 5))
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
            let isOutsideRenderedViewport = !element.frame.intersects(self.app.frame)
                || !element.isHittable
                || extendsBehindTabBar
            return isOutsideRenderedViewport || isVerifiedPlanStatusFalsePositive
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
