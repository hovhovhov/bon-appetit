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
