import Foundation

struct Money: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    let minorUnits: Int
    let currencyCode: String

    init(minorUnits: Int, currencyCode: String = "USD") {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    static func zero(currencyCode: String = "USD") -> Money {
        Money(minorUnits: 0, currencyCode: currencyCode)
    }

    static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currencyCode == rhs.currencyCode, "Cannot add different currencies")
        return Money(minorUnits: lhs.minorUnits + rhs.minorUnits, currencyCode: lhs.currencyCode)
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currencyCode == rhs.currencyCode, "Cannot subtract different currencies")
        return Money(minorUnits: lhs.minorUnits - rhs.minorUnits, currencyCode: lhs.currencyCode)
    }

    static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currencyCode == rhs.currencyCode, "Cannot compare different currencies")
        return lhs.minorUnits < rhs.minorUnits
    }

    var description: String { formatted() }

    func formatted(locale: Locale = Locale(identifier: "en_US")) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amount = NSDecimalNumber(value: minorUnits).dividing(by: 100)
        return formatter.string(from: amount) ?? "\(currencyCode) \(amount)"
    }

    func scaled(byBasisPoints basisPoints: Int) -> Money {
        Money(
            minorUnits: (minorUnits * basisPoints + 5_000) / 10_000,
            currencyCode: currencyCode
        )
    }
}

enum Aisle: String, CaseIterable, Codable, Sendable, Identifiable {
    case produce = "Produce"
    case meatAndFish = "Meat & fish"
    case chilledAndDairy = "Chilled & dairy"
    case pantry = "Pantry"

    var id: String { rawValue }
}

struct Ingredient: Hashable, Codable, Sendable, Identifiable {
    typealias ID = String

    let id: ID
    let canonicalName: String
    let displayName: String
    let aisle: Aisle
}

struct RecipeIngredient: Hashable, Codable, Sendable {
    let ingredient: Ingredient
    let quantity: String
    let estimatedCost: Money

    func quantity(for servings: Int, baseServings: Int) -> String {
        guard servings != baseServings, baseServings > 0 else { return quantity }
        guard let firstDigit = quantity.firstIndex(where: { $0.isNumber }) else { return quantity }
        let numericEnd = quantity[firstDigit...].firstIndex(where: { !$0.isNumber }) ?? quantity.endIndex
        guard let baseAmount = Int(quantity[firstDigit..<numericEnd]) else { return quantity }

        let prefix = String(quantity[..<firstDigit])
        let suffix = String(quantity[numericEnd...])
        let numerator = baseAmount * servings
        if numerator.isMultiple(of: baseServings) {
            let amount = numerator / baseServings
            let pluralUnits = [
                " head": " heads",
                " tin": " tins",
                " thumb": " thumbs",
                " pot": " pots",
                " slice": " slices",
                " clove": " cloves",
                " fillet": " fillets",
                " bunch": " bunches",
            ]
            let adjustedSuffix = baseAmount == 1 && amount != 1 ? (pluralUnits[suffix] ?? suffix) : suffix
            return "\(prefix)\(amount)\(adjustedSuffix)"
        }
        return "\(prefix)\(numerator)/\(baseServings)\(suffix)"
    }

    func cost(for servings: Int, baseServings: Int) -> Money {
        guard baseServings > 0 else { return estimatedCost }
        let scaled = (estimatedCost.minorUnits * servings + baseServings / 2) / baseServings
        return Money(minorUnits: scaled, currencyCode: estimatedCost.currencyCode)
    }
}

struct Recipe: Hashable, Codable, Sendable, Identifiable {
    typealias ID = String

    let id: ID
    let title: String
    let sourceName: String
    let activeMinutes: Int
    let servings: Int
    let tags: [String]
    let rationale: String
    let ingredients: [RecipeIngredient]
    let artwork: ArtworkStyle
    let sourceAttribution: String
    let methodSteps: [String]
    let dietaryCompatibility: Set<DietaryRestriction>
    let declaredAllergens: Set<MedicalAllergen>
    let requiredAppliances: Set<KitchenAppliance>
    let protein: PreferredProtein
    let mealStyles: Set<MealStyle>

