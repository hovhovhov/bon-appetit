import Foundation
import XCTest
@testable import Weeknight

final class RemoteBackendTransportTests: XCTestCase {
    override func tearDown() {
        MockBackendURLProtocol.handler = nil
        super.tearDown()
    }

    func testRemoteCatalogueDecodesIntoValidatedDomainRecipes() async throws {
        let expected = makeBackendCatalogueResponse()
        MockBackendURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/catalog/recipes")
            return (.success, try JSONEncoder().encode(expected))
        }
        let client = makeURLSessionClient()

        let response = try await client.loadCatalogue()
        let catalogue = try response.validatedDomainCatalogue()

        XCTAssertEqual(catalogue.version, "dev-2026-08-31.1")
        XCTAssertEqual(catalogue.recipes.map(\.id), WeeknightFixture.recipes.map(\.id))
        XCTAssertEqual(catalogue.recipes.first?.estimatedCost, WeeknightFixture.recipes.first?.estimatedCost)
        XCTAssertEqual(catalogue.recipes.first?.provenance.contentClearance, "development-only")
    }

    func testGETTimeoutRetriesOnceThenSucceeds() async throws {
        let lock = NSLock()
        var calls = 0
        MockBackendURLProtocol.handler = { _ in
            lock.lock()
            calls += 1
            let attempt = calls
            lock.unlock()
            if attempt == 1 { throw URLError(.timedOut) }
            return (.success, try JSONEncoder().encode(makeBackendCatalogueResponse()))
        }

        let response = try await makeURLSessionClient().loadCatalogue()

        XCTAssertEqual(response.recipes.count, 8)
        XCTAssertEqual(calls, 2)
    }

    func testPOSTServerFailureIsNotRetried() async {
        let lock = NSLock()
        var calls = 0
        MockBackendURLProtocol.handler = { _ in
            lock.lock(); calls += 1; lock.unlock()
            return (.serverError, Data("{}".utf8))
        }
        do {
            _ = try await makeURLSessionClient().recommendations(makeRecommendationRequest())
            XCTFail("Expected typed server error")
        } catch {
            XCTAssertEqual(error as? BackendClientError, .invalidStatus(500))
        }
        XCTAssertEqual(calls, 1)
    }

    func testRequestCancellationPropagatesAsTypedCancellation() async {
        MockBackendURLProtocol.handler = { _ in
            try awaitDelay(milliseconds: 2_000)
            return (.success, try JSONEncoder().encode(makeBackendCatalogueResponse()))
        }
        let client = makeURLSessionClient(timeout: 3)
        let task = Task { try await client.loadCatalogue() }
        try? await Task.sleep(nanoseconds: 30_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertEqual(error as? BackendClientError, .cancelled)
        }
    }

    func testInvalidJSONFailsClosed() async {
        MockBackendURLProtocol.handler = { _ in (.success, Data("not-json".utf8)) }
        do {
            _ = try await makeURLSessionClient().loadCatalogue()
            XCTFail("Expected invalid response")
        } catch {
            XCTAssertEqual(error as? BackendClientError, .invalidResponse)
        }
    }

    private func makeURLSessionClient(timeout: TimeInterval = 0.2) -> URLSessionWeeknightBackendClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockBackendURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return URLSessionWeeknightBackendClient(
            configuration: BackendConfiguration(
                isEnabled: true,
                baseURL: URL(string: "http://127.0.0.1:8787")!,
                timeout: timeout
            ),
            session: session
        )
    }
}

@MainActor
final class Milestone4StoreTests: XCTestCase {
    func testOfflineLaunchUsesLastSuccessfulCompatibleCatalogueCache() async {
        let catalogue = makeBackendCatalogueResponse()
        let cache = InMemoryBackendCatalogueCache(catalogue: catalogue)
        let client = MockWeeknightBackendClient(catalogue: .failure(.unavailable))
        let store = makeStore(client: client, cache: cache)

        await store.connectBackend()

        guard case .cached = store.backendState else { return XCTFail("Expected cached state") }
        XCTAssertEqual(store.recipes.map(\.id), WeeknightFixture.recipes.map(\.id))
        XCTAssertEqual(store.weeklySpend, WeeknightFixture.money(3_540))
    }

    func testUnavailableBackendWithoutCacheKeepsAppUsableOnDevice() async {
        let store = makeStore(
            client: MockWeeknightBackendClient(catalogue: .failure(.unavailable)),
            cache: InMemoryBackendCatalogueCache()
        )

        await store.connectBackend()

        guard case .unavailable = store.backendState else { return XCTFail("Expected offline state") }
        XCTAssertEqual(store.discoverRecipes.count, 5)
        XCTAssertEqual(store.shoppingItems.count, 25)
    }

