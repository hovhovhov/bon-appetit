import Foundation

enum BackendConnectionState: Hashable, Sendable {
    case local
    case loading
    case connected(provider: String)
    case fallback(message: String)
    case cached(message: String)
    case unavailable(message: String)

    var displayTitle: String {
        switch self {
        case .local: "On-device recommendations"
        case .loading: "Connecting to local backend…"
        case .connected(let provider): provider == "stub" ? "Local backend · Stub personalization" : "Local backend · Personalized"
        case .fallback: "Local fallback active"
        case .cached: "Cached catalogue · Local ranking"
        case .unavailable: "Offline · On-device mode"
        }
    }

    var detail: String? {
        switch self {
        case .fallback(let message), .cached(let message), .unavailable(let message): message
        case .local, .loading, .connected: nil
        }
    }

    var usesBackendCatalogue: Bool {
        switch self {
        case .connected, .cached, .fallback: true
        case .local, .loading, .unavailable: false
        }
    }
}

struct BackendConfiguration: Hashable, Sendable {
    let isEnabled: Bool
    let baseURL: URL
    let timeout: TimeInterval

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> BackendConfiguration? {
        guard !arguments.isEmpty else { return nil }
        if arguments.contains("--backend-disabled") { return nil }
        let explicitlyEnabled = arguments.contains("--backend-enabled")
        let isRegressionJourney = arguments.contains("--reset-fixture") && !explicitlyEnabled
        guard !isRegressionJourney else { return nil }

        let environmentURL = ProcessInfo.processInfo.environment["WEEKNIGHT_BACKEND_BASE_URL"]
        let configuredURL = environmentURL
            ?? (Bundle.main.object(forInfoDictionaryKey: "WeeknightBackendBaseURL") as? String)
        guard let configuredURL, let url = URL(string: configuredURL), !configuredURL.isEmpty else { return nil }
        return BackendConfiguration(isEnabled: true, baseURL: url, timeout: 2.5)
    }
}

enum BackendClientError: LocalizedError, Equatable {
    case cancelled
    case timedOut
    case unavailable
    case invalidStatus(Int)
    case invalidResponse
    case incompatibleCatalogue

    var errorDescription: String? {
        switch self {
        case .cancelled: "The backend request was cancelled."
        case .timedOut: "The local backend took too long to respond."
        case .unavailable: "The local backend is unavailable."
        case .invalidStatus: "The local backend returned an error."
        case .invalidResponse: "The local backend returned data Weeknight could not validate."
        case .incompatibleCatalogue: "The cached catalogue is not compatible with this app version."
        }
    }
}

struct BackendCatalogue: Hashable, Sendable {
    let version: String
    let recipes: [Recipe]
}

protocol WeeknightBackendClient: Sendable {
    func loadCatalogue() async throws -> BackendCatalogueResponse
    func recommendations(_ request: BackendRecommendationRequest) async throws -> BackendRecommendationResponse
    func generateWeek(_ request: BackendWeekPlanRequest) async throws -> BackendWeekPlanResponse
}

protocol BackendCatalogueCaching: Sendable {
    func loadCompatible() async -> BackendCatalogueResponse?
    func save(_ catalogue: BackendCatalogueResponse) async
}