    init(
        id: ID,
        title: String,
        sourceName: String,
        activeMinutes: Int,
        servings: Int,
        tags: [String],
        rationale: String,
        ingredients: [RecipeIngredient],
        artwork: ArtworkStyle,
        sourceAttribution: String? = nil,
        methodSteps: [String] = [],
        dietaryCompatibility: Set<DietaryRestriction> = [],
        declaredAllergens: Set<MedicalAllergen> = [],
        requiredAppliances: Set<KitchenAppliance> = [],
        protein: PreferredProtein = .vegetarian,
        mealStyles: Set<MealStyle> = []
    ) {
        self.id = id
        self.title = title
        self.sourceName = sourceName
        self.activeMinutes = activeMinutes
        self.servings = servings
        self.tags = tags
        self.rationale = rationale
        self.ingredients = ingredients
        self.artwork = artwork
        self.sourceAttribution = sourceAttribution ?? "Weeknight fixture inspired by \(sourceName). Local prototype content; no external photography is included."
        self.methodSteps = methodSteps
        self.dietaryCompatibility = dietaryCompatibility
        self.declaredAllergens = declaredAllergens
        self.requiredAppliances = requiredAppliances
        self.protein = protein
        self.mealStyles = mealStyles
    }

    var estimatedCost: Money {
        ingredients.reduce(.zero()) { $0 + $1.estimatedCost }
    }

    func estimatedCost(for servings: Int) -> Money {
        ingredients.reduce(.zero()) { total, entry in
            total + entry.cost(for: servings, baseServings: self.servings)
        }
    }
}

enum ArtworkStyle: String, Codable, Sendable {
    case honeySoy
    case chilli
    case stirFry
    case carbonara
    case curry
    case caesar
    case chopped
    case steak
}

enum Weekday: String, CaseIterable, Codable, Sendable, Identifiable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"

    var id: String { rawValue }
    var shortName: String { String(rawValue.prefix(3)) }
}

struct MealSlot: Hashable, Codable, Sendable, Identifiable {
    var id: Weekday { day }
    let day: Weekday
    var recipeID: Recipe.ID?
    var servings: Int

    init(day: Weekday, recipeID: Recipe.ID?, servings: Int = 1) {
        self.day = day
        self.recipeID = recipeID
        self.servings = max(1, servings)
    }
}

struct WeekPlan: Hashable, Codable, Sendable, Identifiable {
    typealias ID = String

    let id: ID
    let weekLabel: String
    var storeName: String
    var budget: Money
    var slots: [MealSlot]
    var revision: Int
}

enum BudgetStatus: String, Sendable {
    case comfortable
    case nearLimit
    case exactlyAtBudget
    case overBudget
}

struct AssignmentPreview: Hashable, Sendable {
    let day: Weekday
    let recipe: Recipe
    let servings: Int
    let replacedRecipe: Recipe?
    let replacedServings: Int?
    let projectedSpend: Money
    let projectedRemaining: Money

    var isOverBudget: Bool { projectedRemaining.minorUnits < 0 }
}

struct ShoppingContribution: Hashable, Sendable, Identifiable {
    var id: String { "\(day.rawValue)-\(recipeID)" }
    let day: Weekday
    let recipeID: Recipe.ID
    let recipeTitle: String
    let servings: Int
}

struct ShoppingListItem: Hashable, Sendable, Identifiable {
    var id: Ingredient.ID { ingredient.id }
    let ingredient: Ingredient
    let quantityDisplay: String
    let estimatedCost: Money
    let contributions: [ShoppingContribution]
    var isChecked: Bool
}

struct ShoppingProgress: Hashable, Sendable {
    let checked: Int
    let total: Int

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(checked) / Double(total)
    }

    var display: String { "\(checked) of \(total)" }
}

