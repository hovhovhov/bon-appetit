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
        methodSteps: [String] = []
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
    let storeName: String
    let budget: Money
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

struct UserPreferences: Hashable, Codable, Sendable {
    let storeName: String
    let householdSize: Int
    let cookingDays: [Weekday]
    let weeklyBudget: Money
}

struct SavedRecipeRecord: Hashable, Codable, Sendable, Identifiable {
    var id: Recipe.ID { recipeID }
    let recipeID: Recipe.ID
    let savedAt: Date
}

struct AppSnapshot: Hashable, Codable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var plan: WeekPlan
    var checkedIngredientIDs: Set<Ingredient.ID>
    var savedRecipeRecords: [SavedRecipeRecord]
    var recipeNotes: [Recipe.ID: String]

    init(
        schemaVersion: Int = currentSchemaVersion,
        plan: WeekPlan,
        checkedIngredientIDs: Set<Ingredient.ID>,
        savedRecipeRecords: [SavedRecipeRecord],
        recipeNotes: [Recipe.ID: String]
    ) {
        self.schemaVersion = schemaVersion
        self.plan = plan
        self.checkedIngredientIDs = checkedIngredientIDs
        self.savedRecipeRecords = savedRecipeRecords
        self.recipeNotes = recipeNotes
    }
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