actor FileBackendCatalogueCache: BackendCatalogueCaching {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.fileURL = directory.appendingPathComponent("weeknight-backend-catalogue-v1.json")
    }

    func loadCompatible() async -> BackendCatalogueResponse? {
        guard let data = try? Data(contentsOf: fileURL),
              let catalogue = try? decoder.decode(BackendCatalogueResponse.self, from: data),
              catalogue.schemaVersion == 1,
              catalogue.environment == "development"
        else { return nil }
        return catalogue
    }

    func save(_ catalogue: BackendCatalogueResponse) async {
        guard catalogue.schemaVersion == 1, let data = try? encoder.encode(catalogue) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

actor InMemoryBackendCatalogueCache: BackendCatalogueCaching {
    var catalogue: BackendCatalogueResponse?

    init(catalogue: BackendCatalogueResponse? = nil) {
        self.catalogue = catalogue
    }

    func loadCompatible() async -> BackendCatalogueResponse? {
        guard catalogue?.schemaVersion == 1 else { return nil }
        return catalogue
    }

    func save(_ catalogue: BackendCatalogueResponse) async {
        self.catalogue = catalogue
    }
}

struct URLSessionWeeknightBackendClient: WeeknightBackendClient {
    let configuration: BackendConfiguration
    let session: URLSession

    init(configuration: BackendConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        if let session {
            self.session = session
        } else {
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.timeoutIntervalForRequest = configuration.timeout
            sessionConfiguration.timeoutIntervalForResource = configuration.timeout + 1
            sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: sessionConfiguration)
        }
    }

    func loadCatalogue() async throws -> BackendCatalogueResponse {
        try await send(path: "/v1/catalog/recipes", method: "GET", body: Optional<Data>.none, retryCount: 1)
    }

    func recommendations(_ request: BackendRecommendationRequest) async throws -> BackendRecommendationResponse {
        try await send(path: "/v1/recommendations", method: "POST", body: try JSONEncoder().encode(request), retryCount: 0)
    }

    func generateWeek(_ request: BackendWeekPlanRequest) async throws -> BackendWeekPlanResponse {
        try await send(path: "/v1/week-plans/generate", method: "POST", body: try JSONEncoder().encode(request), retryCount: 0)
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        body: Data?,
        retryCount: Int
    ) async throws -> Response {
        var request = URLRequest(url: configuration.baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        var attempt = 0
        while true {
            do {
                try Task.checkCancellation()
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse else { throw BackendClientError.invalidResponse }
                guard (200..<300).contains(http.statusCode) else {
                    if method == "GET", attempt < retryCount, http.statusCode >= 500 {
                        attempt += 1
                        continue
                    }
                    throw BackendClientError.invalidStatus(http.statusCode)
                }
                do {
                    return try JSONDecoder().decode(Response.self, from: data)
                } catch {
                    throw BackendClientError.invalidResponse
                }
            } catch is CancellationError {
                throw BackendClientError.cancelled
            } catch let error as BackendClientError {
                throw error
            } catch let error as URLError {
                if error.code == .cancelled { throw BackendClientError.cancelled }
                let mapped: BackendClientError = error.code == .timedOut ? .timedOut : .unavailable
                if method == "GET", attempt < retryCount {
                    attempt += 1
                    continue
                }
                throw mapped
            }
        }
    }
}

struct BackendCatalogueResponse: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let catalogueVersion: String
    let environment: String
    let recipes: [BackendRecipeRecord]

    func validatedDomainCatalogue() throws -> BackendCatalogue {
        guard schemaVersion == 1, environment == "development", !catalogueVersion.isEmpty else {
            throw BackendClientError.incompatibleCatalogue
        }
        let mapped = try recipes.map { try $0.validatedDomainRecipe() }
        guard Set(mapped.map(\.id)).count == mapped.count else { throw BackendClientError.invalidResponse }
        return BackendCatalogue(version: catalogueVersion, recipes: mapped)
    }
}

struct BackendRecipeRecord: Codable, Hashable, Sendable {
    struct Source: Codable, Hashable, Sendable {
        let name: String
        let url: String?
        let attribution: String
        let rightsStatus: String
        let clearance: String
    }

    struct Image: Codable, Hashable, Sendable {
        let kind: String
        let identifier: String
        let rightsStatus: String
    }

    struct Cost: Codable, Hashable, Sendable {
        let minorUnits: Int
        let currency: String
        let source: String
        let freshnessDate: String
        let confidence: String
    }

    struct IngredientRecord: Codable, Hashable, Sendable {
        let id: String
        let canonicalName: String
        let displayName: String
        let aisle: String
        let displayQuantity: String
        let estimatedCostMinorUnits: Int
    }

    struct Ranking: Codable, Hashable, Sendable {
        let basePriority: Int
        let varietyGroup: String
    }

    let id: String
    let version: Int
    let title: String
    let source: Source
    let image: Image
    let activeMinutes: Int
    let defaultServings: Int
    let cuisine: String?
    let estimatedCost: Cost
    let tags: [String]
    let rationale: String
    let ingredients: [IngredientRecord]
    let cookingSteps: [String]
    let allergens: [String]
    let dietaryClassifications: [String]
    let requiredAppliances: [String]
    let protein: String
    let mealStyles: [String]
    let ranking: Ranking