enum MarketOption: String, CaseIterable, Codable, Sendable, Identifiable {
    case unitedStates = "United States · USD"
    case canada = "Canada · CAD"
    case unitedKingdom = "United Kingdom · GBP"

    var id: String { rawValue }
    var isSupported: Bool { self == .unitedStates }
    var currencyCode: String {
        switch self {
        case .unitedStates: "USD"
        case .canada: "CAD"
        case .unitedKingdom: "GBP"
        }
    }
}

enum Supermarket: String, CaseIterable, Codable, Sendable, Identifiable {
    case traderJoes = "Trader Joe's"
    case aldi = "Aldi"
    case safeway = "Safeway"

    var id: String { rawValue }

    /// Deterministic local quote-set adjustment relative to the canonical Trader Joe's fixture.
    var priceBasisPoints: Int {
        switch self {
        case .traderJoes: 10_000
        case .aldi: 9_200
        case .safeway: 10_800
        }
    }
}

enum DietaryRestriction: String, CaseIterable, Codable, Sendable, Identifiable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case pescatarian = "Pescatarian"
    case glutenFree = "Gluten-free"

    var id: String { rawValue }
}

enum MedicalAllergen: String, CaseIterable, Codable, Sendable, Identifiable {
    case milk = "Milk"
    case egg = "Egg"
    case fish = "Fish"
    case wheat = "Wheat"
    case soy = "Soy"
    case sesame = "Sesame"

    var id: String { rawValue }
}

enum KitchenAppliance: String, CaseIterable, Codable, Sendable, Identifiable {
    case stovetop = "Stovetop"
    case oven = "Oven"
    case microwave = "Microwave"
    case airFryer = "Air fryer"
    case blender = "Blender"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .stovetop: "flame"
        case .oven: "oven"
        case .microwave: "microwave"
        case .airFryer: "fan"
        case .blender: "takeoutbag.and.cup.and.straw"
        }
    }
}

enum PreferredProtein: String, CaseIterable, Codable, Sendable, Identifiable {
    case chicken = "Chicken"
    case beef = "Beef"
    case pork = "Pork"
    case fish = "Fish"
    case vegetarian = "Vegetarian"

    var id: String { rawValue }
}

enum MealStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case speedy = "Speedy"
    case healthyComfort = "Healthy comfort"
    case familyFavorite = "Family favorite"
    case fakeaway = "Fakeaway"
    case meatFree = "Meat-free"
    case proteinPacked = "Protein-packed"
    case treatNight = "Treat night"

    var id: String { rawValue }
}

struct UserPreferences: Hashable, Codable, Sendable {
    static let minimumHouseholdSize = 1
    static let maximumHouseholdSize = 8
    static let minimumBudgetMinorUnits = 4_000
    static let maximumBudgetMinorUnits = 24_000
    static let budgetStepMinorUnits = 1_000
    static let minimumCookingMinutes = 15
    static let maximumCookingMinutes = 60
    static let cookingMinutesStep = 5

    var market: MarketOption
    var supermarket: Supermarket
    var householdSize: Int
    var cookingDays: [Weekday]
    var weeklyBudget: Money
    var maximumCookingMinutes: Int
    var dietaryRestrictions: Set<DietaryRestriction>
    var medicalAllergens: Set<MedicalAllergen>
    var dislikedIngredientIDs: Set<Ingredient.ID>
    var preferredProteins: Set<PreferredProtein>
    var preferredMealStyles: Set<MealStyle>
    var availableAppliances: Set<KitchenAppliance>

    static var canonical: UserPreferences {
        UserPreferences(
            market: .unitedStates,
            supermarket: .traderJoes,
            householdSize: 1,
            cookingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            weeklyBudget: Money(minorUnits: 8_000),
            maximumCookingMinutes: 45,
            dietaryRestrictions: [],
            medicalAllergens: [],
            dislikedIngredientIDs: [],
            preferredProteins: [],
            preferredMealStyles: [],
            availableAppliances: [.stovetop, .oven]
        )
    }

    var storeName: String { supermarket.rawValue }

