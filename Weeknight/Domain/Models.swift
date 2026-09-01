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

    var estimatedCost: Money {
        ingredients.reduce(.zero()) { $0 + $1.estimatedCost }
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
    let replacedRecipe: Recipe?
    let projectedSpend: Money
    let projectedRemaining: Money

    var isOverBudget: Bool { projectedRemaining.minorUnits < 0 }
}

struct ShoppingContribution: Hashable, Sendable, Identifiable {
    var id: String { "\(day.rawValue)-\(recipeID)" }
    let day: Weekday
    let recipeID: Recipe.ID
    let recipeTitle: String
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