    func validatedDomainRecipe() throws -> Recipe {
        guard !id.isEmpty, version > 0, !title.isEmpty, !source.name.isEmpty,
              !source.attribution.isEmpty, source.clearance == "development-only",
              image.kind == "native-placeholder", image.rightsStatus == "weeknight-owned-placeholder",
              activeMinutes > 0, defaultServings > 0, estimatedCost.minorUnits >= 0,
              estimatedCost.currency == "USD", !ingredients.isEmpty, !cookingSteps.isEmpty,
              let artwork = ArtworkStyle(rawValue: image.identifier),
              let proteinValue = PreferredProtein(rawValue: protein)
        else { throw BackendClientError.invalidResponse }

        let mappedIngredients = try ingredients.map { record -> RecipeIngredient in
            guard !record.id.isEmpty, !record.canonicalName.isEmpty, !record.displayName.isEmpty,
                  !record.displayQuantity.isEmpty, record.estimatedCostMinorUnits >= 0,
                  let aisle = Aisle(rawValue: record.aisle)
            else { throw BackendClientError.invalidResponse }
            return RecipeIngredient(
                ingredient: Ingredient(
                    id: record.id,
                    canonicalName: record.canonicalName,
                    displayName: record.displayName,
                    aisle: aisle
                ),
                quantity: record.displayQuantity,
                estimatedCost: Money(minorUnits: record.estimatedCostMinorUnits, currencyCode: estimatedCost.currency)
            )
        }
        guard Set(mappedIngredients.map(\.ingredient.id)).count == mappedIngredients.count,
              mappedIngredients.reduce(0, { $0 + $1.estimatedCost.minorUnits }) == estimatedCost.minorUnits
        else { throw BackendClientError.invalidResponse }

        let declaredAllergens = try set(from: allergens, as: MedicalAllergen.self)
        let dietary = try set(from: dietaryClassifications, as: DietaryRestriction.self)
        let appliances = try set(from: requiredAppliances, as: KitchenAppliance.self)
        let styles = try set(from: mealStyles, as: MealStyle.self)
        let cuisineValue: Cuisine?
        if let cuisine {
            guard let mappedCuisine = Cuisine(rawValue: cuisine) else { throw BackendClientError.invalidResponse }
            cuisineValue = mappedCuisine
        } else {
            cuisineValue = nil
        }
        let sourceURL: URL?
        if let rawURL = source.url {
            guard let parsed = URL(string: rawURL), parsed.scheme == "https" else { throw BackendClientError.invalidResponse }
            sourceURL = parsed
        } else {
            sourceURL = nil
        }

        return Recipe(
            id: id,
            title: title,
            sourceName: source.name,
            activeMinutes: activeMinutes,
            servings: defaultServings,
            cuisine: cuisineValue,
            tags: tags,
            rationale: rationale,
            ingredients: mappedIngredients,
            artwork: artwork,
            sourceAttribution: source.attribution,
            methodSteps: cookingSteps,
            dietaryCompatibility: dietary,
            declaredAllergens: declaredAllergens,
            requiredAppliances: appliances,
            protein: proteinValue,
            mealStyles: styles,
            provenance: RecipeProvenance(
                recordVersion: version,
                sourceURL: sourceURL,
                contentClearance: source.clearance,
                sourceRightsStatus: source.rightsStatus,
                imageRightsStatus: image.rightsStatus,
                estimateSource: estimatedCost.source,
                estimateFreshnessDate: estimatedCost.freshnessDate,
                estimateConfidence: estimatedCost.confidence
            )
        )
    }

    private func set<Value>(from values: [String], as type: Value.Type) throws -> Set<Value>
    where Value: RawRepresentable & Hashable, Value.RawValue == String {
        let mapped = values.compactMap(Value.init(rawValue:))
        guard mapped.count == values.count else { throw BackendClientError.invalidResponse }
        return Set(mapped)
    }
}

struct BackendSoftPreferences: Codable, Hashable, Sendable {
    let maximumCookingMinutes: Int
    let dislikedIngredientIDs: [String]
    let preferredProteins: [String]
    let preferredMealStyles: [String]
    let savedRecipeIDs: [String]
}

struct BackendRecommendationRequest: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let catalogueVersion: String
    let eligibleRecipeIDs: [String]
    let scheduledRecipeIDs: [String]
    let remainingBudgetMinorUnits: Int
    let currency: String
    let householdSize: Int
    let preferences: BackendSoftPreferences
}

struct BackendWeekPlanRequest: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let catalogueVersion: String
    let eligibleRecipeIDs: [String]
    let scheduledRecipeIDs: [String]
    let openDays: [String]
    let currentSpendMinorUnits: Int
    let budgetMinorUnits: Int
    let currency: String
    let householdSize: Int
    let preferences: BackendSoftPreferences
}

struct BackendUsage: Codable, Hashable, Sendable {
    let provider: String
    let model: String
    let latencyMs: Int
    let responseID: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let totalTokens: Int?
}

struct BackendRecommendationItem: Codable, Hashable, Sendable {
    let recipeID: String
    let explanation: String
    let softFitSignals: [String]
}

struct BackendRecommendationResponse: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let catalogueVersion: String
    let status: String
    let fallbackReason: String?
    let recommendations: [BackendRecommendationItem]
    let usage: BackendUsage?
}

struct BackendWeekAssignment: Codable, Hashable, Sendable {
    let day: String
    let recipeID: String
    let explanation: String
}

struct BackendWeekPlanResponse: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let catalogueVersion: String
    let status: String
    let outcome: String
    let fallbackReason: String?
    let assignments: [BackendWeekAssignment]
    let message: String?
    let usage: BackendUsage?
}
