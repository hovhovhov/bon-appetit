import Foundation

protocol RecipeRepository: Sendable {
    func load(mode: RepositoryMode) async throws -> [Recipe]
}

protocol PlanRepository: Sendable {
    func loadPlan() async -> WeekPlan
    func savePlan(_ plan: WeekPlan) async throws
}

protocol ShoppingRepository: Sendable {
    func retry() async -> RepositoryMode
}

enum RepositoryFailure: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "The local fixture is temporarily unavailable."
    }
}

struct MockRecipeRepository: RecipeRepository {
    func load(mode: RepositoryMode) async throws -> [Recipe] {
        switch mode {
        case .loading:
            try? await Task.sleep(nanoseconds: 350_000_000)
            return WeeknightFixture.recipes
        case .empty:
            return []
        case .error:
            throw RepositoryFailure.unavailable
        case .ready, .stale:
            return WeeknightFixture.recipes
        }
    }
}

actor MockPlanRepository: PlanRepository {
    private var plan: WeekPlan
    private var shouldFailNextSave: Bool

    init(plan: WeekPlan = WeeknightFixture.initialPlan, shouldFailNextSave: Bool = false) {
        self.plan = plan
        self.shouldFailNextSave = shouldFailNextSave
    }

    func loadPlan() -> WeekPlan { plan }

    func savePlan(_ plan: WeekPlan) async throws {
        try? await Task.sleep(nanoseconds: 180_000_000)
        if shouldFailNextSave {
            shouldFailNextSave = false
            throw AssignmentError.simulatedFailure
        }
        self.plan = plan
    }
}

struct MockShoppingRepository: ShoppingRepository {
    func retry() async -> RepositoryMode {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return .ready
    }
}