    mutating func normalize() {
        if !market.isSupported { market = .unitedStates }
        householdSize = min(Self.maximumHouseholdSize, max(Self.minimumHouseholdSize, householdSize))
        weeklyBudget = Money(
            minorUnits: min(Self.maximumBudgetMinorUnits, max(Self.minimumBudgetMinorUnits, weeklyBudget.minorUnits)),
            currencyCode: market.currencyCode
        )
        maximumCookingMinutes = min(Self.maximumCookingMinutes, max(Self.minimumCookingMinutes, maximumCookingMinutes))
        cookingDays = Weekday.allCases.filter(Set(cookingDays).contains)
        if cookingDays.isEmpty { cookingDays = [.monday] }
    }
}

struct SavedRecipeRecord: Hashable, Codable, Sendable, Identifiable {
    var id: Recipe.ID { recipeID }
    let recipeID: Recipe.ID
    let savedAt: Date
}

struct AppSnapshot: Hashable, Codable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var plan: WeekPlan
    var checkedIngredientIDs: Set<Ingredient.ID>
    var savedRecipeRecords: [SavedRecipeRecord]
    var recipeNotes: [Recipe.ID: String]
    var preferences: UserPreferences

    init(
        schemaVersion: Int = currentSchemaVersion,
        plan: WeekPlan,
        checkedIngredientIDs: Set<Ingredient.ID>,
        savedRecipeRecords: [SavedRecipeRecord],
        recipeNotes: [Recipe.ID: String],
        preferences: UserPreferences = .canonical
    ) {
        self.schemaVersion = schemaVersion
        self.plan = plan
        self.checkedIngredientIDs = checkedIngredientIDs
        self.savedRecipeRecords = savedRecipeRecords
        self.recipeNotes = recipeNotes
        self.preferences = preferences
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, plan, checkedIngredientIDs, savedRecipeRecords, recipeNotes, preferences
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let decodedPlan = try values.decode(WeekPlan.self, forKey: .plan)
        plan = decodedPlan
        checkedIngredientIDs = try values.decodeIfPresent(Set<Ingredient.ID>.self, forKey: .checkedIngredientIDs) ?? []
        savedRecipeRecords = try values.decodeIfPresent([SavedRecipeRecord].self, forKey: .savedRecipeRecords) ?? []
        recipeNotes = try values.decodeIfPresent([Recipe.ID: String].self, forKey: .recipeNotes) ?? [:]
        preferences = try values.decodeIfPresent(UserPreferences.self, forKey: .preferences) ?? {
            var migrated = UserPreferences.canonical
            migrated.weeklyBudget = decodedPlan.budget
            migrated.cookingDays = decodedPlan.slots.map(\.day)
            migrated.supermarket = Supermarket(rawValue: decodedPlan.storeName) ?? .traderJoes
            return migrated
        }()
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(plan, forKey: .plan)
        try values.encode(checkedIngredientIDs, forKey: .checkedIngredientIDs)
        try values.encode(savedRecipeRecords, forKey: .savedRecipeRecords)
        try values.encode(recipeNotes, forKey: .recipeNotes)
        try values.encode(preferences, forKey: .preferences)
    }
}

struct EligibilityReason: Hashable, Sendable, Identifiable {
    enum Kind: String, Hashable, Sendable {
        case medicalAllergen
        case dietaryRestriction
        case unavailableAppliance
        case maximumCookingTime
    }

    var id: String { "\(kind.rawValue)-\(message)" }
    let kind: Kind
    let message: String
}

struct RecipeEligibility: Hashable, Sendable {
    let recipeID: Recipe.ID
    let hardReasons: [EligibilityReason]
    let exceedsPreferredCookingTime: Bool

    var isEligible: Bool { hardReasons.isEmpty }
}

struct RankedRecipe: Hashable, Sendable, Identifiable {
    var id: Recipe.ID { recipe.id }
    let recipe: Recipe
    let score: Int
    let explanations: [String]
    let cautions: [String]
}

