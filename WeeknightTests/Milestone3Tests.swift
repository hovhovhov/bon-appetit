import SwiftData
import XCTest
@testable import Weeknight

final class Milestone3DomainTests: XCTestCase {
    func testPreferencePresentationUsesIntegerMoneyAndCountsChangedFields() {
        var draft = UserPreferences.canonical
        draft.weeklyBudget = Money(minorUnits: 9_500)
        draft.householdSize = 4
        draft.preferredProteins = [.chicken]

        XCTAssertEqual(
            PreferencePresentation.approximateBudgetPerDinner(draft),
            Money(minorUnits: 1_900)
        )
        XCTAssertEqual(
            PreferencePresentation.changedFieldCount(from: .canonical, to: draft),
            3
        )
    }

    func testExactBudgetParsingNeverUsesFloatingPointMoney() {
        XCTAssertEqual(PreferencePresentation.parsedBudgetMinorUnits("$95"), 9_500)
        XCTAssertEqual(PreferencePresentation.parsedBudgetMinorUnits("95.5"), 9_550)
        XCTAssertEqual(PreferencePresentation.parsedBudgetMinorUnits("1,200.09"), 120_009)
        XCTAssertNil(PreferencePresentation.parsedBudgetMinorUnits("95.123"))
        XCTAssertNil(PreferencePresentation.parsedBudgetMinorUnits("not money"))
    }

    func testEverySupportedAllergenProducesAFirstClassHardReason() throws {
        for allergen in MedicalAllergen.allCases {
            let recipe = try XCTUnwrap(
                WeeknightFixture.recipes.first(where: { $0.declaredAllergens.contains(allergen) }),
                "Fixture catalogue must cover \(allergen.rawValue)"
            )
            var preferences = UserPreferences.canonical
            preferences.medicalAllergens = [allergen]

            let result = Personalization.eligibility(of: recipe, preferences: preferences)

            XCTAssertFalse(result.isEligible, "\(allergen.rawValue) must exclude a declared match")
            XCTAssertEqual(result.hardReasons.first?.kind, .medicalAllergen)
            XCTAssertTrue(result.hardReasons.first?.message.contains(allergen.rawValue.lowercased()) == true)
        }
    }

    func testEverySupportedDietaryRestrictionExcludesAnIncompatibleRecipe() throws {
        for restriction in DietaryRestriction.allCases {
            let recipe = try XCTUnwrap(
                WeeknightFixture.recipes.first(where: { !$0.dietaryCompatibility.contains(restriction) })
            )
            var preferences = UserPreferences.canonical
            preferences.dietaryRestrictions = [restriction]

            let result = Personalization.eligibility(of: recipe, preferences: preferences)

            XCTAssertFalse(result.isEligible)
            XCTAssertEqual(result.hardReasons.first?.kind, .dietaryRestriction)
        }
    }

    func testUnavailableRequiredApplianceIsHardExclusion() throws {
        let steak = try recipe("steak")
        var preferences = UserPreferences.canonical
        preferences.availableAppliances = [.stovetop]

        let result = Personalization.eligibility(of: steak, preferences: preferences)

        XCTAssertFalse(result.isEligible)
        XCTAssertEqual(result.hardReasons.map(\.kind), [.unavailableAppliance])
        XCTAssertTrue(result.hardReasons[0].message.contains("oven"))

        preferences.availableAppliances = []
        preferences.normalize()
        XCTAssertTrue(preferences.availableAppliances.isEmpty, "Normalization must not silently add safety-relevant equipment")
        XCTAssertFalse(Personalization.eligibility(of: try recipe("carbonara"), preferences: preferences).isEligible)
    }

    func testMedicalAndDietaryRulesAreReportedBeforeEquipmentAndRanking() throws {
        let carbonara = try recipe("carbonara")
        var preferences = UserPreferences.canonical
        preferences.medicalAllergens = [.milk]
        preferences.dietaryRestrictions = [.vegan]
        preferences.availableAppliances = [.oven]

        let result = Personalization.eligibility(of: carbonara, preferences: preferences)

        XCTAssertEqual(result.hardReasons.map(\.kind), [.medicalAllergen, .dietaryRestriction, .unavailableAppliance])
        let ranked = Personalization.rankedDiscoverRecipes(
            recipes: WeeknightFixture.recipes,
            plan: WeeknightFixture.initialPlan,
            preferences: preferences,
            savedRecipeIDs: []
        )
        XCTAssertFalse(ranked.contains(where: { $0.id == carbonara.id }))
    }

