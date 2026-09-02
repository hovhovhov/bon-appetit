import SwiftUI

struct MealsView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var navigation = navigation

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Meals")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(WeeknightTheme.primaryText)
                    .accessibilityIdentifier("meals-title")

                if dynamicTypeSize.isAccessibilitySize {
                    Picker("Meals section", selection: $navigation.mealsSection) {
                        ForEach(MealsSection.allCases) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("meals-section-picker")
                } else {
                    Picker("Meals section", selection: $navigation.mealsSection) {
                        ForEach(MealsSection.allCases) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("meals-section-picker")
                }
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.top, WeeknightTheme.Spacing.standard)
            .padding(.bottom, 14)
            .background(WeeknightTheme.background)

            Group {
                if navigation.mealsSection == .saved {
                    SavedView()
                } else {
                    DiscoverView()
                }
            }
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .accessibilityIdentifier("meals-screen")
    }
}

struct SavedView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNavigation.self) private var navigation
    @State private var query: String
    @State private var filter: SavedFilter = .all
    @State private var addRecipe: Recipe?
    @State private var swapDay: Weekday?
    @State private var selectedRecipeID: Recipe.ID?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        _query = State(initialValue: arguments.contains("--saved-no-results") ? "No matching supper" : "")
    }

    private var results: [Recipe] { store.savedRecipes(matching: query, filter: filter) }
    private var mosaicRecipes: [Recipe] { Array(results.prefix(3)) }
    private var recentRecipes: [Recipe] {
        if results.count > 3 { return Array(results.dropFirst(3)) }
        return results.count < 3 ? results : []
    }

    var body: some View {
        Group {
            switch store.savedMode {
            case .loading:
                loadingState
            case .error:
                statePanel(
                    icon: "exclamationmark.arrow.triangle.2.circlepath",
                    title: "Saved recipes didn’t load",
                    message: "Your local library is still on this iPhone.",
                    action: "Try again"
                ) { Task { await store.retrySaved() } }
            case .empty:
                emptyState
            case .ready, .stale:
                library
            }
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(item: $selectedRecipeID) { recipeID in
            if let recipe = store.recipesForCalculations.first(where: { $0.id == recipeID }) {
                RecipeDetailsView(
                    recipeID: recipe.id,
                    origin: .saved,
                    initialServings: store.scheduledSlot(for: recipe.id)?.servings ?? store.preferences.householdSize
                )
            }
        }
        .sheet(item: $addRecipe) { recipe in
            AddToWeekSheet(recipe: recipe, servings: store.preferences.householdSize)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(WeeknightTheme.Radius.sheet)
        }
        .sheet(item: $swapDay) { day in
            SwapMealSheet(day: day) {}
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(WeeknightTheme.Radius.sheet)
        }
        .accessibilityIdentifier("saved-screen")
    }

    private var library: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Saved")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Spacer()
                    Text("\(store.savedCount) recipes")
                        .font(.headline)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .accessibilityIdentifier("saved-count")
                }
                .padding(.top, WeeknightTheme.Spacing.standard)

                searchField
                filterPicker

                if store.savedCount == 0 {
                    emptyState.frame(minHeight: 420)
                } else if results.isEmpty {
                    noResultsState.frame(minHeight: 390)
                } else {
                    if !mosaicRecipes.isEmpty { savedMosaic }
                    if !recentRecipes.isEmpty {
                        Text("RECENTLY SAVED")
                            .font(.caption.weight(.bold))
                            .tracking(1.8)
                            .foregroundStyle(WeeknightTheme.secondaryText)
                            .padding(.top, 4)
                        ForEach(recentRecipes) { recipe in
                            savedRow(recipe)
                            Divider().overlay(WeeknightTheme.hairline)
                        }
                    }
                }
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.bottom, WeeknightTheme.Spacing.xLarge)
        }
        .scrollIndicators(.hidden)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(WeeknightTheme.secondaryText)
            TextField("Search recipes, tags or ingredients…", text: $query)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .accessibilityIdentifier("saved-search")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                }
                .foregroundStyle(WeeknightTheme.secondaryText)
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("clear-saved-search")
            }
        }
        .padding(.leading, 16)
        .frame(minHeight: 52)
        .background(WeeknightTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var filterPicker: some View {
        HStack(spacing: 18) {
            ForEach(SavedFilter.allCases) { option in
                Button {
                    filter = option
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(filter == option ? WeeknightTheme.forest : WeeknightTheme.secondaryText)
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) {
                            if filter == option {
                                Capsule().fill(WeeknightTheme.forest).frame(height: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == option ? .isSelected : [])
                .accessibilityIdentifier("saved-filter-\(option == .all ? "all" : "recent")")
            }
            Spacer()
        }
        .accessibilityLabel("Saved recipe filters")
    }

    private var savedMosaic: some View {
        Group {
            if mosaicRecipes.count >= 3 {
                HStack(spacing: 7) {
                    mosaicTile(mosaicRecipes[0])
                        .frame(maxWidth: .infinity)
                    VStack(spacing: 7) {
                        mosaicTile(mosaicRecipes[1])
                        mosaicTile(mosaicRecipes[2])
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 282)
            } else {
                ForEach(mosaicRecipes) { savedRow($0) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))
    }

    private func mosaicTile(_ recipe: Recipe) -> some View {
        let servings = store.scheduledSlot(for: recipe.id)?.servings ?? store.preferences.householdSize
        return Button {
            selectedRecipeID = recipe.id
        } label: {
            ZStack(alignment: .bottomLeading) {
                RecipeArtwork(style: recipe.artwork)
                LinearGradient(colors: [.clear, .black.opacity(0.66)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(WeeknightTheme.photoText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(recipe.activeMinutes) min · \(store.estimatedCost(for: recipe, servings: servings).formatted())")
                        .font(.caption)
                        .foregroundStyle(WeeknightTheme.photoText.opacity(0.84))
                }
                .padding(12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("saved-recipe-\(recipe.id)")
        .accessibilityLabel("\(recipe.title), \(recipe.activeMinutes) minutes, \(store.estimatedCost(for: recipe, servings: servings).formatted())")
    }

    private func savedRow(_ recipe: Recipe) -> some View {
        let servings = store.scheduledSlot(for: recipe.id)?.servings ?? store.preferences.householdSize
        return HStack(spacing: 12) {
            Button {
                selectedRecipeID = recipe.id
            } label: {
                HStack(spacing: 12) {
                    RecipeArtwork(style: recipe.artwork, compact: true)
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.thumbnail, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipe.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(WeeknightTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(recipe.sourceName) · \(recipe.activeMinutes) min · \(store.estimatedCost(for: recipe, servings: servings).formatted())")
                            .font(.subheadline)
                            .foregroundStyle(WeeknightTheme.secondaryText)
                            .lineLimit(2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("saved-recipe-\(recipe.id)")

            Spacer(minLength: 4)

            Menu {
                Button(store.scheduledSlot(for: recipe.id) == nil ? "Add to week" : "Swap meal") {
                    if let slot = store.scheduledSlot(for: recipe.id) { swapDay = slot.day } else { addRecipe = recipe }
                }
                .disabled(store.scheduledSlot(for: recipe.id) == nil && !store.eligibility(for: recipe).isEligible)
                Button("Unsave", role: .destructive) { store.toggleSaved(recipe.id) }
            } label: {
                Text("Add")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WeeknightTheme.forest)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(WeeknightTheme.forest, lineWidth: 1)
                    }
            }
            .accessibilityIdentifier("saved-plan-action-\(recipe.id)")
        }
        .padding(.vertical, 9)
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(WeeknightTheme.forest)
            Text("Loading saved recipes…").font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        statePanel(
            icon: "bookmark",
            title: "Nothing saved yet",
            message: "Save a dinner from For You and it will wait here for the right night.",
            action: "Find dinners"
        ) { navigation.showMeals() }
        .accessibilityIdentifier("saved-empty-state")
    }

    private var noResultsState: some View {
        statePanel(
            icon: "magnifyingglass",
            title: "No saved recipes found",
            message: "Try another title, source, tag or ingredient.",
            action: "Clear search"
        ) { query = "" }
        .accessibilityIdentifier("saved-no-results-state")
    }

    private func statePanel(
        icon: String,
        title: String,
        message: String,
        action: String,
        perform: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(WeeknightTheme.forest)
            Text(title)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(WeeknightTheme.primaryText)
            Text(message)
                .font(.body)
                .foregroundStyle(WeeknightTheme.secondaryText)
            Button(action, action: perform)
                .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var showsResetConfirmation = false

    var body: some View {
        List {
            Section("Personalization") {
                Label("How suggestions work", systemImage: "wand.and.stars")
                    .font(.headline)
                Text(personalizationSummary)
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Accessibility behavior") {
                settingsValueRow("Reduce Motion", value: reduceMotion ? "On" : "Off", symbol: "figure.walk.motion")
                settingsValueRow(
                    "Differentiate Without Color",
                    value: differentiateWithoutColor ? "On" : "Off",
                    symbol: "circle.lefthalf.filled"
                )
                settingsValueRow(
                    "Increase Contrast",
                    value: colorSchemeContrast == .increased ? "On" : "Off",
                    symbol: "circle.righthalf.filled"
                )
                Text("Weeknight follows these iPhone accessibility settings automatically.")
                    .font(.footnote)
                    .foregroundStyle(WeeknightTheme.secondaryText)
            }

            Section("Privacy and Data") {
                Label("Stored on this iPhone", systemImage: "iphone")
                    .font(.headline)
                Text("Your week, preferences, saved recipes, notes, and shopping progress are stored locally. Weeknight does not require an account.")
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Medical and dietary rules are applied on the device before any optional personalized selection.")
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Data Reset") {
                Button(role: .destructive) {
                    showsResetConfirmation = true
                } label: {
                    Label("Reset local data", systemImage: "trash")
                        .frame(minHeight: 44)
                }
                .accessibilityHint("Asks for confirmation before resetting your week and local recipe data")
                .accessibilityIdentifier("settings-reset-data")
            }

            Section("About") {
                settingsValueRow("Weeknight", value: versionText, symbol: "info.circle")
                Text("A warm, budget-aware weeknight dinner planner built for iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
            }

#if DEBUG
            Section("Developer diagnostics") {
                settingsValueRow("Catalogue", value: "\(store.recipes.count) recipes", symbol: "shippingbox")
                settingsValueRow("Recommendation source", value: store.backendState.displayTitle, symbol: "network")
                if let detail = store.backendState.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
            }
#endif
        }
        .scrollContentBackground(.hidden)
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Reset local Weeknight data?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset week and local data", role: .destructive) {
                store.resetFixture()
                navigation.showPlans()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This restores the demo week and removes your local preference changes, shopping progress, saved-recipe changes, and recipe notes.")
        }
        .accessibilityIdentifier("settings-screen")
    }

    private var personalizationSummary: String {
        switch store.backendState {
        case .connected:
            "Personalized suggestions are active. Every result is checked again against your medical, dietary, equipment, and budget rules before it can reach your plan."
        case .loading:
            "Weeknight is preparing personalized suggestions. Local recommendations remain available while it connects."
        case .fallback, .cached, .unavailable, .local:
            "Suggestions are selected on this iPhone using your preferences. Medical, dietary, equipment, and budget rules are always enforced."
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    private func settingsValueRow(_ title: String, value: String, symbol: String) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(WeeknightTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        } label: {
            Label(title, systemImage: symbol)
                .foregroundStyle(WeeknightTheme.primaryText)
        }
        .accessibilityElement(children: .combine)
    }
}
