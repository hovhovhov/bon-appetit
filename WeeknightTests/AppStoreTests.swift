import XCTest
@testable import Weeknight

@MainActor
final class AppStoreTests: XCTestCase {
    func testDoubleActivationPerformsExactlyOneMutation() async throws {
        let repository = CountingPlanRepository()
        let store = AppStore(arguments: [], planRepository: repository)
        let carbonara = try XCTUnwrap(WeeknightFixture.recipes.first(where: { $0.id == "carbonara" }))

        async let first: Void = store.assign(recipe: carbonara, to: .thursday)
        async let second: Void = store.assign(recipe: carbonara, to: .thursday)
        _ = try await (first, second)

        let saveCount = await repository.saveCount
        XCTAssertEqual(store.planMutationCount, 1)
        XCTAssertEqual(saveCount, 1)
        XCTAssertEqual(store.plan.slots.first(where: { $0.day == .thursday })?.recipeID, "carbonara")
    }

    func testFailureRetainsPlanAndRetrySucceeds() async throws {
        let repository = CountingPlanRepository(failsOnce: true)
        let store = AppStore(arguments: [], planRepository: repository)
        let carbonara = try XCTUnwrap(WeeknightFixture.recipes.first(where: { $0.id == "carbonara" }))

        do {
            try await store.assign(recipe: carbonara, to: .thursday)
            XCTFail("Expected the first save to fail")
        } catch {
            XCTAssertEqual(store.planMutationCount, 0)
            XCTAssertNil(store.plan.slots.first(where: { $0.day == .thursday })?.recipeID)
        }

        try await store.assign(recipe: carbonara, to: .thursday)
        XCTAssertEqual(store.planMutationCount, 1)
        XCTAssertEqual(store.weeklySpend, WeeknightFixture.money(4_430))
    }

    func testSaveUnsaveTimestampOrderingAndSearchConsistency() throws {
        let persistence = InMemoryAppStatePersistence()
        let timestamp = Date(timeIntervalSince1970: 1_900_000_000)
        let store = AppStore(arguments: [], persistence: persistence, now: { timestamp })

        XCTAssertFalse(store.isSaved("carbonara"))
        store.toggleSaved("carbonara")
        XCTAssertTrue(store.isSaved("carbonara"))
        XCTAssertEqual(store.savedAt("carbonara"), timestamp)
        XCTAssertEqual(store.recentlySavedRecipes.first?.id, "carbonara")
        XCTAssertEqual(store.savedRecipes(matching: "spaghetti", filter: .all).map(\.id), ["carbonara"])
        XCTAssertEqual(store.savedRecipes(matching: "five ingredients", filter: .all).map(\.id), ["carbonara"])

        store.toggleSaved("carbonara")
        XCTAssertFalse(store.isSaved("carbonara"))
        XCTAssertTrue(store.savedRecipes(matching: "carbonara", filter: .all).isEmpty)
    }

    func testRecipeNotePersistsAcrossStoreRelaunch() {
        let persistence = InMemoryAppStatePersistence()
        let first = AppStore(arguments: [], persistence: persistence)
        first.saveNote("Use extra black pepper.", for: "carbonara")

        let relaunched = AppStore(arguments: [], persistence: persistence)
        XCTAssertEqual(relaunched.note(for: "carbonara"), "Use extra black pepper.")
    }

    func testPlanServingsAndShoppingChecksPersistAcrossStoreRelaunch() async throws {
        let persistence = InMemoryAppStatePersistence()
        let first = AppStore(arguments: [], persistence: persistence)
        let carbonara = try XCTUnwrap(WeeknightFixture.recipes.first(where: { $0.id == "carbonara" }))
        try await first.assign(recipe: carbonara, servings: 2, to: .thursday)
        let broccoli = try XCTUnwrap(first.shoppingItems.first(where: { $0.id == "broccoli" }))
        first.toggleShoppingItem(broccoli)

        let relaunched = AppStore(arguments: [], persistence: persistence)
        XCTAssertEqual(relaunched.plan.slots.first(where: { $0.day == .thursday })?.recipeID, "carbonara")
        XCTAssertEqual(relaunched.plan.slots.first(where: { $0.day == .thursday })?.servings, 2)
        XCTAssertEqual(relaunched.weeklySpend, WeeknightFixture.money(5_320))
        XCTAssertTrue(relaunched.checkedIngredientIDs.contains("broccoli"))
    }

    func testScheduledServingChangeIsDraftUntilCommittedAndPersistsAtomically() async throws {
        let persistence = InMemoryAppStatePersistence()
        let store = AppStore(arguments: [], persistence: persistence)
        let originalSpend = store.weeklySpend
        var draft = RecipeServingDraft(committed: 1)
        draft.increment()

        XCTAssertEqual(store.weeklySpend, originalSpend)
        draft.cancel()
        XCTAssertEqual(store.weeklySpend, originalSpend)

        try await store.updateServings(for: .monday, to: 2)
        XCTAssertEqual(store.plan.slots.first(where: { $0.day == .monday })?.servings, 2)
        XCTAssertEqual(store.weeklySpend, WeeknightFixture.money(4_700))
        XCTAssertEqual(store.shoppingItems.first(where: { $0.id == "broccoli" })?.quantityDisplay, "2 heads")

        let relaunched = AppStore(arguments: [], persistence: persistence)
        XCTAssertEqual(relaunched.weeklySpend, WeeknightFixture.money(4_700))
        XCTAssertEqual(relaunched.shoppingItems.first(where: { $0.id == "broccoli" })?.quantityDisplay, "2 heads")
    }

    func testFixtureSeedAndRepeatedResetNeverDuplicatePersistenceRecord() throws {
        let persistence = try SwiftDataAppStatePersistence(inMemory: true)
        let store = AppStore(arguments: [], persistence: persistence)
        XCTAssertEqual(try persistence.recordCount(), 1)

        store.resetFixture()
        store.resetFixture()
        XCTAssertEqual(try persistence.recordCount(), 1)
        XCTAssertEqual(store.plan, WeeknightFixture.initialPlan)
        XCTAssertEqual(store.savedRecipeRecords, WeeknightFixture.initialSavedRecipeRecords)
    }
}

private actor CountingPlanRepository: PlanRepository {
    private(set) var saveCount = 0
    private var plan = WeeknightFixture.initialPlan
    private var failsOnce: Bool

    init(failsOnce: Bool = false) {
        self.failsOnce = failsOnce
    }

    func loadPlan() -> WeekPlan { plan }

    func savePlan(_ plan: WeekPlan) async throws {
        saveCount += 1
        try? await Task.sleep(nanoseconds: 120_000_000)
        if failsOnce {
            failsOnce = false
            throw AssignmentError.simulatedFailure
        }
        self.plan = plan
    }
}