    func testCookingTimeIsAFlagInDiscoverAndAHardLimitForAutofill() throws {
        var preferences = UserPreferences.canonical
        preferences.maximumCookingMinutes = 15

        let discover = Personalization.rankedDiscoverRecipes(
            recipes: WeeknightFixture.recipes,
            plan: WeeknightFixture.initialPlan,
            preferences: preferences,
            savedRecipeIDs: []
        )
        let carbonara = try XCTUnwrap(discover.first(where: { $0.id == "carbonara" }))
        XCTAssertTrue(carbonara.cautions.contains(where: { $0.contains("over your 15-minute") }))

        let outcome = Personalization.autofill(
            plan: WeeknightFixture.initialPlan,
            recipes: WeeknightFixture.recipes,
            preferences: preferences,
            savedRecipeIDs: []
        )
        guard case .unable(let message, _) = outcome else { return XCTFail("Autofill must not weaken time") }
        XCTAssertTrue(message.contains("cooking-time"))
    }

    func testDislikesAreSoftAndNeverDescribedAsMedical() throws {
        var preferences = UserPreferences.canonical
        preferences.dislikedIngredientIDs = ["spaghetti"]

        let ranked = Personalization.rankedDiscoverRecipes(
            recipes: WeeknightFixture.recipes,
            plan: WeeknightFixture.initialPlan,
            preferences: preferences,
            savedRecipeIDs: []
        )
        let carbonara = try XCTUnwrap(ranked.first(where: { $0.id == "carbonara" }))
        let baselineCarbonara = try XCTUnwrap(
            Personalization.rankedDiscoverRecipes(
                recipes: WeeknightFixture.recipes,
                plan: WeeknightFixture.initialPlan,
                preferences: .canonical,
                savedRecipeIDs: []
            ).first(where: { $0.id == "carbonara" })
        )

        XCTAssertLessThan(carbonara.score, baselineCarbonara.score)
        XCTAssertTrue(carbonara.cautions.contains(where: { $0.contains("disliked") }))
        XCTAssertFalse(carbonara.cautions.contains(where: { $0.localizedCaseInsensitiveContains("allergen") }))
        XCTAssertTrue(Personalization.eligibility(of: carbonara.recipe, preferences: preferences).isEligible)
    }

    func testPreferredProteinStyleAndSavedAreTruthfulRankingSignals() throws {
        var preferences = UserPreferences.canonical
        preferences.preferredProteins = [.pork]
        preferences.preferredMealStyles = [.speedy]

        let ranked = Personalization.rankedDiscoverRecipes(
            recipes: WeeknightFixture.recipes,
            plan: WeeknightFixture.initialPlan,
            preferences: preferences,
            savedRecipeIDs: ["carbonara"]
        )
        let first = try XCTUnwrap(ranked.first)

        XCTAssertEqual(first.id, "carbonara")
        XCTAssertTrue(first.explanations.contains(where: { $0.contains("pork preference") }))
        XCTAssertTrue(first.explanations.contains(where: { $0.contains("speedy meal style") }))
        XCTAssertTrue(first.explanations.contains("You saved this recipe."))
    }

    func testRankingIsDeterministicAndExcludesScheduledRecipes() {
        let arguments = (
            recipes: WeeknightFixture.recipes,
            plan: WeeknightFixture.initialPlan,
            preferences: UserPreferences.canonical,
            savedRecipeIDs: Set<Recipe.ID>()
        )
        let first = Personalization.rankedDiscoverRecipes(
            recipes: arguments.recipes,
            plan: arguments.plan,
            preferences: arguments.preferences,
            savedRecipeIDs: arguments.savedRecipeIDs
        )
        let second = Personalization.rankedDiscoverRecipes(
            recipes: arguments.recipes,
            plan: arguments.plan,
            preferences: arguments.preferences,
            savedRecipeIDs: arguments.savedRecipeIDs
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.first?.id, "carbonara")
        XCTAssertTrue(Set(first.map(\.id)).isDisjoint(with: ["honeysoy", "chilli", "stirfry"]))
    }

