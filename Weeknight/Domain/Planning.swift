import Foundation

enum Planning {
    static func recipesByID(_ recipes: [Recipe]) -> [Recipe.ID: Recipe] {
        Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
    }

    static func filledSlots(in plan: WeekPlan) -> [MealSlot] {
        plan.slots.filter { $0.recipeID != nil }
    }

    static func openSlots(in plan: WeekPlan) -> [MealSlot] {
        plan.slots.filter { $0.recipeID == nil }
    }

    static func weeklySpend(plan: WeekPlan, recipes: [Recipe]) -> Money {
        let lookup = recipesByID(recipes)
        return plan.slots.reduce(.zero(currencyCode: plan.budget.currencyCode)) { total, slot in
            guard let recipeID = slot.recipeID, let recipe = lookup[recipeID] else { return total }
            return total + recipe.estimatedCost(for: slot.servings)
        }
    }

    static func remainingBudget(plan: WeekPlan, recipes: [Recipe]) -> Money {
        plan.budget - weeklySpend(plan: plan, recipes: recipes)
    }

    static func budgetStatus(plan: WeekPlan, recipes: [Recipe]) -> BudgetStatus {
        let spent = weeklySpend(plan: plan, recipes: recipes).minorUnits
        let budget = plan.budget.minorUnits
        if spent > budget { return .overBudget }
        if spent == budget { return .exactlyAtBudget }
        if spent * 100 > budget * 85 { return .nearLimit }
        return .comfortable
    }

    static func previewAssignment(
        recipe: Recipe,
        servings: Int? = nil,
        to day: Weekday,
        in plan: WeekPlan,
        recipes: [Recipe]
    ) -> AssignmentPreview {
        let lookup = recipesByID(recipes)
        let existingSlot = plan.slots.first(where: { $0.day == day })
        let existingID = existingSlot?.recipeID
        let replaced = existingID.flatMap { lookup[$0] }
        let current = weeklySpend(plan: plan, recipes: recipes)
        let selectedServings = servings ?? recipe.servings
        let replacedCost = replaced.map { $0.estimatedCost(for: existingSlot?.servings ?? $0.servings) } ?? .zero()
        let projected = current - replacedCost + recipe.estimatedCost(for: selectedServings)
        return AssignmentPreview(
            day: day,
            recipe: recipe,
            servings: selectedServings,
            replacedRecipe: replaced,
            replacedServings: existingSlot?.servings,
            projectedSpend: projected,
            projectedRemaining: plan.budget - projected
        )
    }

    static func assigning(
        recipeID: Recipe.ID,
        servings: Int = 1,
        to day: Weekday,
        in plan: WeekPlan
    ) -> WeekPlan {
        var result = plan
        guard let index = result.slots.firstIndex(where: { $0.day == day }) else { return result }
        guard result.slots[index].recipeID != recipeID || result.slots[index].servings != servings else { return result }
        result.slots[index].recipeID = recipeID
        result.slots[index].servings = min(RecipeServingDraft.maximum, max(RecipeServingDraft.minimum, servings))
        result.revision += 1
        return result
    }

    static func updatingServings(to servings: Int, on day: Weekday, in plan: WeekPlan) -> WeekPlan {
        var result = plan
        guard let index = result.slots.firstIndex(where: { $0.day == day }), result.slots[index].recipeID != nil else {
            return result
        }
        let clamped = min(RecipeServingDraft.maximum, max(RecipeServingDraft.minimum, servings))
        guard result.slots[index].servings != clamped else { return result }
        result.slots[index].servings = clamped
        result.revision += 1
        return result
    }

    static func shoppingItems(
        plan: WeekPlan,
        recipes: [Recipe],
        checkedIngredientIDs: Set<Ingredient.ID>
    ) -> [ShoppingListItem] {
        struct Accumulator {
            let ingredient: Ingredient
            var quantities: [String]
            var cost: Money
            var contributions: [ShoppingContribution]
        }

        let lookup = recipesByID(recipes)
        var aggregated: [Ingredient.ID: Accumulator] = [:]

        for slot in plan.slots {
            guard let recipeID = slot.recipeID, let recipe = lookup[recipeID] else { continue }
            for entry in recipe.ingredients {
                let contribution = ShoppingContribution(
                    day: slot.day,
                    recipeID: recipe.id,
                    recipeTitle: recipe.title,
                    servings: slot.servings
                )
                let quantity = entry.quantity(for: slot.servings, baseServings: recipe.servings)
                let cost = entry.cost(for: slot.servings, baseServings: recipe.servings)
                if var existing = aggregated[entry.ingredient.id] {
                    existing.quantities.append(quantity)
                    existing.cost = existing.cost + cost
                    existing.contributions.append(contribution)
                    aggregated[entry.ingredient.id] = existing
                } else {
                    aggregated[entry.ingredient.id] = Accumulator(
                        ingredient: entry.ingredient,
                        quantities: [quantity],
                        cost: cost,
                        contributions: [contribution]
                    )
                }
            }
        }

        return aggregated.values.map { item in
            let quantities: String
            if item.quantities.count == 1 {
                quantities = item.quantities[0]
            } else if Set(item.quantities).count == 1 {
                quantities = "\(item.quantities[0]) × \(item.quantities.count)"
            } else {
                quantities = item.quantities.joined(separator: " + ")
            }
            return ShoppingListItem(
                ingredient: item.ingredient,
                quantityDisplay: quantities,
                estimatedCost: item.cost,
                contributions: item.contributions,
                isChecked: checkedIngredientIDs.contains(item.ingredient.id)
            )
        }
        .sorted {
            let lhsAisle = Aisle.allCases.firstIndex(of: $0.ingredient.aisle) ?? 0
            let rhsAisle = Aisle.allCases.firstIndex(of: $1.ingredient.aisle) ?? 0
            if lhsAisle == rhsAisle {
                return $0.ingredient.displayName.localizedStandardCompare($1.ingredient.displayName) == .orderedAscending
            }
            return lhsAisle < rhsAisle
        }
    }

    static func shoppingProgress(items: [ShoppingListItem]) -> ShoppingProgress {
        ShoppingProgress(checked: items.filter(\.isChecked).count, total: items.count)
    }

    static func aisleProgress(_ aisle: Aisle, items: [ShoppingListItem]) -> ShoppingProgress {
        shoppingProgress(items: items.filter { $0.ingredient.aisle == aisle })
    }
}
