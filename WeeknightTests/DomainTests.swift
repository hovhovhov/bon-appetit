import XCTest
@testable import Weeknight

final class DomainTests: XCTestCase {
    func testMoneyUsesIntegerMinorUnits() {
        let first = Money(minorUnits: 890)
        let second = Money(minorUnits: 1_240)

        XCTAssertEqual(first + second, Money(minorUnits: 2_130))
        XCTAssertEqual(second - first, Money(minorUnits: 350))
        XCTAssertEqual(first.formatted(locale: Locale(identifier: "en_US")), "$8.90")
    }

    func testFilledAndOpenMealSlots() {
        let plan = WeeknightFixture.initialPlan

        XCTAssertEqual(Planning.filledSlots(in: plan).map(\.day), [.monday, .tuesday, .wednesday])
        XCTAssertEqual(Planning.openSlots(in: plan).map(\.day), [.thursday, .friday])
    }

    func testAddToFreeDay() throws {
        let carbonara = try XCTUnwrap(recipe("carbonara"))
        let updated = Planning.assigning(recipeID: carbonara.id, to: .thursday, in: WeeknightFixture.initialPlan)

        XCTAssertEqual(updated.slots.first(where: { $0.day == .thursday })?.recipeID, "carbonara")
        XCTAssertEqual(updated.revision, WeeknightFixture.initialPlan.revision + 1)
        XCTAssertEqual(Planning.weeklySpend(plan: updated, recipes: WeeknightFixture.recipes), WeeknightFixture.money(4_430))
    }

    func testReplacementSubtractsOldRecipeBeforeAddingNewRecipe() throws {
        let carbonara = try XCTUnwrap(recipe("carbonara"))
        let preview = Planning.previewAssignment(
            recipe: carbonara,
            to: .monday,
            in: WeeknightFixture.initialPlan,
            recipes: WeeknightFixture.recipes
        )

        XCTAssertEqual(preview.replacedRecipe?.id, "honeysoy")
        XCTAssertEqual(preview.projectedSpend, WeeknightFixture.money(3_270))
        XCTAssertEqual(preview.projectedRemaining, WeeknightFixture.money(4_730))
    }

    func testWeeklySpendAndRemainingBudget() {
        let plan = WeeknightFixture.initialPlan

        XCTAssertEqual(Planning.weeklySpend(plan: plan, recipes: WeeknightFixture.recipes), WeeknightFixture.money(3_540))
        XCTAssertEqual(Planning.remainingBudget(plan: plan, recipes: WeeknightFixture.recipes), WeeknightFixture.money(4_460))
    }

    func testBudgetStatusBoundaries() {
        XCTAssertEqual(status(spend: 8_500, budget: 10_000), .comfortable)
        XCTAssertEqual(status(spend: 8_501, budget: 10_000), .nearLimit)
        XCTAssertEqual(status(spend: 10_000, budget: 10_000), .exactlyAtBudget)
        XCTAssertEqual(status(spend: 10_001, budget: 10_000), .overBudget)
    }

    func testCanonicalIngredientAggregationAndSharedContributions() throws {
        let items = Planning.shoppingItems(
            plan: WeeknightFixture.initialPlan,
            recipes: WeeknightFixture.recipes,
            checkedIngredientIDs: WeeknightFixture.initialCheckedIngredientIDs
        )
        let garlic = try XCTUnwrap(items.first(where: { $0.id == "garlic" }))

        XCTAssertEqual(items.count, 25)
        XCTAssertEqual(garlic.quantityDisplay, "3 cloves × 2")
        XCTAssertEqual(garlic.estimatedCost, WeeknightFixture.money(70))
        XCTAssertEqual(garlic.contributions.map(\.day), [.monday, .wednesday])
    }

    func testShoppingProgress() {
        let items = Planning.shoppingItems(
            plan: WeeknightFixture.initialPlan,
            recipes: WeeknightFixture.recipes,
            checkedIngredientIDs: WeeknightFixture.initialCheckedIngredientIDs
        )

        XCTAssertEqual(Planning.shoppingProgress(items: items), ShoppingProgress(checked: 3, total: 25))
        XCTAssertEqual(Planning.aisleProgress(.produce, items: items), ShoppingProgress(checked: 1, total: 9))
    }