    func testBudgetFitChangesScoreButNeverMedicalEligibility() throws {
        var plan = WeeknightFixture.initialPlan
        plan.budget = Planning.weeklySpend(plan: plan, recipes: WeeknightFixture.recipes) + Money(minorUnits: 900)

        let ranked = Personalization.rankedDiscoverRecipes(
            recipes: WeeknightFixture.recipes,
            plan: plan,
            preferences: .canonical,
            savedRecipeIDs: []
        )
        let carbonara = try XCTUnwrap(ranked.first(where: { $0.id == "carbonara" }))
        let steak = try XCTUnwrap(ranked.first(where: { $0.id == "steak" }))

        XCTAssertGreaterThan(carbonara.score, steak.score)
        XCTAssertTrue(carbonara.explanations.contains(where: { $0.contains("left in this week’s budget") }))
        XCTAssertTrue(steak.cautions.contains(where: { $0.contains("over budget") }))
        XCTAssertTrue(Personalization.eligibility(of: steak.recipe, preferences: .canonical).isEligible)
    }

    func testRankingRewardsProteinVarietyAgainstTheCurrentWeek() throws {
        var plan = WeeknightFixture.initialPlan
        plan.slots = [
            MealSlot(day: .monday, recipeID: "honeysoy", servings: 1),
            MealSlot(day: .tuesday, recipeID: nil, servings: 1),
        ]

        let ranked = Personalization.rankedDiscoverRecipes(
            recipes: WeeknightFixture.recipes,
            plan: plan,
            preferences: .canonical,
            savedRecipeIDs: []
        )
        let carbonara = try XCTUnwrap(ranked.first(where: { $0.id == "carbonara" }))
        let curry = try XCTUnwrap(ranked.first(where: { $0.id == "curry" }))

        XCTAssertGreaterThan(carbonara.score, curry.score)
        XCTAssertTrue(carbonara.explanations.contains("Adds a different main protein to this week."))
    }

    func testReconciliationNeverSilentlyDeletesAConflictingScheduledMeal() throws {
        var draft = UserPreferences.canonical
        draft.medicalAllergens = [.soy]

        let preview = Personalization.previewPreferenceUpdate(
            from: .canonical,
            to: draft,
            plan: WeeknightFixture.initialPlan,
            recipes: WeeknightFixture.recipes,
            checkedIngredientIDs: WeeknightFixture.initialCheckedIngredientIDs
        )

        XCTAssertTrue(preview.requiresConfirmation)
        XCTAssertEqual(preview.projectedPlan.slots.first(where: { $0.day == .monday })?.recipeID, "honeysoy")
        XCTAssertEqual(preview.projectedPlan.slots.first(where: { $0.day == .wednesday })?.recipeID, "stirfry")
        XCTAssertEqual(preview.conflicts.map(\.day), [.monday, .wednesday])
        XCTAssertTrue(preview.removedFilledSlots.isEmpty)
    }

    func testHouseholdPreviewScalesScheduledServingsBudgetAndShoppingTogether() {
        var draft = UserPreferences.canonical
        draft.householdSize = 2

        let preview = Personalization.previewPreferenceUpdate(
            from: .canonical,
            to: draft,
            plan: WeeknightFixture.initialPlan,
            recipes: WeeknightFixture.recipes,
            checkedIngredientIDs: WeeknightFixture.initialCheckedIngredientIDs
        )

        XCTAssertEqual(preview.servingChangeCount, 3)
        XCTAssertEqual(preview.projectedPlan.slots.filter { $0.recipeID != nil }.map(\.servings), [2, 2, 2])
        XCTAssertEqual(preview.currentSpend, WeeknightFixture.money(3_540))
        XCTAssertEqual(preview.projectedSpend, WeeknightFixture.money(7_080))
        XCTAssertEqual(preview.projectedShoppingItemCount, 25)
        XCTAssertEqual(preview.shoppingChangeCount, 25)
    }

    func testCookingDayPreviewNamesFilledRemovalAndAddedSlots() {
        var draft = UserPreferences.canonical
        draft.cookingDays = [.tuesday, .wednesday, .thursday, .friday, .saturday]

        let preview = Personalization.previewPreferenceUpdate(
            from: .canonical,
            to: draft,
            plan: WeeknightFixture.initialPlan,
            recipes: WeeknightFixture.recipes,
            checkedIngredientIDs: []
        )

        XCTAssertEqual(preview.removedFilledSlots.map(\.day), [.monday])
        XCTAssertEqual(preview.removedFilledSlots.first?.recipeTitle, "Honey Soy Chicken & Broccoli")
        XCTAssertEqual(preview.addedDays, [.saturday])
        XCTAssertEqual(preview.removedDays, [.monday])
        XCTAssertNil(preview.projectedPlan.slots.first(where: { $0.day == .saturday })?.recipeID)
    }

