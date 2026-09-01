import Foundation

enum WeeknightFixture {
    static let currencyCode = "USD"

    static func money(_ cents: Int) -> Money {
        Money(minorUnits: cents, currencyCode: currencyCode)
    }

    private static func item(
        _ id: String,
        _ name: String,
        _ aisle: Aisle,
        _ quantity: String,
        _ cents: Int
    ) -> RecipeIngredient {
        RecipeIngredient(
            ingredient: Ingredient(id: id, canonicalName: id, displayName: name, aisle: aisle),
            quantity: quantity,
            estimatedCost: money(cents)
        )
    }

    static let recipes: [Recipe] = [
        Recipe(
            id: "honeysoy",
            title: "Honey Soy Chicken & Broccoli",
            sourceName: "Sift & Simmer",
            activeMinutes: 25,
            servings: 1,
            tags: ["Fakeaway", "Protein-packed"],
            rationale: "One pan, and it uses the soy and honey already on your list.",
            ingredients: [
                item("chicken-thighs", "Chicken thighs", .meatAndFish, "500g", 620),
                item("broccoli", "Broccoli", .produce, "1 head", 190),
                item("honey", "Honey", .pantry, "2 tbsp", 60),
                item("soy-sauce", "Soy sauce", .pantry, "3 tbsp", 50),
                item("jasmine-rice", "Jasmine rice", .pantry, "150g", 120),
                item("garlic", "Garlic", .produce, "3 cloves", 35),
                item("sesame-seeds", "Sesame seeds", .pantry, "1 tsp", 25),
                item("spring-onions", "Spring onions", .produce, "2", 60),
            ],
            artwork: .honeySoy,
            methodSteps: [
                "Cook the rice until tender, then cover and keep warm.",
                "Brown the chicken in a wide pan, add broccoli, garlic, soy and honey, and simmer until glossy and cooked through.",
                "Spoon over the rice and finish with spring onions and sesame seeds.",
            ]
        ),
        Recipe(
            id: "chilli",
            title: "Smoky Chilli Con Carne",
            sourceName: "Cook Republic",
            activeMinutes: 45,
            servings: 1,
            tags: ["Healthy comfort", "Batch friendly"],
            rationale: "Makes a second portion for Thursday lunch at no extra cost.",
            ingredients: [
                item("beef-mince", "Beef mince", .meatAndFish, "400g", 640),
                item("kidney-beans", "Kidney beans", .pantry, "1 tin", 110),
                item("chopped-tomatoes", "Chopped tomatoes", .pantry, "1 tin", 95),
                item("onion", "Onion", .produce, "1", 45),
                item("red-pepper", "Red pepper", .produce, "1", 95),
                item("chipotle-paste", "Chipotle paste", .pantry, "1 tbsp", 90),
                item("ground-cumin", "Ground cumin", .pantry, "1 tsp", 30),
                item("sour-cream", "Sour cream", .chilledAndDairy, "1 pot", 165),
                item("long-grain-rice", "Long-grain rice", .pantry, "150g", 90),
            ],
            artwork: .chilli,
            methodSteps: [
                "Soften the onion and pepper, then brown the beef mince.",
                "Stir in chipotle and cumin, add tomatoes and beans, and simmer until thick.",
                "Serve with rice and a spoonful of sour cream.",
            ]
        ),
        Recipe(
            id: "stirfry",
            title: "Ginger Rice Noodle Stir-Fry",
            sourceName: "Wok & Kin",
            activeMinutes: 20,
            servings: 1,
            tags: ["Speedy", "Meat-free"],
            rationale: "Under 20 minutes and the lightest dinner already on your plan.",
            ingredients: [
                item("rice-noodles", "Rice noodles", .pantry, "200g", 180),
                item("firm-tofu", "Firm tofu", .chilledAndDairy, "280g", 290),
                item("ginger", "Ginger", .produce, "1 thumb", 55),
                item("garlic", "Garlic", .produce, "3 cloves", 35),
                item("tenderstem-broccoli", "Tenderstem broccoli", .produce, "200g", 220),
                item("carrot", "Carrot", .produce, "1", 35),
                item("soy-sauce", "Soy sauce", .pantry, "2 tbsp", 35),
                item("sesame-oil", "Sesame oil", .pantry, "1 tbsp", 45),
                item("lime", "Lime", .produce, "1", 45),
                item("crispy-shallots", "Crispy shallots", .pantry, "30g", 80),
            ],
            artwork: .stirFry,
            methodSteps: [
                "Soak or cook the noodles according to the packet, then drain well.",
                "Crisp the tofu, then stir-fry the vegetables with ginger and garlic.",
                "Toss everything with soy, sesame oil and lime; top with crispy shallots.",
            ]
        ),
        Recipe(
            id: "carbonara",
            title: "Proper Carbonara",
            sourceName: "Bon Appétit",
            activeMinutes: 20,
            servings: 1,
            tags: ["Speedy", "Five ingredients"],
            rationale: "The lowest-cost way to fill an open night this week.",
            ingredients: [
                item("spaghetti", "Spaghetti", .pantry, "125g", 70),
                item("pancetta", "Pancetta", .meatAndFish, "100g", 310),
                item("eggs", "Eggs", .chilledAndDairy, "2", 70),
                item("pecorino", "Pecorino", .chilledAndDairy, "40g", 220),
                item("black-pepper", "Black pepper", .pantry, "1 tsp", 25),
                item("parmesan", "Parmesan", .chilledAndDairy, "20g", 195),
            ],
            artwork: .carbonara,
            methodSteps: [
                "Cook the spaghetti in salted water and reserve a mug of pasta water.",
                "Crisp the pancetta while whisking the eggs, pecorino, parmesan and black pepper in a bowl.",
                "Off the heat, toss hot pasta with the egg mixture and enough pasta water to make a silky sauce.",
            ]
        ),
        Recipe(
            id: "curry",
            title: "Weeknight Chicken Curry",
            sourceName: "Meera Sodha",
            activeMinutes: 40,
            servings: 1,
            tags: ["Healthy comfort", "Freezes well"],
            rationale: "A familiar, comforting finish to the week that stays inside budget.",
            ingredients: [
                item("chicken-thighs", "Chicken thighs", .meatAndFish, "400g", 520),
                item("onion", "Onion", .produce, "1", 45),
                item("garlic", "Garlic", .produce, "3 cloves", 35),
                item("ginger", "Ginger", .produce, "1 thumb", 55),
                item("curry-powder", "Curry powder", .pantry, "2 tbsp", 80),
                item("chopped-tomatoes", "Chopped tomatoes", .pantry, "1 tin", 95),
                item("coconut-milk", "Coconut milk", .pantry, "1 tin", 160),
                item("basmati-rice", "Basmati rice", .pantry, "150g", 120),
                item("coriander", "Coriander", .produce, "1 bunch", 90),
                item("spinach", "Spinach", .produce, "100g", 40),
            ],
            artwork: .curry,
            methodSteps: [
                "Soften the onion, then add garlic, ginger and curry powder until fragrant.",
                "Brown the chicken, add tomatoes and coconut milk, and simmer until the chicken is cooked through.",
                "Fold in the spinach and serve with basmati rice and coriander.",
            ]
        ),
        Recipe(
            id: "caesar",
            title: "Charred Chicken Caesar",
            sourceName: "Delish",
            activeMinutes: 25,
            servings: 1,
            tags: ["Low calorie", "Protein-packed"],
            rationale: "Matches the high-protein, lighter dinners you keep choosing.",
            ingredients: [
                item("chicken-breast", "Chicken breast", .meatAndFish, "250g", 420),
                item("romaine", "Romaine lettuce", .produce, "1", 155),
                item("parmesan", "Parmesan", .chilledAndDairy, "40g", 185),
                item("sourdough", "Sourdough", .pantry, "2 slices", 80),
                item("anchovies", "Anchovies", .pantry, "3 fillets", 65),
                item("egg", "Egg", .chilledAndDairy, "1", 35),
                item("lemon", "Lemon", .produce, "1", 40),
            ],
            artwork: .caesar,
            methodSteps: [
                "Char the chicken until golden and cooked through, then rest and slice.",
                "Toast the sourdough and whisk a dressing from anchovy, egg, lemon and parmesan.",
                "Toss the romaine with dressing and croutons, then top with chicken.",
            ]
        ),
        Recipe(
            id: "chopped",
            title: "Big Chopped Salad",
            sourceName: "Downshiftology",
            activeMinutes: 15,
            servings: 1,
            tags: ["Speedy", "Meat-free"],
            rationale: "No cooking at all, for the night you get home late.",
            ingredients: [
                item("cucumber", "Cucumber", .produce, "1", 85),
                item("cherry-tomatoes", "Cherry tomatoes", .produce, "250g", 195),
                item("chickpeas", "Chickpeas", .pantry, "1 tin", 95),
                item("feta", "Feta", .chilledAndDairy, "100g", 235),
                item("red-onion", "Red onion", .produce, "1", 40),
                item("green-olives", "Green olives", .pantry, "80g", 145),
                item("dill", "Dill", .produce, "1 bunch", 85),
                item("red-wine-vinegar", "Red wine vinegar", .pantry, "1 tbsp", 30),
                item("sunflower-seeds", "Sunflower seeds", .pantry, "20g", 30),
            ],
            artwork: .chopped,
            methodSteps: [
                "Chop the cucumber, tomatoes, onion and dill into bite-sized pieces.",
                "Drain the chickpeas and toss with the vegetables, olives and sunflower seeds.",
                "Dress with red wine vinegar, fold in the feta, and season to taste.",
            ]
        ),
        Recipe(
            id: "steak",
            title: "Steak Frites, Chimichurri",
            sourceName: "Serious Eats",
            activeMinutes: 35,
            servings: 1,
            tags: ["Treat night", "Protein-packed"],
            rationale: "A Friday treat that still fits when the rest of the week is lean.",
            ingredients: [
                item("sirloin-steak", "Sirloin steak", .meatAndFish, "250g", 1_150),
                item("potatoes", "Potatoes", .produce, "400g", 110),
                item("parsley", "Parsley", .produce, "1 bunch", 85),
                item("coriander", "Coriander", .produce, "1 bunch", 85),
                item("red-wine-vinegar", "Red wine vinegar", .pantry, "2 tbsp", 45),
                item("garlic", "Garlic", .produce, "2 cloves", 25),
                item("olive-oil", "Olive oil", .pantry, "3 tbsp", 60),
                item("chilli-flakes", "Chilli flakes", .pantry, "1 tsp", 20),
                item("rocket", "Rocket", .produce, "60g", 135),
                item("beef-dripping", "Beef dripping", .chilledAndDairy, "1 tbsp", 160),
            ],
            artwork: .steak,
            methodSteps: [
                "Cut the potatoes into fries and roast until crisp.",
                "Mix parsley, coriander, garlic, vinegar, chilli and olive oil for the chimichurri.",
                "Sear the steak to your preferred doneness, rest it, then serve with fries, rocket and chimichurri.",
            ]
        ),
    ]