    func testMalformedRemoteCatalogueNeverReplacesApprovedLocalData() async {
        var malformed = makeBackendCatalogueResponse()
        malformed = BackendCatalogueResponse(
            schemaVersion: malformed.schemaVersion,
            catalogueVersion: malformed.catalogueVersion,
            environment: malformed.environment,
            recipes: malformed.recipes.dropLast().map { $0 }
        )
        let store = makeStore(
            client: MockWeeknightBackendClient(catalogue: .success(malformed)),
            cache: InMemoryBackendCatalogueCache()
        )

        await store.connectBackend()

        guard case .fallback = store.backendState else { return XCTFail("Expected validation fallback") }
        XCTAssertEqual(store.recipes.map(\.id), WeeknightFixture.recipes.map(\.id))
    }

    func testAIUnavailableStillCompletesWithDeterministicAutofill() async throws {
        let client = MockWeeknightBackendClient(
            catalogue: .success(makeBackendCatalogueResponse()),
            recommendations: .success(makeRecommendationResponse(status: "fallback")),
            week: .failure(.unavailable)
        )
        let store = makeStore(client: client, cache: InMemoryBackendCatalogueCache())
        await store.connectBackend()

        let outcome = try await store.fillOpenDays()

        guard case .success = outcome else { return XCTFail("On-device fallback should succeed") }
        XCTAssertEqual(store.filledCount, 5)
        XCTAssertFalse(store.plan.slots.compactMap(\.recipeID).contains("invented-id"))
        XCTAssertEqual(store.weeklySpend, Planning.weeklySpend(plan: store.plan, recipes: store.recipesForCalculations))
    }

    func testUnknownRemoteWeekSelectionCannotReachPlan() async throws {
        let invalidWeek = BackendWeekPlanResponse(
            schemaVersion: 1,
            catalogueVersion: "dev-2026-08-31.1",
            status: "stub",
            outcome: "success",
            fallbackReason: nil,
            assignments: [
                BackendWeekAssignment(day: "Thursday", recipeID: "invented-id", explanation: "Invalid"),
                BackendWeekAssignment(day: "Friday", recipeID: "curry", explanation: "Valid"),
            ],
            message: nil,
            usage: nil
        )
        let client = MockWeeknightBackendClient(
            catalogue: .success(makeBackendCatalogueResponse()),
            recommendations: .success(makeRecommendationResponse()),
            week: .success(invalidWeek)
        )
        let store = makeStore(client: client, cache: InMemoryBackendCatalogueCache())
        await store.connectBackend()

        _ = try await store.fillOpenDays()

        XCTAssertFalse(store.plan.slots.compactMap(\.recipeID).contains("invented-id"))
        XCTAssertEqual(store.filledCount, 5, "The deterministic local fallback should still complete the week")
    }

    func testOnDeviceHardEligibilityStillAppliesAfterRemoteCatalogueLoad() async {
        var snapshot = WeeknightFixture.canonicalSnapshot
        snapshot.preferences.medicalAllergens = [.milk]
        let persistence = InMemoryAppStatePersistence(snapshot: snapshot)
        let store = AppStore(
            arguments: [],
            persistence: persistence,
            backendClient: MockWeeknightBackendClient(
                catalogue: .success(makeBackendCatalogueResponse()),
                recommendations: .success(makeRecommendationResponse())
            ),
            backendCache: InMemoryBackendCatalogueCache()
        )

        await store.connectBackend()

        XCTAssertFalse(store.discoverRecipes.map(\.id).contains("carbonara"))
        XCTAssertFalse(store.discoverRecipes.map(\.id).contains("caesar"))
        XCTAssertTrue(store.discoverRecipes.map(\.id).contains("curry"))
    }

    private func makeStore(
        client: MockWeeknightBackendClient,
        cache: InMemoryBackendCatalogueCache
    ) -> AppStore {
        AppStore(
            arguments: [],
            persistence: InMemoryAppStatePersistence(),
            backendClient: client,
            backendCache: cache
        )
    }
}

private actor MockWeeknightBackendClient: WeeknightBackendClient {
    let catalogue: Result<BackendCatalogueResponse, BackendClientError>
    let recommendationsResult: Result<BackendRecommendationResponse, BackendClientError>
    let weekResult: Result<BackendWeekPlanResponse, BackendClientError>

    init(
        catalogue: Result<BackendCatalogueResponse, BackendClientError>,
        recommendations: Result<BackendRecommendationResponse, BackendClientError> = .success(makeRecommendationResponse()),
        week: Result<BackendWeekPlanResponse, BackendClientError> = .success(makeWeekResponse())
    ) {
        self.catalogue = catalogue
        self.recommendationsResult = recommendations
        self.weekResult = week
    }

    func loadCatalogue() async throws -> BackendCatalogueResponse { try catalogue.get() }
    func recommendations(_ request: BackendRecommendationRequest) async throws -> BackendRecommendationResponse {
        try recommendationsResult.get()
    }
    func generateWeek(_ request: BackendWeekPlanRequest) async throws -> BackendWeekPlanResponse {
        try weekResult.get()
    }
}

