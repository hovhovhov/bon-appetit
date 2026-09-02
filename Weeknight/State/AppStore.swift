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
    private(set) var preferences: UserPreferences
    private(set) var recipeMode: RepositoryMode
    var shoppingMode: RepositoryMode
    var savedMode: RepositoryMode
    private(set) var isAssigning = false
    private(set) var isSavingPreferences = false
    private(set) var isAutofilling = false
    private(set) var planMutationCount = 0
    private(set) var persistenceErrorMessage: String?
    private(set) var backendState: BackendConnectionState
    var confirmationMessage: String?

    private let recipeRepository: any RecipeRepository
    private let planRepository: any PlanRepository
    private let shoppingRepository: any ShoppingRepository
    private let persistence: any AppStatePersistence
    private let now: @Sendable () -> Date
    private let backendClient: (any WeeknightBackendClient)?
    private let backendCache: any BackendCatalogueCaching
    private var backendCatalogueVersion: String?
    private var backendRecommendationOrder: [Recipe.ID] = []
    private var backendExplanations: [Recipe.ID: String] = [:]
    private var isBackendConnecting = false

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        recipeRepository: any RecipeRepository = MockRecipeRepository(),
        planRepository: (any PlanRepository)? = nil,
        shoppingRepository: any ShoppingRepository = MockShoppingRepository(),
        persistence: (any AppStatePersistence)? = nil,
        backendClient: (any WeeknightBackendClient)? = nil,
        backendCache: (any BackendCatalogueCaching)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        let recipeMode = Self.mode(after: "--recipe-mode", in: arguments) ?? .ready
        let shoppingMode = Self.mode(after: "--shopping-mode", in: arguments) ?? .ready
        let savedMode = Self.mode(after: "--saved-mode", in: arguments) ?? .ready
        let shouldFail = arguments.contains("--assignment-fails-once")
        let persistence = persistence ?? (arguments.isEmpty
            ? InMemoryAppStatePersistence()
            : AppStatePersistenceFactory.makeDefault())
        let backendConfiguration = BackendConfiguration.current(arguments: arguments)
        let resolvedBackendClient = backendClient
            ?? backendConfiguration.map { URLSessionWeeknightBackendClient(configuration: $0) }
        let resolvedBackendCache: any BackendCatalogueCaching = backendCache
            ?? (arguments.contains("--backend-ignore-cache")
                ? InMemoryBackendCatalogueCache()
                : FileBackendCatalogueCache())
        var canonical = WeeknightFixture.canonicalSnapshot
        if arguments.contains("--m3-conflict") {
            canonical.preferences.medicalAllergens = [.soy]
        }
        if arguments.contains("--m3-no-results") {
            canonical.preferences.dietaryRestrictions = [.vegan]
        }
        if arguments.contains("--m3-personalized") {
            canonical.preferences.preferredProteins = [.pork]
            canonical.preferences.preferredMealStyles = [.speedy]
        }
        if arguments.contains("--m3-unable-autofill") {
            canonical.preferences.weeklyBudget = Money(minorUnits: 4_000)
            canonical.plan.budget = Money(minorUnits: 4_000)
        }
        if arguments.contains("--v2-empty-plan") {
            canonical.plan.slots = canonical.plan.slots.map { slot in
                MealSlot(day: slot.day, recipeID: nil, servings: slot.servings)
            }
        }

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
        self.preferences = snapshot.preferences
        self.recipeMode = resolvedBackendClient == nil ? recipeMode : .loading
        self.shoppingMode = shoppingMode
        self.savedMode = savedMode
        self.persistenceErrorMessage = persistenceErrorMessage
        self.backendState = resolvedBackendClient == nil ? .local : .loading
        self.recipeRepository = recipeRepository
        self.planRepository = planRepository ?? MockPlanRepository(plan: snapshot.plan, shouldFailNextSave: shouldFail)
        self.shoppingRepository = shoppingRepository
        self.persistence = persistence
        self.backendClient = resolvedBackendClient
        self.backendCache = resolvedBackendCache
        self.now = now
        if arguments.contains("--start-preferences") {
            self.selectedTab = .preferences
        } else if arguments.contains("--start-discover") {
            self.selectedTab = .discover
        }
    }

    var recipeLookup: [Recipe.ID: Recipe] { Planning.recipesByID(recipesForCalculations) }
    var recipesForCalculations: [Recipe] {
        let available = Set(recipes.map(\.id))
        let required = Set(WeeknightFixture.recipes.map(\.id))
        return !recipes.isEmpty && required.isSubset(of: available) ? recipes : WeeknightFixture.recipes
    }
    var filledCount: Int { Planning.filledSlots(in: plan).count }
    var totalCount: Int { plan.slots.count }
    var weeklySpend: Money {
        Planning.weeklySpend(
            plan: plan,
            recipes: recipesForCalculations,
            priceBasisPoints: preferences.supermarket.priceBasisPoints
        )
    }
    var remainingBudget: Money {
        Planning.remainingBudget(
            plan: plan,
            recipes: recipesForCalculations,
            priceBasisPoints: preferences.supermarket.priceBasisPoints
        )
    }
    var budgetStatus: BudgetStatus {
        Planning.budgetStatus(
            plan: plan,
            recipes: recipesForCalculations,
            priceBasisPoints: preferences.supermarket.priceBasisPoints
        )
    }
    var savedCount: Int { savedRecipeRecords.count }

    var shoppingItems: [ShoppingListItem] {
        Planning.shoppingItems(
            plan: plan,
            recipes: recipesForCalculations,
            checkedIngredientIDs: checkedIngredientIDs,
            priceBasisPoints: preferences.supermarket.priceBasisPoints
        )
    }

    var shoppingProgress: ShoppingProgress {
        Planning.shoppingProgress(items: shoppingItems)
    }

    var rankedDiscoverRecipes: [RankedRecipe] {
        let deterministic = Personalization.rankedDiscoverRecipes(
            recipes: recipes,
            plan: plan,
            preferences: preferences,
            savedRecipeIDs: Set(savedRecipeRecords.map(\.recipeID))
        )
        guard !backendRecommendationOrder.isEmpty else { return deterministic }
        let byID = Dictionary(uniqueKeysWithValues: deterministic.map { ($0.id, $0) })
        let ordered = backendRecommendationOrder.compactMap { id -> RankedRecipe? in
            guard let ranked = byID[id] else { return nil }
            return RankedRecipe(
                recipe: ranked.recipe,
                score: ranked.score,
                explanations: backendExplanations[id].map { [$0] } ?? ranked.explanations,
                cautions: ranked.cautions
            )
        }
        return ordered.count == deterministic.count ? ordered : deterministic
    }

    var discoverRecipes: [Recipe] {
        rankedDiscoverRecipes.map(\.recipe)
    }

    var scheduledPreferenceConflicts: [ScheduledPreferenceConflict] {
        Personalization.conflicts(in: plan, recipes: recipesForCalculations, preferences: preferences)
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
            recipes: recipesForCalculations,
            priceBasisPoints: preferences.supermarket.priceBasisPoints
        )
    }

    func estimatedCost(for recipe: Recipe, servings: Int? = nil) -> Money {
        recipe.estimatedCost(for: servings ?? recipe.servings)
            .scaled(byBasisPoints: preferences.supermarket.priceBasisPoints)
    }

    func eligibility(for recipe: Recipe) -> RecipeEligibility {
        Personalization.eligibility(of: recipe, preferences: preferences)
    }

    func ranking(for recipeID: Recipe.ID) -> RankedRecipe? {
        rankedDiscoverRecipes.first(where: { $0.id == recipeID })
    }

    func conflict(for day: Weekday) -> ScheduledPreferenceConflict? {
        scheduledPreferenceConflicts.first(where: { $0.day == day })
    }

    func eligibleRecipesForReplacement(on day: Weekday) -> [Recipe] {
        let currentID = plan.slots.first(where: { $0.day == day })?.recipeID
        let scheduledElsewhere = Set(plan.slots.filter { $0.day != day }.compactMap(\.recipeID))
        return recipesForCalculations.filter { recipe in
            recipe.id != currentID
                && !scheduledElsewhere.contains(recipe.id)
                && eligibility(for: recipe).isEligible
        }
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
        if backendClient != nil {
            await connectBackend()
            return
        }
        do {
            recipes = try await recipeRepository.load(mode: .loading)
            recipeMode = recipes.isEmpty ? .empty : .ready
        } catch {
            recipeMode = .error
        }
    }

    func retryRecipes() async {
        if backendClient != nil {
            await connectBackend()
            return
        }
        recipeMode = .loading
        do {
            recipes = try await recipeRepository.load(mode: .ready)
            recipeMode = recipes.isEmpty ? .empty : .ready
        } catch {
            recipeMode = .error
        }
    }

    func connectBackendIfNeeded() async {
        guard backendClient != nil else { return }
        guard case .loading = backendState else { return }
        await connectBackend()
    }

    func connectBackend() async {
        guard let backendClient, !isBackendConnecting else { return }
        isBackendConnecting = true
        defer { isBackendConnecting = false }
        backendState = .loading
        recipeMode = .loading
        backendRecommendationOrder = []
        backendExplanations = [:]
        do {
            let response = try await backendClient.loadCatalogue()
            let catalogue = try response.validatedDomainCatalogue()
            try validateCatalogueCompatibility(catalogue)
            recipes = catalogue.recipes
            backendCatalogueVersion = catalogue.version
            recipeMode = .ready
            await backendCache.save(response)
            do {
                try await refreshBackendRecommendations()
            } catch {
                backendRecommendationOrder = []
                backendExplanations = [:]
                backendState = .fallback(message: "Backend ranking failed validation. The validated catalogue remains available with on-device ranking.")
            }
        } catch {
            if let cachedResponse = await backendCache.loadCompatible(),
               let catalogue = try? cachedResponse.validatedDomainCatalogue(),
               (try? validateCatalogueCompatibility(catalogue)) != nil {
                recipes = catalogue.recipes
                backendCatalogueVersion = catalogue.version
                recipeMode = .ready
                backendState = .cached(message: "The backend is unavailable. Using the last validated catalogue with on-device ranking.")
            } else {
                recipes = WeeknightFixture.recipes
                backendCatalogueVersion = nil
                recipeMode = .ready
                let invalid = error as? BackendClientError
                if invalid == .invalidResponse || invalid == .incompatibleCatalogue {
                    backendState = .fallback(message: "Backend data failed validation. Weeknight kept the approved on-device catalogue and rules.")
                } else {
                    backendState = .unavailable(message: "The backend could not be reached. Everything remains usable on device.")
                }
            }
        }
    }

    private func refreshBackendRecommendations() async throws {
        guard let backendClient, let backendCatalogueVersion else { return }
        let deterministic = Personalization.rankedDiscoverRecipes(
            recipes: recipes,
            plan: plan,
            preferences: preferences,
            savedRecipeIDs: Set(savedRecipeRecords.map(\.recipeID))
        )
        let eligibleIDs = deterministic.map(\.id)
        guard !eligibleIDs.isEmpty else {
            backendState = .connected(provider: "stub")
            return
        }
        let request = BackendRecommendationRequest(
            schemaVersion: 1,
            catalogueVersion: backendCatalogueVersion,
            eligibleRecipeIDs: eligibleIDs,
            scheduledRecipeIDs: plan.slots.compactMap(\.recipeID),
            remainingBudgetMinorUnits: remainingBudget.minorUnits,
            currency: plan.budget.currencyCode,
            householdSize: preferences.householdSize,
            preferences: backendSoftPreferences
        )
        let response = try await backendClient.recommendations(request)
        guard response.schemaVersion == 1,
              response.catalogueVersion == backendCatalogueVersion,
              ["stub", "openai", "fallback"].contains(response.status),
              Set(response.recommendations.map(\.recipeID)).count == response.recommendations.count,
              Set(response.recommendations.map(\.recipeID)) == Set(eligibleIDs),
              response.recommendations.allSatisfy({ !$0.explanation.isEmpty && $0.explanation.count <= 180 })
        else { throw BackendClientError.invalidResponse }
        backendRecommendationOrder = response.recommendations.map(\.recipeID)
        backendExplanations = Dictionary(uniqueKeysWithValues: response.recommendations.map { ($0.recipeID, $0.explanation) })
        if response.status == "fallback" {
            backendState = .fallback(message: "AI personalization was unavailable, so the backend returned its deterministic safe ranking.")
        } else {
            backendState = .connected(provider: response.status)
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
        guard eligibility(for: recipe).isEligible else { throw PreferenceCommitError.recipeIneligible }
        let reconciledChecks = validCheckedIDs(for: updated)
        try await planRepository.savePlan(updated)
        try persistence.save(snapshot(plan: updated, checkedIngredientIDs: reconciledChecks))
        plan = updated
        checkedIngredientIDs = reconciledChecks
        planMutationCount += 1
        confirmationMessage = "\(recipe.title) added to \(day.rawValue). The week and shopping list are updated."
        await refreshBackendRecommendationsIfReachable()
    }

    func updateServings(for day: Weekday, to servings: Int) async throws {
        guard !isAssigning else { return }
        isAssigning = true
        defer { isAssigning = false }

        let updated = Planning.updatingServings(to: servings, on: day, in: plan)
        guard updated != plan else { return }
        let reconciledChecks = validCheckedIDs(for: updated)
        try await planRepository.savePlan(updated)
        try persistence.save(snapshot(plan: updated, checkedIngredientIDs: reconciledChecks))
        plan = updated
        checkedIngredientIDs = reconciledChecks
        planMutationCount += 1
        confirmationMessage = "Servings updated. The plan, budget, and shopping list now agree."
        await refreshBackendRecommendationsIfReachable()
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
        if backendClient != nil {
            Task { await self.refreshBackendRecommendationsIfReachable() }
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

    func previewPreferenceUpdate(_ draft: UserPreferences) -> PreferenceUpdatePreview {
        Personalization.previewPreferenceUpdate(
            from: preferences,
            to: draft,
            plan: plan,
            recipes: recipesForCalculations,
            checkedIngredientIDs: checkedIngredientIDs
        )
    }

    func commitPreferences(_ draft: UserPreferences) async throws {
        guard !isSavingPreferences else { return }
        isSavingPreferences = true
        defer { isSavingPreferences = false }

        let preview = previewPreferenceUpdate(draft)
        let didChangePlan = preview.projectedPlan != plan
        let reconciledChecks = validCheckedIDs(
            for: preview.projectedPlan,
            preferences: preview.draft
        )
        if preview.projectedPlan != plan {
            try await planRepository.savePlan(preview.projectedPlan)
        }
        try persistence.save(
            snapshot(
                plan: preview.projectedPlan,
                checkedIngredientIDs: reconciledChecks,
                preferences: preview.draft
            )
        )
        plan = preview.projectedPlan
        preferences = preview.draft
        checkedIngredientIDs = reconciledChecks
        persistenceErrorMessage = nil
        if didChangePlan { planMutationCount += 1 }
        confirmationMessage = "Preferences saved. Your plan and shopping list now agree."
        await refreshBackendRecommendationsIfReachable()
    }

    func clearMeal(on day: Weekday) async throws {
        guard !isAssigning else { return }
        let updated = Planning.clearing(day: day, in: plan)
        guard updated != plan else { return }
        isAssigning = true
        defer { isAssigning = false }
        let reconciledChecks = validCheckedIDs(for: updated)
        try await planRepository.savePlan(updated)
        try persistence.save(snapshot(plan: updated, checkedIngredientIDs: reconciledChecks))
        plan = updated
        checkedIngredientIDs = reconciledChecks
        planMutationCount += 1
        confirmationMessage = "\(day.rawValue)’s meal was cleared. The shopping list is updated."
        await refreshBackendRecommendationsIfReachable()
    }

    func fillOpenDays() async throws -> AutofillOutcome {
        guard !isAutofilling else {
            return .unable(message: "Weeknight is already filling your open days.", suggestions: [])
        }
        isAutofilling = true
        defer { isAutofilling = false }

        if backendClient != nil, backendCatalogueVersion != nil {
            do {
                if let backendOutcome = try await performBackendAutofill() {
                    return backendOutcome
                }
            } catch let error as BackendClientError {
                backendState = .fallback(message: "Backend week generation failed validation (\(error.localizedDescription)). The on-device engine completed the request instead.")
            }
        }

        let outcome = Personalization.autofill(
            plan: plan,
            recipes: recipesForCalculations,
            preferences: preferences,
            savedRecipeIDs: Set(savedRecipeRecords.map(\.recipeID))
        )
        guard case .success(let updated, let assignments, let projectedSpend) = outcome else { return outcome }
        let reconciledChecks = validCheckedIDs(for: updated)
        try await planRepository.savePlan(updated)
        try persistence.save(snapshot(plan: updated, checkedIngredientIDs: reconciledChecks))
        plan = updated
        checkedIngredientIDs = reconciledChecks
        planMutationCount += 1
        confirmationMessage = backendClient == nil
            ? "Open days filled. The plan and shopping list are ready."
            : "Open days filled safely on device. The plan and shopping list are ready."
        return .success(plan: updated, assignments: assignments, projectedSpend: projectedSpend)
    }

    private func performBackendAutofill() async throws -> AutofillOutcome? {
        guard let backendClient, let backendCatalogueVersion else { return nil }
        let openSlots = Planning.openSlots(in: plan)
        guard !openSlots.isEmpty else { return nil }
        let scheduledIDs = Set(plan.slots.compactMap(\.recipeID))
        let eligible = recipesForCalculations.filter { recipe in
            !scheduledIDs.contains(recipe.id)
                && eligibility(for: recipe).isEligible
                && recipe.activeMinutes <= preferences.maximumCookingMinutes
        }
        guard !eligible.isEmpty else { return nil }
        let request = BackendWeekPlanRequest(
            schemaVersion: 1,
            catalogueVersion: backendCatalogueVersion,
            eligibleRecipeIDs: eligible.map(\.id),
            scheduledRecipeIDs: Array(scheduledIDs).sorted(),
            openDays: openSlots.map(\.day.rawValue),
            currentSpendMinorUnits: weeklySpend.minorUnits,
            budgetMinorUnits: plan.budget.minorUnits,
            currency: plan.budget.currencyCode,
            householdSize: preferences.householdSize,
            preferences: backendSoftPreferences
        )
        let response = try await backendClient.generateWeek(request)
        guard response.schemaVersion == 1,
              response.catalogueVersion == backendCatalogueVersion,
              ["stub", "openai", "fallback"].contains(response.status),
              ["success", "unable"].contains(response.outcome)
        else { throw BackendClientError.invalidResponse }
        guard response.outcome == "success" else {
            backendState = .fallback(message: "The backend could not produce a complete safe week, so Weeknight is using its on-device engine.")
            return nil
        }

        let expectedDays = Set(openSlots.map(\.day))
        let candidateLookup = Dictionary(uniqueKeysWithValues: eligible.map { ($0.id, $0) })
        let days = response.assignments.compactMap { Weekday(rawValue: $0.day) }
        let selectedIDs = response.assignments.map(\.recipeID)
        guard days.count == response.assignments.count,
              response.assignments.count == openSlots.count,
              Set(days) == expectedDays,
              Set(selectedIDs).count == selectedIDs.count,
              selectedIDs.allSatisfy({ candidateLookup[$0] != nil }),
              response.assignments.allSatisfy({ !$0.explanation.isEmpty && $0.explanation.count <= 180 })
        else { throw BackendClientError.invalidResponse }

        var updated = plan
        var assignments: [ShoppingContribution] = []
        for assignment in response.assignments {
            guard let day = Weekday(rawValue: assignment.day),
                  let recipe = candidateLookup[assignment.recipeID],
                  eligibility(for: recipe).isEligible,
                  recipe.activeMinutes <= preferences.maximumCookingMinutes
            else { throw BackendClientError.invalidResponse }
            updated = Planning.assigning(
                recipeID: recipe.id,
                servings: preferences.householdSize,
                to: day,
                in: updated
            )
            assignments.append(
                ShoppingContribution(
                    day: day,
                    recipeID: recipe.id,
                    recipeTitle: recipe.title,
                    servings: preferences.householdSize
                )
            )
        }
        let projectedSpend = Planning.weeklySpend(
            plan: updated,
            recipes: recipesForCalculations,
            priceBasisPoints: preferences.supermarket.priceBasisPoints
        )
        guard projectedSpend <= updated.budget else { throw BackendClientError.invalidResponse }

        let reconciledChecks = validCheckedIDs(for: updated)
        try await planRepository.savePlan(updated)
        try persistence.save(snapshot(plan: updated, checkedIngredientIDs: reconciledChecks))
        plan = updated
        checkedIngredientIDs = reconciledChecks
        planMutationCount += 1
        if response.status == "fallback" {
            backendState = .fallback(message: "AI was unavailable. The backend’s deterministic engine generated this validated week.")
        } else {
            backendState = .connected(provider: response.status)
        }
        confirmationMessage = "Backend week applied after on-device safety and budget checks. Shopping is updated."
        return .success(plan: updated, assignments: assignments, projectedSpend: projectedSpend)
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
        preferences = canonical.preferences
        recipeMode = backendClient == nil ? .ready : .loading
        shoppingMode = .ready
        savedMode = .ready
        selectedTab = .plan
        confirmationMessage = "The canonical demo week has been reset."
        planMutationCount = 0
        if backendClient != nil {
            backendCatalogueVersion = nil
            backendRecommendationOrder = []
            backendExplanations = [:]
            backendState = .loading
            Task { await self.connectBackend() }
        }
    }

    private var backendSoftPreferences: BackendSoftPreferences {
        BackendSoftPreferences(
            maximumCookingMinutes: preferences.maximumCookingMinutes,
            dislikedIngredientIDs: preferences.dislikedIngredientIDs.sorted(),
            preferredProteins: PreferredProtein.allCases
                .filter(preferences.preferredProteins.contains)
                .map(\.rawValue),
            preferredMealStyles: MealStyle.allCases
                .filter(preferences.preferredMealStyles.contains)
                .map(\.rawValue),
            savedRecipeIDs: savedRecipeRecords.map(\.recipeID).sorted()
        )
    }

    private func validateCatalogueCompatibility(_ catalogue: BackendCatalogue) throws {
        let remoteIDs = Set(catalogue.recipes.map(\.id))
        let approvedIDs = Set(WeeknightFixture.recipes.map(\.id))
        let scheduledIDs = Set(plan.slots.compactMap(\.recipeID))
        guard approvedIDs.isSubset(of: remoteIDs), scheduledIDs.isSubset(of: remoteIDs),
              catalogue.recipes.allSatisfy({ $0.estimatedCost.currencyCode == plan.budget.currencyCode })
        else { throw BackendClientError.incompatibleCatalogue }
    }

    private func refreshBackendRecommendationsIfReachable() async {
        guard backendClient != nil, backendCatalogueVersion != nil else { return }
        try? await refreshBackendRecommendations()
    }

    private func validCheckedIDs(
        for plan: WeekPlan,
        preferences preferencesOverride: UserPreferences? = nil
    ) -> Set<Ingredient.ID> {
        let activePreferences = preferencesOverride ?? preferences
        let validIDs = Set(
            Planning.shoppingItems(
                plan: plan,
                recipes: recipesForCalculations,
                checkedIngredientIDs: [],
                priceBasisPoints: activePreferences.supermarket.priceBasisPoints
            ).map(\.id)
        )
        return checkedIngredientIDs.intersection(validIDs)
    }

    private func snapshot(
        plan planOverride: WeekPlan? = nil,
        checkedIngredientIDs checkedOverride: Set<Ingredient.ID>? = nil,
        preferences preferencesOverride: UserPreferences? = nil
    ) -> AppSnapshot {
        AppSnapshot(
            plan: planOverride ?? plan,
            checkedIngredientIDs: checkedOverride ?? checkedIngredientIDs,
            savedRecipeRecords: savedRecipeRecords,
            recipeNotes: recipeNotes,
            preferences: preferencesOverride ?? preferences
        )
    }

    private static func mode(after flag: String, in arguments: [String]) -> RepositoryMode? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return RepositoryMode(rawValue: arguments[index + 1])
    }
}

enum PreferenceCommitError: LocalizedError {
    case recipeIneligible

    var errorDescription: String? {
        "This recipe conflicts with a hard preference. Review the warning before adding it."
    }
}
