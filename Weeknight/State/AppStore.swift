import Foundation
import Observation

enum AppTab: Hashable {
    case plan
    case discover
    case saved
    case preferences
}

@MainActor
@Observable
final class AppStore {
    var selectedTab: AppTab = .plan
    private(set) var plan: WeekPlan
    private(set) var recipes: [Recipe]
    private(set) var checkedIngredientIDs: Set<Ingredient.ID>
    private(set) var recipeMode: RepositoryMode
    var shoppingMode: RepositoryMode
    private(set) var isAssigning = false
    private(set) var planMutationCount = 0
    var confirmationMessage: String?

    private let recipeRepository: any RecipeRepository
    private let planRepository: any PlanRepository
    private let shoppingRepository: any ShoppingRepository

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        recipeRepository: any RecipeRepository = MockRecipeRepository(),
        planRepository: (any PlanRepository)? = nil,
        shoppingRepository: any ShoppingRepository = MockShoppingRepository()
    ) {
        let recipeMode = Self.mode(after: "--recipe-mode", in: arguments) ?? .ready
        let shoppingMode = Self.mode(after: "--shopping-mode", in: arguments) ?? .ready
        let shouldFail = arguments.contains("--assignment-fails-once")
        let initialPlan = WeeknightFixture.initialPlan

        self.plan = initialPlan
        self.recipes = recipeMode == .ready || recipeMode == .stale ? WeeknightFixture.recipes : []
        self.checkedIngredientIDs = WeeknightFixture.initialCheckedIngredientIDs
        self.recipeMode = recipeMode
        self.shoppingMode = shoppingMode
        self.recipeRepository = recipeRepository
        self.planRepository = planRepository ?? MockPlanRepository(plan: initialPlan, shouldFailNextSave: shouldFail)
        self.shoppingRepository = shoppingRepository
    }

    var recipeLookup: [Recipe.ID: Recipe] { Planning.recipesByID(recipesForCalculations) }
    var recipesForCalculations: [Recipe] { WeeknightFixture.recipes }
    var filledCount: Int { Planning.filledSlots(in: plan).count }
    var totalCount: Int { plan.slots.count }
    var weeklySpend: Money { Planning.weeklySpend(plan: plan, recipes: recipesForCalculations) }
    var remainingBudget: Money { Planning.remainingBudget(plan: plan, recipes: recipesForCalculations) }
    var budgetStatus: BudgetStatus { Planning.budgetStatus(plan: plan, recipes: recipesForCalculations) }

    var shoppingItems: [ShoppingListItem] {
        Planning.shoppingItems(
            plan: plan,
            recipes: recipesForCalculations,
            checkedIngredientIDs: checkedIngredientIDs
        )
    }

    var shoppingProgress: ShoppingProgress {
        Planning.shoppingProgress(items: shoppingItems)
    }

    var discoverRecipes: [Recipe] {
        let used = Set(plan.slots.compactMap(\.recipeID))
        return recipes.filter { !used.contains($0.id) }
    }

    func recipe(for slot: MealSlot) -> Recipe? {
        guard let id = slot.recipeID else { return nil }
        return recipesForCalculations.first(where: { $0.id == id })
    }

    func preview(recipe: Recipe, day: Weekday) -> AssignmentPreview {
        Planning.previewAssignment(recipe: recipe, to: day, in: plan, recipes: recipesForCalculations)
    }

    func loadRecipesIfNeeded() async {
        guard recipeMode == .loading else { return }
        do {
            recipes = try await recipeRepository.load(mode: .loading)
            recipeMode = recipes.isEmpty ? .empty : .ready
        } catch {
            recipeMode = .error
        }
    }

    func retryRecipes() async {
        recipeMode = .loading
        do {
            recipes = try await recipeRepository.load(mode: .ready)
            recipeMode = recipes.isEmpty ? .empty : .ready
        } catch {
            recipeMode = .error
        }
    }

    func assign(recipe: Recipe, to day: Weekday) async throws {
        guard !isAssigning else { return }
        isAssigning = true
        defer { isAssigning = false }

        let updated = Planning.assigning(recipeID: recipe.id, to: day, in: plan)
        guard updated != plan else { return }
        try await planRepository.savePlan(updated)
        plan = updated
        planMutationCount += 1
        confirmationMessage = "\(recipe.title) added to \(day.rawValue). The week and shopping list are updated."
    }

    func toggleShoppingItem(_ item: ShoppingListItem) {
        if checkedIngredientIDs.contains(item.id) {
            checkedIngredientIDs.remove(item.id)
        } else {
            checkedIngredientIDs.insert(item.id)
        }
    }

    func retryShopping() async {
        shoppingMode = .loading
        shoppingMode = await shoppingRepository.retry()
    }

    func resetFixture() {
        plan = WeeknightFixture.initialPlan
        recipes = WeeknightFixture.recipes
        checkedIngredientIDs = WeeknightFixture.initialCheckedIngredientIDs
        recipeMode = .ready
        shoppingMode = .ready
        selectedTab = .plan
        confirmationMessage = "The canonical demo week has been reset."
        planMutationCount = 0
    }

    private static func mode(after flag: String, in arguments: [String]) -> RepositoryMode? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return RepositoryMode(rawValue: arguments[index + 1])
    }
}