private final class MockBackendURLProtocol: URLProtocol, @unchecked Sendable {
    static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse.Status, Data))?
    private var work: DispatchWorkItem?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let work = DispatchWorkItem { [weak self] in
            guard let self, let handler = Self.handler else { return }
            do {
                let (status, data) = try handler(request)
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: status.rawValue,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch let error as URLError {
                client?.urlProtocol(self, didFailWithError: error)
            } catch {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
            }
        }
        self.work = work
        DispatchQueue.global().async(execute: work)
    }

    override func stopLoading() {
        work?.cancel()
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }
}

private extension HTTPURLResponse {
    enum Status: Int {
        case success = 200
        case serverError = 500
    }
}

private func awaitDelay(milliseconds: UInt64) throws {
    Thread.sleep(forTimeInterval: Double(milliseconds) / 1_000)
}

private func makeRecommendationRequest() -> BackendRecommendationRequest {
    BackendRecommendationRequest(
        schemaVersion: 1,
        catalogueVersion: "dev-2026-08-31.1",
        eligibleRecipeIDs: ["carbonara", "curry"],
        scheduledRecipeIDs: [],
        remainingBudgetMinorUnits: 4_000,
        currency: "USD",
        householdSize: 1,
        preferences: BackendSoftPreferences(
            maximumCookingMinutes: 45,
            dislikedIngredientIDs: [],
            preferredProteins: [],
            preferredMealStyles: [],
            savedRecipeIDs: []
        )
    )
}

private func makeRecommendationResponse(status: String = "stub") -> BackendRecommendationResponse {
    BackendRecommendationResponse(
        schemaVersion: 1,
        catalogueVersion: "dev-2026-08-31.1",
        status: status,
        fallbackReason: status == "fallback" ? "provider-unavailable" : nil,
        recommendations: ["carbonara", "curry", "caesar", "chopped", "steak"].map {
            BackendRecommendationItem(recipeID: $0, explanation: "Validated backend explanation for \($0).", softFitSignals: [])
        },
        usage: nil
    )
}

private func makeWeekResponse() -> BackendWeekPlanResponse {
    BackendWeekPlanResponse(
        schemaVersion: 1,
        catalogueVersion: "dev-2026-08-31.1",
        status: "stub",
        outcome: "success",
        fallbackReason: nil,
        assignments: [
            BackendWeekAssignment(day: "Thursday", recipeID: "carbonara", explanation: "Validated pick."),
            BackendWeekAssignment(day: "Friday", recipeID: "curry", explanation: "Validated pick."),
        ],
        message: nil,
        usage: nil
    )
}

private func makeBackendCatalogueResponse() -> BackendCatalogueResponse {
    BackendCatalogueResponse(
        schemaVersion: 1,
        catalogueVersion: "dev-2026-08-31.1",
        environment: "development",
        recipes: WeeknightFixture.recipes.map { recipe in
            BackendRecipeRecord(
                id: recipe.id,
                version: 1,
                title: recipe.title,
                source: BackendRecipeRecord.Source(
                    name: recipe.sourceName,
                    url: nil,
                    attribution: recipe.sourceAttribution,
                    rightsStatus: "development-fixture-unverified",
                    clearance: "development-only"
                ),
                image: BackendRecipeRecord.Image(
                    kind: "native-placeholder",
                    identifier: recipe.artwork.rawValue,
                    rightsStatus: "weeknight-owned-placeholder"
                ),
                activeMinutes: recipe.activeMinutes,
                defaultServings: recipe.servings,
                estimatedCost: BackendRecipeRecord.Cost(
                    minorUnits: recipe.estimatedCost.minorUnits,
                    currency: recipe.estimatedCost.currencyCode,
                    source: "Weeknight local development estimate",
                    freshnessDate: "2026-08-31",
                    confidence: "low"
                ),
                tags: recipe.tags,
                rationale: recipe.rationale,
                ingredients: recipe.ingredients.map { entry in
                    BackendRecipeRecord.IngredientRecord(
                        id: entry.ingredient.id,
                        canonicalName: entry.ingredient.canonicalName,
                        displayName: entry.ingredient.displayName,
                        aisle: entry.ingredient.aisle.rawValue,
                        displayQuantity: entry.quantity,
                        estimatedCostMinorUnits: entry.estimatedCost.minorUnits
                    )
                },
                cookingSteps: recipe.methodSteps,
                allergens: MedicalAllergen.allCases.filter(recipe.declaredAllergens.contains).map(\.rawValue),
                dietaryClassifications: DietaryRestriction.allCases.filter(recipe.dietaryCompatibility.contains).map(\.rawValue),
                requiredAppliances: KitchenAppliance.allCases.filter(recipe.requiredAppliances.contains).map(\.rawValue),
                protein: recipe.protein.rawValue,
                mealStyles: MealStyle.allCases.filter(recipe.mealStyles.contains).map(\.rawValue),
                ranking: BackendRecipeRecord.Ranking(basePriority: 0, varietyGroup: recipe.protein.rawValue.lowercased())
            )
        }
    )
}
