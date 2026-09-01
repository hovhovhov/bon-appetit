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
    private(set) var savedRecipeRecords: [SavedRecipeRecord]
    private(set) var recipeNotes: [Recipe.ID: String]
    private(set) var recipeMode: RepositoryMode
    var shoppingMode: RepositoryMode
    var savedMode: RepositoryMode
    private(set) var isAssigning = false
    private(set) var planMutationCount = 0
    private(set) var persistenceErrorMessage: String?
    var confirmationMessage: String?

    private let recipeRepository: any RecipeRepository
    private let planRepository: any PlanRepository
    private let shoppingRepository: any ShoppingRepository
    private let persistence: any AppStatePersistence
    private let now: @Sendable () -> Date

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        recipeRepository: any RecipeRepository = MockRecipeRepository(),
        planRepository: (any PlanRepository)? = nil,
        shoppingRepository: any ShoppingRepository = MockShoppingRepository(),
        persistence: (any AppStatePersistence)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        let recipeMode = Self.mode(after: "--recipe-mode", in: arguments) ?? .ready
        let shoppingMode = Self.mode(after: "--shopping-mode", in: arguments) ?? .ready
        let savedMode = Self.mode(after: "--saved-mode", in: arguments) ?? .ready
        let shouldFail = arguments.contains("--assignment-fails-once")
        let persistence = persistence ?? (arguments.isEmpty
            ? InMemoryAppStatePersistence()
            : AppStatePersistenceFactory.makeDefault())
        let canonical = WeeknightFixture.canonicalSnapshot

        let snapshot: AppSnapshot
        var persistenceErrorMessage: String?
        do {
            if arguments.contains("--reset-fixture") {
                try persistence.reset(to: canonical)
                snapshot = canonical
            } else if let loaded = try persistence.load() {
                snapshot = loaded
            } else {
                try persistence.save(canonical)
                snapshot = canonical
            }
        } catch {
            snapshot = canonical
            persistenceErrorMessage = error.localizedDescription
            try? persistence.reset(to: canonical)
        }

        self.plan = snapshot.plan
        self.recipes = recipeMode == .ready || recipeMode == .stale ? WeeknightFixture.recipes : []
        self.checkedIngredientIDs = snapshot.checkedIngredientIDs
        self.savedRecipeRecords = snapshot.savedRecipeRecords
        self.recipeNotes = snapshot.recipeNotes
        self.recipeMode = recipeMode
        self.shoppingMode = shoppingMode
        self.savedMode = savedMode
        self.persistenceErrorMessage = persistenceErrorMessage
        self.recipeRepository = recipeRepository
        self.planRepository = planRepository ?? MockPlanRepository(plan: snapshot.plan, shouldFailNextSave: shouldFail)
        self.shoppingRepository = shoppingRepository
        self.persistence = persistence
        self.now = now
    }

    var recipeLookup: [Recipe.ID: Recipe] { Planning.recipesByID(recipesForCalculations) }
    var recipesForCalculations: [Recipe] { WeeknightFixture.recipes }
    var filledCount: Int { Planning.filledSlots(in: plan).count }
    var totalCount: Int { plan.slots.count }
    var weeklySpend: Money { Planning.weeklySpend(plan: plan, recipes: recipesForCalculations) }
    var remainingBudget: Money { Planning.remainingBudget(plan: plan, recipes: recipesForCalculations) }
    var budgetStatus: BudgetStatus { Planning.budgetStatus(plan: plan, recipes: recipesForCalculations) }
    var savedCount: Int { savedRecipeRecords.count }

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

    var recentlySavedRecipes: [Recipe] {
        savedRecipeRecords
            .sorted { $0.savedAt > $1.savedAt }
            .compactMap { recipeLookup[$0.recipeID] }
    }

    func recipe(for slot: MealSlot) -> Recipe? {
        guard let id = slot.recipeID else { return nil }
        return recipesForCalculations.first(where: { $0.id == id })
    }

    func scheduledSlot(for recipeID: Recipe.ID) -> MealSlot? {
        plan.slots.first(where: { $0.recipeID == recipeID })
    }

    func preview(recipe: Recipe, servings: Int? = nil, day: Weekday) -> AssignmentPreview {
        Planning.previewAssignment(
            recipe: recipe,
            servings: servings,
            to: day,
            in: plan,
            recipes: recipesForCalculations
        )
    }

    func isSaved(_ recipeID: Recipe.ID) -> Bool {
        savedRecipeRecords.contains(where: { $0.recipeID == recipeID })
    }

    func savedAt(_ recipeID: Recipe.ID) -> Date? {
        savedRecipeRecords.first(where: { $0.recipeID == recipeID })?.savedAt
    }

    func savedRecipes(matching query: String, filter: SavedFilter) -> [Recipe] {
        let ordered: [Recipe]
        switch filter {
        case .all:
            ordered = recentlySavedRecipes.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .recentlySaved:
            ordered = recentlySavedRecipes
        }
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return ordered }
        return ordered.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(normalized)
                || recipe.sourceName.localizedCaseInsensitiveContains(normalized)
                || recipe.tags.contains(where: { $0.localizedCaseInsensitiveContains(normalized) })
                || recipe.ingredients.contains(where: {
                    $0.ingredient.displayName.localizedCaseInsensitiveContains(normalized)
                })
        }
    }

    func note(for recipeID: Recipe.ID) -> String {
        recipeNotes[recipeID] ?? ""
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

    func retrySaved() async {
        savedMode = .loading
        try? await Task.sleep(nanoseconds: 280_000_000)
        savedMode = .ready
    }

    func assign(recipe: Recipe, servings: Int? = nil, to day: Weekday) async throws {
        guard !isAssigning else { return }
        isAssigning = true
        defer { isAssigning = false }

        let selectedServings = servings ?? recipe.servings
        let updated = Planning.assigning(recipeID: recipe.id, servings: selectedServings, to: day, in: plan)
        guard updated != plan else { return }
        try await planRepository.savePlan(updated)
        try persistence.save(snapshot(plan: updated))
        plan = updated
        reconcileCheckedItems()
        planMutationCount += 1
        confirmationMessage = "\(recipe.title) added to \(day.rawValue). The week and shopping list are updated."
    }

    func updateServings(for day: Weekday, to servings: Int) async throws {
        guard !isAssigning else { return }
        isAssigning = true
        defer { isAssigning = false }

        let updated = Planning.updatingServings(to: servings, on: day, in: plan)
        guard updated != plan else { return }
        try await planRepository.savePlan(updated)
        try persistence.save(snapshot(plan: updated))
        plan = updated
        reconcileCheckedItems()
        planMutationCount += 1
        confirmationMessage = "Servings updated. The plan, budget, and shopping list now agree."
    }

    func toggleSaved(_ recipeID: Recipe.ID) {
        let previous = savedRecipeRecords
        if isSaved(recipeID) {
            savedRecipeRecords.removeAll(where: { $0.recipeID == recipeID })
            confirmationMessage = "Recipe removed from Saved."
        } else {
            savedRecipeRecords.append(SavedRecipeRecord(recipeID: recipeID, savedAt: now()))
            confirmationMessage = "Recipe saved."
        }
        do {
            try persistence.save(snapshot())
            persistenceErrorMessage = nil
        } catch {
            savedRecipeRecords = previous
            persistenceErrorMessage = error.localizedDescription
            confirmationMessage = "The saved change could not be stored. Try again."
        }
    }

    func saveNote(_ note: String, for recipeID: Recipe.ID) {
        let previous = recipeNotes[recipeID]
        let normalized = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            recipeNotes.removeValue(forKey: recipeID)
        } else {
            recipeNotes[recipeID] = note
        }
        do {
            try persistence.save(snapshot())
            persistenceErrorMessage = nil
            confirmationMessage = normalized.isEmpty ? "Recipe note cleared." : "Recipe note saved."
        } catch {
            recipeNotes[recipeID] = previous
            persistenceErrorMessage = error.localizedDescription
            confirmationMessage = "The note could not be saved. Try again."
        }
    }

    func toggleShoppingItem(_ item: ShoppingListItem) {
        let previous = checkedIngredientIDs
        if checkedIngredientIDs.contains(item.id) {
            checkedIngredientIDs.remove(item.id)
        } else {
            checkedIngredientIDs.insert(item.id)
        }
        do {
            try persistence.save(snapshot())
            persistenceErrorMessage = nil
        } catch {
            checkedIngredientIDs = previous
            persistenceErrorMessage = error.localizedDescription
            confirmationMessage = "The shopping change could not be stored. Try again."
        }
    }

    func retryShopping() async {
        shoppingMode = .loading
        shoppingMode = await shoppingRepository.retry()
    }

    func resetFixture() {
        let canonical = WeeknightFixture.canonicalSnapshot
        do {
            try persistence.reset(to: canonical)
            persistenceErrorMessage = nil
        } catch {
            persistenceErrorMessage = error.localizedDescription
        }
        plan = canonical.plan
        recipes = WeeknightFixture.recipes
        checkedIngredientIDs = canonical.checkedIngredientIDs
        savedRecipeRecords = canonical.savedRecipeRecords
        recipeNotes = canonical.recipeNotes
        recipeMode = .ready
        shoppingMode = .ready
        savedMode = .ready
        selectedTab = .plan
        confirmationMessage = "The canonical demo week has been reset."
        planMutationCount = 0
    }

    private func reconcileCheckedItems() {
        let validIDs = Set(
            Planning.shoppingItems(
                plan: plan,
                recipes: recipesForCalculations,
                checkedIngredientIDs: []
            ).map(\.id)
        )
        checkedIngredientIDs.formIntersection(validIDs)
        try? persistence.save(snapshot())
    }

    private func snapshot(plan planOverride: WeekPlan? = nil) -> AppSnapshot {
        AppSnapshot(
            plan: planOverride ?? plan,
            checkedIngredientIDs: checkedIngredientIDs,
            savedRecipeRecords: savedRecipeRecords,
            recipeNotes: recipeNotes
        )
    }

    private static func mode(after flag: String, in arguments: [String]) -> RepositoryMode? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return RepositoryMode(rawValue: arguments[index + 1])
    }
}