struct ScheduledPreferenceConflict: Hashable, Sendable, Identifiable {
    var id: Weekday { day }
    let day: Weekday
    let recipe: Recipe
    let reasons: [EligibilityReason]
}

struct PreferenceUpdatePreview: Hashable, Sendable {
    let draft: UserPreferences
    let projectedPlan: WeekPlan
    let conflicts: [ScheduledPreferenceConflict]
    let removedFilledSlots: [(day: Weekday, recipeTitle: String)]
    let addedDays: [Weekday]
    let removedDays: [Weekday]
    let servingChangeCount: Int
    let currentSpend: Money
    let projectedSpend: Money
    let currentShoppingItemCount: Int
    let projectedShoppingItemCount: Int
    let shoppingChangeCount: Int

    var requiresConfirmation: Bool {
        !conflicts.isEmpty || !addedDays.isEmpty || !removedDays.isEmpty || servingChangeCount > 0
    }

    static func == (lhs: PreferenceUpdatePreview, rhs: PreferenceUpdatePreview) -> Bool {
        lhs.draft == rhs.draft
            && lhs.projectedPlan == rhs.projectedPlan
            && lhs.conflicts == rhs.conflicts
            && lhs.removedFilledSlots.map { "\($0.day.rawValue):\($0.recipeTitle)" } == rhs.removedFilledSlots.map { "\($0.day.rawValue):\($0.recipeTitle)" }
            && lhs.addedDays == rhs.addedDays
            && lhs.removedDays == rhs.removedDays
            && lhs.servingChangeCount == rhs.servingChangeCount
            && lhs.currentSpend == rhs.currentSpend
            && lhs.projectedSpend == rhs.projectedSpend
            && lhs.currentShoppingItemCount == rhs.currentShoppingItemCount
            && lhs.projectedShoppingItemCount == rhs.projectedShoppingItemCount
            && lhs.shoppingChangeCount == rhs.shoppingChangeCount
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(draft)
        hasher.combine(projectedPlan)
        hasher.combine(conflicts)
        removedFilledSlots.forEach { hasher.combine($0.day); hasher.combine($0.recipeTitle) }
        hasher.combine(addedDays)
        hasher.combine(removedDays)
        hasher.combine(servingChangeCount)
        hasher.combine(currentSpend)
        hasher.combine(projectedSpend)
        hasher.combine(currentShoppingItemCount)
        hasher.combine(projectedShoppingItemCount)
        hasher.combine(shoppingChangeCount)
    }
}

enum AutofillOutcome: Hashable, Sendable {
    case success(plan: WeekPlan, assignments: [ShoppingContribution], projectedSpend: Money)
    case unable(message: String, suggestions: [String])
}

struct RecipeServingDraft: Hashable, Sendable {
    static let minimum = 1
    static let maximum = 8

    let committed: Int
    private(set) var value: Int

    init(committed: Int) {
        let clamped = min(Self.maximum, max(Self.minimum, committed))
        self.committed = clamped
        self.value = clamped
    }

    var isEdited: Bool { value != committed }
    var canDecrement: Bool { value > Self.minimum }
    var canIncrement: Bool { value < Self.maximum }

    mutating func decrement() {
        guard canDecrement else { return }
        value -= 1
    }

    mutating func increment() {
        guard canIncrement else { return }
        value += 1
    }

    mutating func cancel() {
        value = committed
    }
}

enum SavedFilter: String, CaseIterable, Hashable, Sendable, Identifiable {
    case all = "All recipes"
    case recentlySaved = "Recently saved"

    var id: String { rawValue }
}

enum RecipeOrigin: String, Hashable, Sendable {
    case plan = "Plan"
    case discover = "Discover"
    case saved = "Saved"
}

enum RepositoryMode: String, Sendable {
    case ready
    case loading
    case empty
    case error
    case stale
}

enum AssignmentError: LocalizedError, Equatable {
    case simulatedFailure

    var errorDescription: String? {
        "The demo plan could not be updated. Your selected day is still here, so you can retry."
    }
}