    static var initialPlan: WeekPlan {
        WeekPlan(
            id: "week-2026-08-31",
            weekLabel: "Mon 31 Aug – Sun 6 Sep",
            storeName: "Trader Joe's",
            budget: money(8_000),
            slots: [
                MealSlot(day: .monday, recipeID: "honeysoy"),
                MealSlot(day: .tuesday, recipeID: "chilli"),
                MealSlot(day: .wednesday, recipeID: "stirfry"),
                MealSlot(day: .thursday, recipeID: nil),
                MealSlot(day: .friday, recipeID: nil),
            ],
            revision: 1
        )
    }

    static let initialCheckedIngredientIDs: Set<Ingredient.ID> = [
        "jasmine-rice", "soy-sauce", "garlic",
    ]

    static let initialSavedRecipeRecords: [SavedRecipeRecord] = [
        SavedRecipeRecord(recipeID: "curry", savedAt: Date(timeIntervalSince1970: 1_788_267_600)),
        SavedRecipeRecord(recipeID: "caesar", savedAt: Date(timeIntervalSince1970: 1_788_264_000)),
        SavedRecipeRecord(recipeID: "chopped", savedAt: Date(timeIntervalSince1970: 1_788_260_400)),
    ]

    static var canonicalSnapshot: AppSnapshot {
        AppSnapshot(
            plan: initialPlan,
            checkedIngredientIDs: initialCheckedIngredientIDs,
            savedRecipeRecords: initialSavedRecipeRecords,
            recipeNotes: [:]
        )
    }

    static let preferences = UserPreferences(
        storeName: "Trader Joe's",
        householdSize: 1,
        cookingDays: Weekday.allCases,
        weeklyBudget: money(8_000)
    )
}
