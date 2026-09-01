import Foundation

enum Personalization {
    static func eligibility(of recipe: Recipe, preferences: UserPreferences) -> RecipeEligibility {
        var reasons: [EligibilityReason] = []

        for allergen in MedicalAllergen.allCases where preferences.medicalAllergens.contains(allergen) && recipe.declaredAllergens.contains(allergen) {
            reasons.append(
                EligibilityReason(
                    kind: .medicalAllergen,
                    message: "Contains declared \(allergen.rawValue.lowercased())."
                )
            )
        }

        for restriction in DietaryRestriction.allCases where preferences.dietaryRestrictions.contains(restriction) && !recipe.dietaryCompatibility.contains(restriction) {
            reasons.append(
                EligibilityReason(
                    kind: .dietaryRestriction,
                    message: "Does not meet your \(restriction.rawValue.lowercased()) setting."
                )
            )
        }

        for appliance in KitchenAppliance.allCases where recipe.requiredAppliances.contains(appliance) && !preferences.availableAppliances.contains(appliance) {
            reasons.append(
                EligibilityReason(
                    kind: .unavailableAppliance,
                    message: "Needs a \(appliance.rawValue.lowercased()), which is not selected in your kitchen."
                )
            )
        }

        return RecipeEligibility(
            recipeID: recipe.id,
            hardReasons: reasons,
            exceedsPreferredCookingTime: recipe.activeMinutes > preferences.maximumCookingMinutes
        )
    }

    static func rankedDiscoverRecipes(
        recipes: [Recipe],
        plan: WeekPlan,
        preferences: UserPreferences,
        savedRecipeIDs: Set<Recipe.ID>
    ) -> [RankedRecipe] {
        let scheduledIDs = Set(plan.slots.compactMap(\.recipeID))
        let scheduledRecipes = recipes.filter { scheduledIDs.contains($0.id) }
        let scheduledProteins = Set(scheduledRecipes.map(\.protein))
        let remaining = Planning.remainingBudget(
            plan: plan,
            recipes: recipes,
            priceBasisPoints: preferences.supermarket.priceBasisPoints
        )

        return recipes.compactMap { recipe -> RankedRecipe? in
            guard !scheduledIDs.contains(recipe.id) else { return nil }
            let eligibility = eligibility(of: recipe, preferences: preferences)
            guard eligibility.isEligible else { return nil }

            var score = 0
            var explanations: [String] = []
            var cautions: [String] = []
            let cost = recipe.estimatedCost(for: preferences.householdSize)
                .scaled(byBasisPoints: preferences.supermarket.priceBasisPoints)

            if eligibility.exceedsPreferredCookingTime {
                score -= 30
                cautions.append("\(recipe.activeMinutes) minutes is over your \(preferences.maximumCookingMinutes)-minute preference.")
            } else {
                score += 20
                explanations.append("Inside your \(preferences.maximumCookingMinutes)-minute cooking-time preference.")
            }

            if cost <= remaining {
                score += 18
                explanations.append("Fits the \(remaining.formatted()) left in this week’s budget.")
            } else {
                score -= 20
                cautions.append("Would take the current plan over budget by \((cost - remaining).formatted()).")
            }

            if preferences.preferredProteins.contains(recipe.protein) {
                score += 16
                explanations.insert("Matches your \(recipe.protein.rawValue.lowercased()) preference.", at: 0)
            }

            let matchingStyles = recipe.mealStyles.intersection(preferences.preferredMealStyles)
            if let firstStyle = MealStyle.allCases.first(where: { matchingStyles.contains($0) }) {
                score += 12
                explanations.insert("Matches your \(firstStyle.rawValue.lowercased()) meal style.", at: 0)
            }

            let disliked = recipe.ingredients.filter { preferences.dislikedIngredientIDs.contains($0.ingredient.id) }
            if let first = disliked.first {
                score -= 24
                cautions.append("Includes \(first.ingredient.displayName.lowercased()), which you marked as disliked.")
            }

            if scheduledProteins.contains(recipe.protein) {
                score -= 6
            } else {
                score += 8
                explanations.append("Adds a different main protein to this week.")
            }

            if savedRecipeIDs.contains(recipe.id) {
                score += 5
                explanations.append("You saved this recipe.")
            }

            if explanations.isEmpty {
                explanations.append(recipe.rationale)
            }

            return RankedRecipe(
                recipe: recipe,
                score: score,
                explanations: explanations,
                cautions: cautions
            )
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            let lhsIndex = recipes.firstIndex(where: { $0.id == lhs.recipe.id }) ?? 0
            let rhsIndex = recipes.firstIndex(where: { $0.id == rhs.recipe.id }) ?? 0
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return lhs.recipe.id < rhs.recipe.id
        }
    }