    func testNoResultsDoesNotWeakenHardDietaryConstraint() {
        var preferences = UserPreferences.canonical
        preferences.dietaryRestrictions = [.vegan]

        let ranked = Personalization.rankedDiscoverRecipes(
            recipes: WeeknightFixture.recipes,
            plan: WeeknightFixture.initialPlan,
            preferences: preferences,
            savedRecipeIDs: []
        )
        XCTAssertTrue(ranked.isEmpty, "The only vegan fixture is already scheduled")

        let outcome = Personalization.autofill(
            plan: WeeknightFixture.initialPlan,
            recipes: WeeknightFixture.recipes,
            preferences: preferences,
            savedRecipeIDs: []
        )
        guard case .unable = outcome else { return XCTFail("Autofill must fail without weakening vegan") }
    }

    func testAutofillFillsOpenConfiguredDaysWithoutDuplicatesAndInsideBudget() {
        let outcome = Personalization.autofill(
            plan: WeeknightFixture.initialPlan,
            recipes: WeeknightFixture.recipes,
            preferences: .canonical,
            savedRecipeIDs: []
        )
        guard case .success(let plan, let assignments, let spend) = outcome else { return XCTFail("Expected a valid combination") }

        XCTAssertEqual(assignments.map(\.day), [.thursday, .friday])
        XCTAssertEqual(Set(assignments.map(\.recipeID)).count, assignments.count)
        XCTAssertTrue(assignments.allSatisfy { assignment in
            WeeknightFixture.recipes.first(where: { $0.id == assignment.recipeID })!.activeMinutes <= UserPreferences.canonical.maximumCookingMinutes
        })
        XCTAssertEqual(Planning.openSlots(in: plan).count, 0)
        XCTAssertLessThanOrEqual(spend, plan.budget)
        XCTAssertEqual(plan.slots.prefix(3).compactMap(\.recipeID), ["honeysoy", "chilli", "stirfry"])
    }

    func testAutofillBudgetFailureLeavesInputPlanUnchanged() {
        var preferences = UserPreferences.canonical
        preferences.weeklyBudget = Money(minorUnits: 4_000)
        var plan = WeeknightFixture.initialPlan
        plan.budget = preferences.weeklyBudget
        let original = plan

        let outcome = Personalization.autofill(
            plan: plan,
            recipes: WeeknightFixture.recipes,
            preferences: preferences,
            savedRecipeIDs: []
        )

        guard case .unable(let message, let suggestions) = outcome else { return XCTFail("No two-recipe combination fits $4") }
        XCTAssertTrue(message.contains("budget"))
        XCTAssertTrue(suggestions.contains("Increase weekly budget"))
        XCTAssertEqual(plan, original)
    }

    func testDeterministicStoreQuoteSetsNeverUseCurrencyConversion() {
        let trader = Planning.weeklySpend(plan: WeeknightFixture.initialPlan, recipes: WeeknightFixture.recipes, priceBasisPoints: Supermarket.traderJoes.priceBasisPoints)
        let aldi = Planning.weeklySpend(plan: WeeknightFixture.initialPlan, recipes: WeeknightFixture.recipes, priceBasisPoints: Supermarket.aldi.priceBasisPoints)
        let safeway = Planning.weeklySpend(plan: WeeknightFixture.initialPlan, recipes: WeeknightFixture.recipes, priceBasisPoints: Supermarket.safeway.priceBasisPoints)

        XCTAssertLessThan(aldi, trader)
        XCTAssertLessThan(trader, safeway)
        XCTAssertEqual(Set([trader.currencyCode, aldi.currencyCode, safeway.currencyCode]), ["USD"])
        XCTAssertFalse(MarketOption.canada.isSupported)
        XCTAssertFalse(MarketOption.unitedKingdom.isSupported)
    }

    private func recipe(_ id: Recipe.ID) throws -> Recipe {
        try XCTUnwrap(WeeknightFixture.recipes.first(where: { $0.id == id }))
    }
}

