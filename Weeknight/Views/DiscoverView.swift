import SwiftUI

struct ForYouMealsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var query = ""
    @State private var stylesExpanded = false
    @State private var addRecipe: Recipe?
    @State private var detailRecipeID: Recipe.ID?
    @State private var selectedCuisine: Cuisine?
    @State private var selectedStyle: MealStyle?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        _stylesExpanded = State(initialValue: arguments.contains("--meals-expanded-styles"))
        _selectedCuisine = State(initialValue: arguments.contains("--meals-cuisine-asian") ? .asian : nil)
    }

    private var searchResults: [Recipe] { store.exploreRecipes(matching: query) }
    private var visibleStyles: [MealStyle] {
        stylesExpanded ? store.orderedMealStyles : Array(store.orderedMealStyles.prefix(2))
    }

    var body: some View {
        Group {
            switch store.recipeMode {
            case .loading:
                loadingState
            case .error:
                MealsStatePanel(
                    icon: "wifi.exclamationmark",
                    title: "Meals didn’t load",
                    message: "Your Saved meals and weekly plan are still available on this iPhone.",
                    action: "Try again"
                ) { Task { await store.retryRecipes() } }
            case .empty:
                MealsStatePanel(
                    icon: "fork.knife",
                    title: "No meals yet",
                    message: "There is nothing in this recipe source right now.",
                    action: "Back to Plans"
                ) { navigation.showPlans() }
            case .ready, .stale:
                if store.eligibleMealsCatalogue.isEmpty {
                    MealsStatePanel(
                        icon: "checkmark.shield",
                        title: "No meals meet every hard rule",
                        message: "Medical and dietary rules were not weakened. Review Preferences to change your rules.",
                        action: "Review Preferences",
                        identifier: "explore-no-eligible-results"
                    ) { navigation.showPreferences() }
                } else {
                    explore
                }
            }
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .sheet(item: $addRecipe) { recipe in
            AddToWeekSheet(recipe: recipe, servings: store.preferences.householdSize)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(WeeknightTheme.Radius.sheet)
        }
        .navigationDestination(item: $detailRecipeID) { recipeID in
            RecipeDetailsView(
                recipeID: recipeID,
                origin: .discover,
                initialServings: store.scheduledSlot(for: recipeID)?.servings ?? store.preferences.householdSize
            )
        }
        .navigationDestination(item: $selectedCuisine) { cuisine in
            CuisineResultsView(cuisine: cuisine)
        }
        .navigationDestination(item: $selectedStyle) { style in
            StyleResultsView(style: style)
        }
        .task { await store.loadRecipesIfNeeded() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("explore-meals")
    }

    private var explore: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if showsBackendRecovery {
                    BackendStatusView(onDark: false)
                        .padding(.bottom, 14)
                }

                MealsSearchField(
                    query: $query,
                    prompt: "Search meals and ingredients…",
                    identifier: "for-you-search",
                    accessibilityLabel: "Search Explore meals",
                    accessibilityHint: "Searches titles, cuisines, ingredients, tags, and styles."
                )
                .padding(.bottom, 20)

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    stylesSection
                    cuisineSection
                } else if searchResults.isEmpty {
                    MealsStatePanel(
                        icon: "magnifyingglass",
                        title: "No meals found",
                        message: "Try another title, cuisine, ingredient, tag, or style.",
                        action: "Clear search",
                        identifier: "explore-no-search-results"
                    ) { query = "" }
                    .frame(minHeight: 360)
                } else {
                    searchResultsSection
                }
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.bottom, WeeknightTheme.Spacing.xLarge)
        }
        .scrollIndicators(.hidden)
    }

    private var stylesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your styles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.secondaryText)
                    stylesToggleButton
                }
            } else {
                HStack(alignment: .center) {
                    Text("Your styles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.secondaryText)
                    Spacer(minLength: 12)
                    stylesToggleButton
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    ForEach(visibleStyles) { style in
                        styleCard(style)
                    }
                }
            } else {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    ForEach(Array(stride(from: 0, to: visibleStyles.count, by: 2)), id: \.self) { index in
                        if index + 1 < visibleStyles.count {
                            GridRow {
                                styleCard(visibleStyles[index])
                                styleCard(visibleStyles[index + 1])
                            }
                        } else {
                            GridRow {
                                styleCard(visibleStyles[index])
                                    .frame(maxWidth: 220)
                                    .gridCellColumns(2)
                            }
                        }
                    }
                }
            }
        }
        .padding(.bottom, 24)
    }

    private var stylesToggleButton: some View {
        Button {
            stylesExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(stylesExpanded ? "Show less" : "See all \(MealStyle.allCases.count)")
                if !stylesExpanded { Image(systemName: "arrow.right") }
            }
            .font(.headline.weight(.bold))
            .frame(minHeight: 44)
        }
        .foregroundStyle(WeeknightTheme.forest)
        .accessibilityLabel(stylesExpanded ? "Show fewer meal styles" : "See all seven meal styles")
        .accessibilityValue(stylesExpanded ? "Expanded" : "Collapsed")
        .accessibilityIdentifier("styles-toggle")
    }

    private func styleCard(_ style: MealStyle) -> some View {
        let preferred = store.preferences.preferredMealStyles.contains(style)
        return Button {
            selectedStyle = style
        } label: {
            VStack(spacing: 7) {
                Image(systemName: style.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.forest)
                    .accessibilityHidden(true)
                Text(style.browseLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if preferred {
                    Label("Preferred", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.forest)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 132 : 88)
            .background(WeeknightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous)
                    .stroke(preferred ? WeeknightTheme.forest : WeeknightTheme.hairline, lineWidth: preferred ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Browse \(style.browseLabel) meals")
        .accessibilityValue(preferred ? "Preferred style" : "Not selected in Preferences")
        .accessibilityAddTraits(preferred ? .isSelected : [])
        .accessibilityIdentifier("style-\(style.id)")
    }

    @ViewBuilder
    private var cuisineSection: some View {
        if store.cuisineSummaries.isEmpty {
            MealsStatePanel(
                icon: "arrow.clockwise",
                title: "Cuisine information needs a refresh",
                message: "You can still search every eligible meal while Weeknight refreshes the catalogue.",
                action: "Try again"
            ) { Task { await store.retryRecipes() } }
            .accessibilityIdentifier("cuisine-metadata-unavailable")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Browse by cuisine")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .accessibilityIdentifier("cuisine-grid")
                    Spacer()
                    Text("All \(store.cuisineSummaries.count)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.forest)
                }

                LazyVGrid(columns: cuisineColumns, spacing: 14) {
                    ForEach(store.cuisineSummaries) { summary in
                        cuisineCard(summary)
                    }
                }
            }
        }
    }

    private var cuisineColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 14)]
            : [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    }

    private func cuisineCard(_ summary: CuisineSummary) -> some View {
        let recipe = store.eligibleMealsCatalogue.first { $0.id == summary.representativeRecipeID }
        return Button {
            selectedCuisine = summary.cuisine
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let recipe {
                    RecipeArtwork(style: recipe.artwork, compact: true)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 158 : 116)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: WeeknightTheme.Radius.row,
                                topTrailingRadius: WeeknightTheme.Radius.row
                            )
                        )
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.cuisine.rawValue)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Text(summary.cuisine.examples)
                        .font(.subheadline)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(summary.mealCount) \(summary.mealCount == 1 ? "meal" : "meals") · from \(summary.lowestPrice.formatted())")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.forest)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WeeknightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous)
                    .stroke(WeeknightTheme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(summary.cuisine.rawValue) cuisine, \(summary.mealCount) meals, from \(summary.lowestPrice.formatted())")
        .accessibilityHint("Opens eligible \(summary.cuisine.rawValue) meals")
        .accessibilityIdentifier("cuisine-\(summary.cuisine.id)")
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(searchResults.count) \(searchResults.count == 1 ? "meal" : "meals") inside your rules")
                .font(.headline.weight(.semibold))
                .foregroundStyle(WeeknightTheme.secondaryText)
                .padding(.bottom, 8)
                .accessibilityIdentifier("explore-result-count")
            ForEach(searchResults) { recipe in
                MealCompactRow(
                    recipe: recipe,
                    onOpen: { detailRecipeID = recipe.id },
                    onAdd: { addRecipe = recipe }
                )
                Divider().overlay(WeeknightTheme.hairline)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(WeeknightTheme.forest)
            Text(store.backendState == .local ? "Loading meals…" : "Loading validated meals…")
                .font(.headline)
                .foregroundStyle(WeeknightTheme.primaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading meals")
    }

    private var showsBackendRecovery: Bool {
        switch store.backendState {
        case .fallback, .cached, .unavailable: true
        case .local, .loading, .connected: false
        }
    }
}

struct CuisineResultsView: View {
    let cuisine: Cuisine

    var body: some View {
        MealBrowseResultsView(collection: .cuisine(cuisine))
    }
}

struct StyleResultsView: View {
    let style: MealStyle

    var body: some View {
        MealBrowseResultsView(collection: .style(style))
    }
}

enum MealBrowseCollection: Hashable {
    case cuisine(Cuisine)
    case style(MealStyle)

    var title: String {
        switch self {
        case .cuisine(let cuisine): cuisine.rawValue
        case .style(let style): style.browseLabel
        }
    }

    var searchPrompt: String { "Search \(title) meals…" }
    var identifier: String {
        switch self {
        case .cuisine(let cuisine): "cuisine-results-\(cuisine.id)"
        case .style(let style): "style-results-\(style.id)"
        }
    }
}

struct MealBrowseResultsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let collection: MealBrowseCollection
    @State private var query = ""
    @State private var sort: MealBrowseSort = .cheapest
    @State private var addRecipe: Recipe?
    @State private var detailRecipeID: Recipe.ID?

    private var allResults: [Recipe] { recipes(matching: "") }
    private var results: [Recipe] { recipes(matching: query) }

    var body: some View {
        VStack(spacing: 0) {
            MealsSearchField(
                query: $query,
                prompt: collection.searchPrompt,
                identifier: "browse-search",
                accessibilityLabel: "Search \(collection.title) meals"
            )
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.vertical, 14)

            HStack(alignment: .center, spacing: 10) {
                Text(resultCountLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("browse-result-count")
                Spacer(minLength: 8)
                Menu {
                    Picker("Sort meals", selection: $sort) {
                        ForEach(MealBrowseSort.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.forest)
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("Sort meals, \(sort.rawValue)")
                .accessibilityIdentifier("browse-sort")
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            Divider().overlay(WeeknightTheme.hairline)

            if results.isEmpty {
                MealsStatePanel(
                    icon: "magnifyingglass",
                    title: "No meals found",
                    message: "Try another title, ingredient, tag, or style.",
                    action: "Clear search"
                ) { query = "" }
                .accessibilityIdentifier("browse-no-results")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { recipe in
                            MealCompactRow(
                                recipe: recipe,
                                onOpen: { detailRecipeID = recipe.id },
                                onAdd: { addRecipe = recipe }
                            )
                            Divider().overlay(WeeknightTheme.hairline)
                        }
                    }
                    .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                    .padding(.bottom, WeeknightTheme.Spacing.xLarge)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Label("Meals", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(.headline)
                }
                .accessibilityLabel("Back to Meals")
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(WeeknightTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $addRecipe) { recipe in
            AddToWeekSheet(recipe: recipe, servings: store.preferences.householdSize)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(WeeknightTheme.Radius.sheet)
        }
        .navigationDestination(item: $detailRecipeID) { recipeID in
            RecipeDetailsView(
                recipeID: recipeID,
                origin: .discover,
                initialServings: store.scheduledSlot(for: recipeID)?.servings ?? store.preferences.householdSize
            )
        }
    }

    private var resultCountLabel: String {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(allResults.count) \(allResults.count == 1 ? "meal" : "meals") inside your rules"
        }
        return "\(results.count) of \(allResults.count) meals"
    }

    private func recipes(matching query: String) -> [Recipe] {
        switch collection {
        case .cuisine(let cuisine): store.cuisineRecipes(cuisine, matching: query, sort: sort)
        case .style(let style): store.styleRecipes(style, matching: query, sort: sort)
        }
    }
}

struct MealCompactRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let recipe: Recipe
    let onOpen: () -> Void
    let onAdd: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    recipeButton
                    addButton(compact: false)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    recipeButton
                    addButton(compact: true)
                }
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .contain)
    }

    private var recipeButton: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                RecipeArtwork(style: recipe.artwork, compact: true)
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize ? 82 : 62,
                        height: dynamicTypeSize.isAccessibilitySize ? 82 : 62
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(recipe.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("discover-title-\(recipe.id)")
                    FlowLayout(spacing: 6) {
                        ForEach(relevantStyles, id: \.self) { style in
                            CompactStyleTag(text: style.browseLabel)
                        }
                    }
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let slot = store.scheduledSlot(for: recipe.id) {
                        Text("Already planned for \(slot.day.rawValue)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WeeknightTheme.forest)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Already planned for \(slot.day.rawValue)")
                            .accessibilityIdentifier("planned-recipe-\(recipe.id)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recipeAccessibilityLabel)
        .accessibilityHint("Opens Recipe Details")
        .accessibilityIdentifier("discover-details-\(recipe.id)")
    }

    private func addButton(compact: Bool) -> some View {
        Button(action: onAdd) {
            Group {
                if compact {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .frame(width: 58, height: 58)
                } else {
                    Label("Add to Plan", systemImage: "plus")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .foregroundStyle(WeeknightTheme.forest)
            .background(WeeknightTheme.wash)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(WeeknightTheme.forest.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Add \(recipe.title) to plan.")
        .accessibilityHint("Opens day selection and replacement options")
        .accessibilityIdentifier("add-recipe-\(recipe.id)")
    }

    private var relevantStyles: [MealStyle] {
        MealStyle.allCases.filter(recipe.mealStyles.contains).prefix(2).map { $0 }
    }

    private var metadata: String {
        let servings = store.preferences.householdSize
        let servingLabel = servings == 1 ? "1 serving" : "\(servings) servings"
        return "\(recipe.activeMinutes) min · \(servingLabel) · \(store.estimatedCost(for: recipe, servings: servings).formatted())"
    }

    private var recipeAccessibilityLabel: String {
        let scheduled = store.scheduledSlot(for: recipe.id).map { ", already planned for \($0.day.rawValue)" } ?? ""
        return "\(recipe.title), \(metadata)\(scheduled)"
    }
}

struct CompactStyleTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(WeeknightTheme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(WeeknightTheme.hairline, lineWidth: 1)
            }
    }
}

struct MealsSearchField: View {
    @Binding var query: String
    let prompt: String
    let identifier: String
    let accessibilityLabel: String
    var accessibilityHint: String = "Filters the available meals."

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(WeeknightTheme.secondaryText)
                .accessibilityHidden(true)
            TextField(prompt, text: $query)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint(accessibilityHint)
                .accessibilityIdentifier(identifier)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(WeeknightTheme.secondaryText)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 16)
        .frame(minHeight: 52)
        .background(WeeknightTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
    }
}

struct MealsStatePanel: View {
    let icon: String
    let title: String
    let message: String
    let action: String
    var identifier: String? = nil
    let perform: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(WeeknightTheme.forest)
                .accessibilityHidden(true)
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(WeeknightTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier ?? title)
            Text(message)
                .font(.body)
                .foregroundStyle(WeeknightTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button(action, action: perform)
                .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct LegacyDiscoverFeedView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedRecipe: Recipe?
    @State private var detailRecipeID: Recipe.ID?
    @State private var visibleRecipeID: Recipe.ID?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                WeeknightTheme.deepestPine.ignoresSafeArea()
                content(size: proxy.size)
                if store.recipeMode == .ready || store.recipeMode == .stale,
                   !store.discoverRecipes.isEmpty {
                    VStack(spacing: 7) {
                        Text("LEGACY DISCOVER · DEBUG")
                            .font(.caption2.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(WeeknightTheme.photoText)
                            .accessibilityLabel("Legacy Discover feed")
                            .accessibilityIdentifier("legacy-discover-feed")
                        progressHeader
                        if showsBackendStatus { BackendStatusView(onDark: true) }
                    }
                    .padding(.horizontal, WeeknightTheme.Spacing.gutter)
                    .padding(.top, 8)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedRecipe) { recipe in
            AddToWeekSheet(recipe: recipe, servings: store.preferences.householdSize)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(WeeknightTheme.Radius.sheet)
        }
        .navigationDestination(item: $detailRecipeID) { recipeID in
            RecipeDetailsView(
                recipeID: recipeID,
                origin: .discover,
                initialServings: store.preferences.householdSize
            )
        }
        .task {
            await store.loadRecipesIfNeeded()
            if visibleRecipeID == nil { visibleRecipeID = store.rankedDiscoverRecipes.first?.id }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        switch store.recipeMode {
        case .loading:
            loadingState
        case .error:
            statePanel(
                icon: "wifi.exclamationmark",
                title: "Recipes didn’t load",
                message: "Your local week is safe. Try again to restore the feed.",
                action: "Try again"
            ) { Task { await store.retryRecipes() } }
        case .empty:
            statePanel(
                icon: "fork.knife",
                title: "No recipes yet",
                message: "There is nothing in this recipe source right now.",
                action: "Back to Plan"
            ) { navigation.showPlans() }
        case .ready, .stale:
            if store.discoverRecipes.isEmpty {
                noResultsState
            } else {
                recipePages(size: size)
            }
        }
    }

    @ViewBuilder
    private func recipePages(size: CGSize) -> some View {
        let pages = ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.rankedDiscoverRecipes.enumerated()), id: \.element.id) { index, ranked in
                    RecipeFeedPage(
                        ranked: ranked,
                        position: index,
                        count: store.rankedDiscoverRecipes.count,
                        onDetails: { detailRecipeID = ranked.recipe.id },
                        onAdd: { selectedRecipe = ranked.recipe }
                    )
                    .frame(width: size.width, height: size.height)
                    .id(ranked.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollPosition(id: $visibleRecipeID)
        .accessibilityLabel("Recipe discovery feed")

        if reduceMotion {
            pages.scrollTargetBehavior(.viewAligned)
        } else {
            pages.scrollTargetBehavior(.paging)
        }
    }

    @ViewBuilder
    private var noResultsState: some View {
        let scheduled = Set(store.plan.slots.compactMap(\.recipeID))
        let unscheduled = store.recipes.filter { !scheduled.contains($0.id) }
        if unscheduled.isEmpty {
            statePanel(
                icon: "checkmark.circle.fill",
                title: "Every dinner is planned",
                message: "Your active week already contains every available recipe.",
                action: "See the plan"
            ) { navigation.showPlans() }
        } else {
            statePanel(
                icon: "slider.horizontal.3",
                title: "No recipes meet every hard rule",
                message: "The remaining recipes conflict with your current eligibility settings. Hard rules were not weakened.",
                action: "Review Preferences"
            ) { navigation.showPreferences() }
            .accessibilityIdentifier("discover-no-results")
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.28))
                    Capsule()
                        .fill(WeeknightTheme.leaf)
                        .frame(width: proxy.size.width * Double(store.filledCount) / Double(max(1, store.totalCount)))
                }
            }
            .frame(height: 3)
            Text("\(store.weeklySpend.formatted()) / \(store.plan.budget.formatted())")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(WeeknightTheme.photoText)
                .lineLimit(1)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.filledCount) of \(store.totalCount) dinners chosen, \(store.weeklySpend.formatted()) of \(store.plan.budget.formatted())")
        .accessibilityIdentifier("discover-progress")
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(WeeknightTheme.leaf)
            Text(store.backendState == .local ? "Loading local recipes…" : "Loading validated recipes…")
                .font(.headline)
                .foregroundStyle(WeeknightTheme.photoText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading recipes")
    }

    private func statePanel(
        icon: String,
        title: String,
        message: String,
        action: String,
        perform: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(WeeknightTheme.leaf)
            Text(title)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(WeeknightTheme.photoText)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.body)
                .foregroundStyle(WeeknightTheme.photoText.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
            Button(action, action: perform)
                .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(WeeknightTheme.Spacing.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var showsBackendStatus: Bool {
        if case .local = store.backendState { return false }
        return true
    }
}

private struct RecipeFeedPage: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let ranked: RankedRecipe
    let position: Int
    let count: Int
    let onDetails: () -> Void
    let onAdd: () -> Void

    private var recipe: Recipe { ranked.recipe }
    private var servings: Int { store.preferences.householdSize }
    private var cost: Money { store.estimatedCost(for: recipe, servings: servings) }
    private var firstOpenDay: Weekday? { store.plan.slots.first(where: { $0.recipeID == nil })?.day }
    private var targetText: String { firstOpenDay.map { "FOR \($0.rawValue.uppercased())" } ?? "FOR YOUR WEEK" }
    private var addText: String { firstOpenDay.map { "Add to \($0.rawValue)" } ?? "Add to week" }

    private var fitText: String {
        if cost.minorUnits > store.remainingBudget.minorUnits {
            return "Adds \((cost - store.remainingBudget).formatted()) over budget"
        }
        let after = store.remainingBudget - cost
        if let next = store.plan.slots.drop(while: { $0.recipeID != nil }).dropFirst().first?.day {
            return "Leaves \(after.formatted()) for \(next.rawValue)"
        }
        return "Leaves \(after.formatted()) in your budget"
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RecipeArtwork(style: recipe.artwork)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            PhotoScrim()

            VStack(alignment: .leading, spacing: 0) {
                Text(targetText)
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(WeeknightTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 76)

                Spacer(minLength: 80)

                HStack(alignment: .bottom, spacing: 14) {
                    positionTicks
                    VStack(alignment: .leading, spacing: 10) {
                        Text(recipe.title)
                            .font(dynamicTypeSize.isAccessibilitySize ? .title.weight(.black) : .system(size: 42, weight: .black))
                            .foregroundStyle(WeeknightTheme.photoText)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("discover-title-\(recipe.id)")
                            .overlay {
                                Button(action: onDetails) {
                                    Color.clear
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open \(recipe.title) details")
                                .accessibilityHint("Opens recipe details")
                                .accessibilityIdentifier("discover-details-\(recipe.id)")
                            }

                        Text("\(recipe.activeMinutes) min · serves \(servings) · \(cost.formatted())")
                            .font(.headline)
                            .foregroundStyle(WeeknightTheme.photoText.opacity(0.9))

                        Label(fitText, systemImage: cost.minorUnits > store.remainingBudget.minorUnits ? "exclamationmark.circle.fill" : "circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(cost.minorUnits > store.remainingBudget.minorUnits ? Color(hex: 0xFFB6A7) : WeeknightTheme.leaf)

                        Text(discoveryExplanation)
                            .font(.caption)
                            .foregroundStyle(WeeknightTheme.photoText.opacity(0.76))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                            .accessibilityIdentifier("discover-explanation-\(recipe.id)")

                        if let caution = ranked.cautions.first {
                            Label(caution, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Color(hex: 0xFFD7A0))
                                .lineLimit(2)
                        }
                    }
                }

                GeometryReader { proxy in
                    HStack(spacing: 12) {
                        Button {
                            store.toggleSaved(recipe.id)
                        } label: {
                            Text(store.isSaved(recipe.id) ? "SAVED" : "SAVE")
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .frame(width: 64, height: 54)
                        }
                        .foregroundStyle(WeeknightTheme.photoText)
                        .background(Color.black.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.62), lineWidth: 1)
                        }
                        .accessibilityLabel(store.isSaved(recipe.id) ? "Unsave \(recipe.title)" : "Save \(recipe.title)")
                        .accessibilityValue(store.isSaved(recipe.id) ? "Saved" : "Not saved")
                        .accessibilityIdentifier("discover-save-\(recipe.id)")

                        Button(addText, action: onAdd)
                            .buttonStyle(PrimaryActionButtonStyle())
                            .frame(width: max(0, proxy.size.width - 76))
                            .accessibilityIdentifier("add-recipe-\(recipe.id)")
                    }
                }
                .frame(height: 56)
                .padding(.top, 18)
                .padding(.bottom, 18)
            }
                .frame(
                    width: max(0, proxy.size.width - WeeknightTheme.Spacing.gutter * 2),
                    height: proxy.size.height,
                    alignment: .leading
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityElement(children: .contain)
    }

    private var discoveryExplanation: String {
        let dislikeContext = ranked.cautions.filter {
            $0.localizedCaseInsensitiveContains("marked as disliked")
        }
        let messages = ranked.explanations + dislikeContext
        return messages.isEmpty ? recipe.rationale : messages.joined(separator: " · ")
    }

    private var positionTicks: some View {
        VStack(spacing: 6) {
            ForEach(0..<min(count, 5), id: \.self) { index in
                Capsule()
                    .fill(index == position ? WeeknightTheme.photoText : WeeknightTheme.photoText.opacity(0.4))
                    .frame(width: 3, height: index == position ? 22 : 15)
            }
        }
        .padding(.bottom, 12)
        .accessibilityHidden(true)
    }
}