    static func conflicts(
        in plan: WeekPlan,
        recipes: [Recipe],
        preferences: UserPreferences
    ) -> [ScheduledPreferenceConflict] {
        let lookup = Planning.recipesByID(recipes)
        return plan.slots.compactMap { slot in
            guard let recipeID = slot.recipeID, let recipe = lookup[recipeID] else { return nil }
            let result = eligibility(of: recipe, preferences: preferences)
            guard !result.isEligible else { return nil }
            return ScheduledPreferenceConflict(day: slot.day, recipe: recipe, reasons: result.hardReasons)
        }
    }

    static func previewPreferenceUpdate(
        from current: UserPreferences,
        to proposed: UserPreferences,
        plan: WeekPlan,
        recipes: [Recipe],
        checkedIngredientIDs: Set<Ingredient.ID>
    ) -> PreferenceUpdatePreview {
        var draft = proposed
        draft.normalize()
        let lookup = Planning.recipesByID(recipes)
        let currentDays = Set(plan.slots.map(\.day))
        let proposedDays = Set(draft.cookingDays)

        let removedFilled = plan.slots.compactMap { slot -> (day: Weekday, recipeTitle: String)? in
            guard !proposedDays.contains(slot.day), let recipeID = slot.recipeID, let recipe = lookup[recipeID] else { return nil }
            return (slot.day, recipe.title)
        }

        var projected = plan
        projected.storeName = draft.supermarket.rawValue
        projected.budget = draft.weeklyBudget
        projected.slots = draft.cookingDays.map { day in
            if var existing = plan.slots.first(where: { $0.day == day }) {
                if existing.recipeID != nil, current.householdSize != draft.householdSize {
                    existing.servings = draft.householdSize
                }
                return existing
            }
            return MealSlot(day: day, recipeID: nil, servings: draft.householdSize)
        }
        if projected != plan { projected.revision = plan.revision + 1 }

        let currentSpend = Planning.weeklySpend(
            plan: plan,
            recipes: recipes,
            priceBasisPoints: current.supermarket.priceBasisPoints
        )
        let projectedSpend = Planning.weeklySpend(
            plan: projected,
            recipes: recipes,
            priceBasisPoints: draft.supermarket.priceBasisPoints
        )
        let currentItems = Planning.shoppingItems(
            plan: plan,
            recipes: recipes,
            checkedIngredientIDs: checkedIngredientIDs,
            priceBasisPoints: current.supermarket.priceBasisPoints
        )
        let projectedItems = Planning.shoppingItems(
            plan: projected,
            recipes: recipes,
            checkedIngredientIDs: checkedIngredientIDs,
            priceBasisPoints: draft.supermarket.priceBasisPoints
        )
        let currentItemsByID = Dictionary(uniqueKeysWithValues: currentItems.map { ($0.id, $0) })
        let projectedItemsByID = Dictionary(uniqueKeysWithValues: projectedItems.map { ($0.id, $0) })
        let shoppingChangeCount = Set(currentItemsByID.keys).union(projectedItemsByID.keys).filter { id in
            currentItemsByID[id]?.quantityDisplay != projectedItemsByID[id]?.quantityDisplay
                || currentItemsByID[id]?.estimatedCost != projectedItemsByID[id]?.estimatedCost
        }.count

        return PreferenceUpdatePreview(
            draft: draft,
            projectedPlan: projected,
            conflicts: conflicts(in: projected, recipes: recipes, preferences: draft),
            removedFilledSlots: removedFilled,
            addedDays: Weekday.allCases.filter { proposedDays.contains($0) && !currentDays.contains($0) },
            removedDays: Weekday.allCases.filter { currentDays.contains($0) && !proposedDays.contains($0) },
            servingChangeCount: projected.slots.filter { slot in
                guard slot.recipeID != nil, let old = plan.slots.first(where: { $0.day == slot.day }) else { return false }
                return old.servings != slot.servings
            }.count,
            currentSpend: currentSpend,
            projectedSpend: projectedSpend,
            currentShoppingItemCount: currentItems.count,
            projectedShoppingItemCount: projectedItems.count,
            shoppingChangeCount: shoppingChangeCount
        )
    }