@MainActor
final class Milestone3StorePersistenceTests: XCTestCase {
    func testPreferencePlanAndReconciliationPersistAcrossRelaunch() async throws {
        let persistence = InMemoryAppStatePersistence()
        let first = AppStore(arguments: [], persistence: persistence)
        var draft = first.preferences
        draft.householdSize = 2
        draft.medicalAllergens = [.soy]

        try await first.commitPreferences(draft)
        let relaunched = AppStore(arguments: [], persistence: persistence)

        XCTAssertEqual(relaunched.preferences.householdSize, 2)
        XCTAssertEqual(relaunched.preferences.medicalAllergens, [.soy])
        XCTAssertEqual(relaunched.plan.slots.first(where: { $0.day == .monday })?.servings, 2)
        XCTAssertEqual(relaunched.conflict(for: .monday)?.recipe.id, "honeysoy")
        XCTAssertEqual(relaunched.weeklySpend, WeeknightFixture.money(7_080))
    }

    func testPreferenceAndPlanCommitRemainAtomicWhenRepositoryFails() async {
        let persistence = InMemoryAppStatePersistence()
        let repository = RejectingPlanRepository()
        let store = AppStore(arguments: [], planRepository: repository, persistence: persistence)
        let originalPreferences = store.preferences
        let originalPlan = store.plan
        var draft = originalPreferences
        draft.householdSize = 2

        do {
            try await store.commitPreferences(draft)
            XCTFail("Expected repository failure")
        } catch {
            XCTAssertEqual(store.preferences, originalPreferences)
            XCTAssertEqual(store.plan, originalPlan)
            XCTAssertEqual(try? persistence.load()?.preferences, originalPreferences)
            XCTAssertEqual(try? persistence.load()?.plan, originalPlan)
        }
    }

    func testAutofillPersistsAsOneCompletedPlanMutation() async throws {
        let persistence = InMemoryAppStatePersistence()
        let store = AppStore(arguments: [], persistence: persistence)

        let outcome = try await store.fillOpenDays()
        guard case .success = outcome else { return XCTFail("Expected success") }
        XCTAssertEqual(store.planMutationCount, 1)
        XCTAssertEqual(store.filledCount, 5)

        let relaunched = AppStore(arguments: [], persistence: persistence)
        XCTAssertEqual(relaunched.plan, store.plan)
        XCTAssertEqual(relaunched.shoppingItems, store.shoppingItems)
    }

    func testFixtureResetRestoresCanonicalPreferencesAndOneRecord() async throws {
        let persistence = try SwiftDataAppStatePersistence(inMemory: true)
        let store = AppStore(arguments: [], persistence: persistence)
        var draft = store.preferences
        draft.supermarket = .safeway
        draft.preferredProteins = [.pork]
        try await store.commitPreferences(draft)

        store.resetFixture()
        store.resetFixture()

        XCTAssertEqual(store.preferences, .canonical)
        XCTAssertEqual(store.plan, WeeknightFixture.initialPlan)
        XCTAssertEqual(try persistence.recordCount(), 1)
    }

    func testSchemaOnePayloadMigratesToSchemaTwoWithoutDuplicatingRecord() throws {
        struct LegacySnapshot: Codable {
            let schemaVersion: Int
            let plan: WeekPlan
            let checkedIngredientIDs: Set<Ingredient.ID>
            let savedRecipeRecords: [SavedRecipeRecord]
            let recipeNotes: [Recipe.ID: String]
        }

        let container = try ModelContainer(
            for: PersistentAppState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let legacy = LegacySnapshot(
            schemaVersion: 1,
            plan: WeeknightFixture.initialPlan,
            checkedIngredientIDs: WeeknightFixture.initialCheckedIngredientIDs,
            savedRecipeRecords: WeeknightFixture.initialSavedRecipeRecords,
            recipeNotes: ["carbonara": "Pepper"]
        )
        context.insert(PersistentAppState(schemaVersion: 1, payload: try JSONEncoder().encode(legacy)))
        try context.save()
        let persistence = SwiftDataAppStatePersistence(container: container)

        let migrated = try XCTUnwrap(persistence.load())

        XCTAssertEqual(migrated.schemaVersion, AppSnapshot.currentSchemaVersion)
        XCTAssertEqual(migrated.preferences, .canonical)
        XCTAssertEqual(migrated.recipeNotes["carbonara"], "Pepper")
        XCTAssertEqual(try persistence.recordCount(), 1)
    }
}

private actor RejectingPlanRepository: PlanRepository {
    func loadPlan() -> WeekPlan { WeeknightFixture.initialPlan }
    func savePlan(_ plan: WeekPlan) async throws { throw AssignmentError.simulatedFailure }
}