    func testExactCanonicalFixtureTotalsThroughCompleteLoop() {
        var plan = WeeknightFixture.initialPlan
        var checked = WeeknightFixture.initialCheckedIngredientIDs

        XCTAssertEqual(Planning.filledSlots(in: plan).count, 3)
        XCTAssertEqual(Planning.weeklySpend(plan: plan, recipes: WeeknightFixture.recipes), WeeknightFixture.money(3_540))
        XCTAssertEqual(Planning.shoppingItems(plan: plan, recipes: WeeknightFixture.recipes, checkedIngredientIDs: checked).count, 25)

        plan = Planning.assigning(recipeID: "carbonara", to: .thursday, in: plan)
        var items = Planning.shoppingItems(plan: plan, recipes: WeeknightFixture.recipes, checkedIngredientIDs: checked)
        XCTAssertEqual(Planning.weeklySpend(plan: plan, recipes: WeeknightFixture.recipes), WeeknightFixture.money(4_430))
        XCTAssertEqual(Planning.remainingBudget(plan: plan, recipes: WeeknightFixture.recipes), WeeknightFixture.money(3_570))
        XCTAssertEqual(items.count, 31)
        XCTAssertEqual(Planning.shoppingProgress(items: items).checked, 3)

        plan = Planning.assigning(recipeID: "curry", to: .friday, in: plan)
        items = Planning.shoppingItems(plan: plan, recipes: WeeknightFixture.recipes, checkedIngredientIDs: checked)
        XCTAssertEqual(Planning.filledSlots(in: plan).count, 5)
        XCTAssertEqual(Planning.weeklySpend(plan: plan, recipes: WeeknightFixture.recipes), WeeknightFixture.money(5_670))
        XCTAssertEqual(Planning.remainingBudget(plan: plan, recipes: WeeknightFixture.recipes), WeeknightFixture.money(2_330))
        XCTAssertEqual(items.count, 36)
        XCTAssertEqual(Planning.shoppingProgress(items: items), ShoppingProgress(checked: 3, total: 36))

        checked.insert("broccoli")
        items = Planning.shoppingItems(plan: plan, recipes: WeeknightFixture.recipes, checkedIngredientIDs: checked)
        XCTAssertEqual(Planning.shoppingProgress(items: items), ShoppingProgress(checked: 4, total: 36))
        XCTAssertEqual(Planning.aisleProgress(.produce, items: items), ShoppingProgress(checked: 2, total: 11))
    }

    func testServingDependentBudgetAndIngredientAggregation() throws {
        let carbonara = try XCTUnwrap(recipe("carbonara"))
        let plan = Planning.assigning(
            recipeID: carbonara.id,
            servings: 2,
            to: .thursday,
            in: WeeknightFixture.initialPlan
        )
        let items = Planning.shoppingItems(
            plan: plan,
            recipes: WeeknightFixture.recipes,
            checkedIngredientIDs: []
        )

        XCTAssertEqual(Planning.weeklySpend(plan: plan, recipes: WeeknightFixture.recipes), WeeknightFixture.money(5_320))
        XCTAssertEqual(items.first(where: { $0.id == "spaghetti" })?.quantityDisplay, "250g")
        XCTAssertEqual(items.first(where: { $0.id == "spaghetti" })?.estimatedCost, WeeknightFixture.money(140))
        XCTAssertEqual(items.first(where: { $0.id == "eggs" })?.quantityDisplay, "4")
    }

    func testServingDraftCancelAndLimits() {
        var draft = RecipeServingDraft(committed: 2)

        draft.increment()
        XCTAssertEqual(draft.value, 3)
        XCTAssertTrue(draft.isEdited)
        draft.cancel()
        XCTAssertEqual(draft.value, 2)
        XCTAssertFalse(draft.isEdited)

        var minimum = RecipeServingDraft(committed: RecipeServingDraft.minimum)
        minimum.decrement()
        XCTAssertEqual(minimum.value, RecipeServingDraft.minimum)
        XCTAssertFalse(minimum.canDecrement)

        var maximum = RecipeServingDraft(committed: RecipeServingDraft.maximum)
        maximum.increment()
        XCTAssertEqual(maximum.value, RecipeServingDraft.maximum)
        XCTAssertFalse(maximum.canIncrement)
    }

    func testAddAndSwapReuseAssignmentLogicWithServings() throws {
        var plan = Planning.assigning(recipeID: "carbonara", servings: 2, to: .thursday, in: WeeknightFixture.initialPlan)
        let curry = try XCTUnwrap(recipe("curry"))
        let preview = Planning.previewAssignment(
            recipe: curry,
            servings: 2,
            to: .thursday,
            in: plan,
            recipes: WeeknightFixture.recipes
        )

        XCTAssertEqual(preview.replacedRecipe?.id, "carbonara")
        XCTAssertEqual(preview.replacedServings, 2)
        plan = Planning.assigning(recipeID: curry.id, servings: 2, to: .thursday, in: plan)
        XCTAssertEqual(plan.slots.first(where: { $0.day == .thursday })?.servings, 2)
        XCTAssertEqual(Planning.weeklySpend(plan: plan, recipes: WeeknightFixture.recipes), WeeknightFixture.money(6_020))
    }

    private func recipe(_ id: Recipe.ID) -> Recipe? {
        WeeknightFixture.recipes.first(where: { $0.id == id })
    }

    private func status(spend: Int, budget: Int) -> BudgetStatus {
        let ingredient = Ingredient(id: "test", canonicalName: "test", displayName: "Test", aisle: .pantry)
        let recipe = Recipe(
            id: "test",
            title: "Test",
            sourceName: "Fixture",
            activeMinutes: 1,
            servings: 1,
            tags: [],
            rationale: "Boundary fixture",
            ingredients: [RecipeIngredient(ingredient: ingredient, quantity: "1", estimatedCost: Money(minorUnits: spend))],
            artwork: .chopped
        )
        let plan = WeekPlan(
            id: "boundary",
            weekLabel: "Boundary",
            storeName: "Fixture",
            budget: Money(minorUnits: budget),
            slots: [MealSlot(day: .monday, recipeID: recipe.id)],
            revision: 1
        )
        return Planning.budgetStatus(plan: plan, recipes: [recipe])
    }
}