    static func autofill(
        plan: WeekPlan,
        recipes: [Recipe],
        preferences: UserPreferences,
        savedRecipeIDs: Set<Recipe.ID>
    ) -> AutofillOutcome {
        let openSlots = Planning.openSlots(in: plan)
        guard !openSlots.isEmpty else {
            return .unable(message: "Every configured cooking day already has a dinner.", suggestions: [])
        }

        let scheduled = Set(plan.slots.compactMap(\.recipeID))
        let eligible = recipes.filter { recipe in
            !scheduled.contains(recipe.id)
                && eligibility(of: recipe, preferences: preferences).isEligible
                && recipe.activeMinutes <= preferences.maximumCookingMinutes
        }

        guard eligible.count >= openSlots.count else {
            return .unable(
                message: "There aren’t enough different recipes that meet every hard rule and your cooking-time limit.",
                suggestions: ["Review allergens or dietary settings", "Add an available appliance", "Increase maximum cooking time"]
            )
        }

        let ranked = rankedDiscoverRecipes(
            recipes: recipes,
            plan: plan,
            preferences: preferences,
            savedRecipeIDs: savedRecipeIDs
        ).filter { $0.recipe.activeMinutes <= preferences.maximumCookingMinutes }
        let scoreByID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.id, $0.score) })
        let existingSpend = Planning.weeklySpend(
            plan: plan,
            recipes: recipes,
            priceBasisPoints: preferences.supermarket.priceBasisPoints
        )

        var combinations: [[Recipe]] = []
        buildCombinations(from: eligible, choosing: openSlots.count, start: 0, current: [], output: &combinations)
        let valid = combinations.compactMap { selection -> (recipes: [Recipe], spend: Money, score: Int)? in
            let added = selection.reduce(Money.zero()) { total, recipe in
                total + recipe.estimatedCost(for: preferences.householdSize)
                    .scaled(byBasisPoints: preferences.supermarket.priceBasisPoints)
            }
            let spend = existingSpend + added
            guard spend <= plan.budget else { return nil }
            let variety = Set(selection.map(\.protein)).count * 7
            let score = selection.reduce(variety) { $0 + (scoreByID[$1.id] ?? 0) }
            return (selection, spend, score)
        }

        guard let winner = valid.sorted(by: { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.spend != rhs.spend { return lhs.spend < rhs.spend }
            return lhs.recipes.map(\.id).joined(separator: "|") < rhs.recipes.map(\.id).joined(separator: "|")
        }).first else {
            return .unable(
                message: "No eligible combination fits the money left in this week’s budget.",
                suggestions: ["Increase weekly budget", "Reduce household size", "Choose one dinner manually"]
            )
        }

        let recipeOrder = Dictionary(uniqueKeysWithValues: ranked.enumerated().map { ($0.element.id, $0.offset) })
        let orderedWinner = winner.recipes.sorted {
            (recipeOrder[$0.id] ?? .max) < (recipeOrder[$1.id] ?? .max)
        }
        var completed = plan
        var assignments: [ShoppingContribution] = []
        for (slot, recipe) in zip(openSlots, orderedWinner) {
            completed = Planning.assigning(
                recipeID: recipe.id,
                servings: preferences.householdSize,
                to: slot.day,
                in: completed
            )
            assignments.append(
                ShoppingContribution(
                    day: slot.day,
                    recipeID: recipe.id,
                    recipeTitle: recipe.title,
                    servings: preferences.householdSize
                )
            )
        }
        return .success(plan: completed, assignments: assignments, projectedSpend: winner.spend)
    }

    private static func buildCombinations(
        from recipes: [Recipe],
        choosing count: Int,
        start: Int,
        current: [Recipe],
        output: inout [[Recipe]]
    ) {
        if current.count == count {
            output.append(current)
            return
        }
        guard start < recipes.count else { return }
        let remainingNeeded = count - current.count
        guard recipes.count - start >= remainingNeeded else { return }
        for index in start...recipes.count - remainingNeeded {
            buildCombinations(
                from: recipes,
                choosing: count,
                start: index + 1,
                current: current + [recipes[index]],
                output: &output
            )
        }
    }
}
