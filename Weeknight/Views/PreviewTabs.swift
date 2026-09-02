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
                    .frame(minHeight: 44)
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
#if DEBUG
                    if navigation.showsLegacyDiscoverFeed {
                        LegacyDiscoverFeedView()
                    } else {
                        ForYouMealsView()
                    }
#else
                    ForYouMealsView()
#endif
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var query: String
    @State private var addRecipe: Recipe?
    @State private var swapDay: Weekday?
    @State private var selectedRecipeID: Recipe.ID?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        _query = State(initialValue: arguments.contains("--saved-no-results") ? "No matching supper" : "")
    }

    private var results: [Recipe] { store.savedRecipes(matching: query, filter: .recentlySaved) }

    var body: some View {
        ZStack {
            switch store.savedMode {
            case .loading:
                loadingState
            case .error:
                MealsStatePanel(
                    icon: "exclamationmark.arrow.triangle.2.circlepath",
                    title: "Saved meals didn’t load",
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
            VStack(alignment: .leading, spacing: 0) {
                MealsSearchField(
                    query: $query,
                    prompt: "Search saved meals…",
                    identifier: "saved-search",
                    accessibilityLabel: "Search saved meals by title, source, cuisine, ingredient, tag, or style"
                )
                .padding(.bottom, 16)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(store.savedCount) saved \(store.savedCount == 1 ? "meal" : "meals")")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .accessibilityIdentifier("saved-count")
                    Spacer(minLength: 8)
                    Text("Recently added")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WeeknightTheme.forest)
                }
                .padding(.bottom, 8)

                if store.savedCount == 0 {
                    emptyState.frame(minHeight: 420)
                } else if results.isEmpty {
                    noResultsState.frame(minHeight: 390)
                } else {
                    ForEach(results) { recipe in
                        savedRow(recipe)
                        Divider().overlay(WeeknightTheme.hairline)
                    }
                }
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.top, 4)
            .padding(.bottom, WeeknightTheme.Spacing.xLarge)
        }
        .scrollIndicators(.hidden)
    }

    private func savedRow(_ recipe: Recipe) -> some View {
        let servings = store.scheduledSlot(for: recipe.id)?.servings ?? store.preferences.householdSize
        let scheduledSlot = store.scheduledSlot(for: recipe.id)
        return VStack(alignment: .leading, spacing: 14) {
            Button { selectedRecipeID = recipe.id } label: {
                HStack(alignment: .top, spacing: 14) {
                    RecipeArtwork(style: recipe.artwork, compact: true)
                        .frame(
                            width: dynamicTypeSize.isAccessibilitySize ? 84 : 76,
                            height: dynamicTypeSize.isAccessibilitySize ? 84 : 76
                        )
                        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.thumbnail, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(WeeknightTheme.primaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(recipe.sourceName)
                            .font(.subheadline)
                            .foregroundStyle(WeeknightTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(recipe.activeMinutes) min · \(servings) \(servings == 1 ? "serving" : "servings") · \(store.estimatedCost(for: recipe, servings: servings).formatted())")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WeeknightTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(recipe.title), \(recipe.sourceName), \(recipe.activeMinutes) minutes, \(servings) servings, estimated \(store.estimatedCost(for: recipe, servings: servings).formatted())")
            .accessibilityHint("Opens Recipe Details")
            .accessibilityIdentifier("saved-details-\(recipe.id)")

            savedStatus(recipe, scheduledSlot: scheduledSlot)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    savedActions(recipe, scheduledSlot: scheduledSlot)
                }
                VStack(spacing: 10) {
                    savedActions(recipe, scheduledSlot: scheduledSlot)
                }
            }
        }
        .padding(.vertical, 18)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("saved-recipe-\(recipe.id)")
    }

    private func savedStatus(_ recipe: Recipe, scheduledSlot: MealSlot?) -> some View {
        let status = savedStatusContent(recipe, scheduledSlot: scheduledSlot)
        return Label(status.text, systemImage: status.symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(status.color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(status.text)
            .accessibilityIdentifier("saved-status-\(recipe.id)")
    }

    private func savedStatusContent(_ recipe: Recipe, scheduledSlot: MealSlot?) -> (text: String, symbol: String, color: Color) {
        if let scheduledSlot {
            return ("Already planned for \(scheduledSlot.day.rawValue)", "exclamationmark.triangle.fill", WeeknightTheme.citrus)
        }
        let eligibility = store.eligibility(for: recipe)
        if let reason = eligibility.hardReasons.first {
            return (reason.message, "exclamationmark.triangle.fill", WeeknightTheme.tomato)
        }
        if eligibility.exceedsPreferredCookingTime {
            return ("Longer than your \(store.preferences.maximumCookingMinutes)-minute preference", "clock.badge.exclamationmark", WeeknightTheme.citrus)
        }
        if store.estimatedCost(for: recipe, servings: store.preferences.householdSize) > store.remainingBudget {
            return ("Would exceed this week’s remaining budget", "exclamationmark.triangle.fill", WeeknightTheme.citrus)
        }
        return ("Fits your budget and time", "checkmark", WeeknightTheme.forest)
    }

    @ViewBuilder
    private func savedActions(_ recipe: Recipe, scheduledSlot: MealSlot?) -> some View {
        Button {
            if let scheduledSlot { swapDay = scheduledSlot.day } else { addRecipe = recipe }
        } label: {
            Label(
                scheduledSlot.map { "Replace \($0.day.rawValue)" } ?? "Add to Plan",
                systemImage: scheduledSlot == nil ? "plus" : "arrow.triangle.2.circlepath"
            )
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(WeeknightTheme.background)
        .padding(.horizontal, 12)
        .background(WeeknightTheme.forest)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(scheduledSlot == nil && !store.eligibility(for: recipe).isEligible)
        .accessibilityLabel(scheduledSlot.map { "Replace \(recipe.title) planned for \($0.day.rawValue)" } ?? "Add \(recipe.title) to plan")
        .accessibilityIdentifier("saved-plan-action-\(recipe.id)")

        Button { store.toggleSaved(recipe.id) } label: {
            Label("Saved", systemImage: "bookmark.fill")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(WeeknightTheme.forest)
        .padding(.horizontal, 12)
        .background(WeeknightTheme.wash)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(WeeknightTheme.forest.opacity(0.24), lineWidth: 1)
        }
        .accessibilityLabel("Unsave \(recipe.title)")
        .accessibilityValue("Saved")
        .accessibilityAddTraits(.isSelected)
        .accessibilityIdentifier("saved-unsave-\(recipe.id)")
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(WeeknightTheme.forest)
            Text("Loading saved recipes…").font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        MealsStatePanel(
            icon: "bookmark",
            title: "Nothing saved yet",
            message: "Save a meal from Explore and it will wait here for the right night.",
            action: "Find dinners",
            identifier: "saved-empty-state"
        ) { navigation.showMeals() }
    }

    private var noResultsState: some View {
        MealsStatePanel(
            icon: "magnifyingglass",
            title: "No saved meals found",
            message: "Try another title, source, cuisine, tag, style, or ingredient.",
            action: "Clear search",
            identifier: "saved-no-results-state"
        ) { query = "" }
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
            Section {
                Label("AI personalization and fallback", systemImage: "wand.and.stars")
                    .font(.headline)
                Text(personalizationSummary)
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                settingsSectionHeader("Personalization")
            }

            Section {
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
                    .accessibilityHint("Change these options in the iPhone Settings app")
            } header: {
                settingsSectionHeader("Accessibility behavior")
            }

            Section {
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
                Text("When a development personalization backend is configured, it receives only eligible recipe identifiers, planning totals, and soft preferences. Raw medical-allergen selections are not included in that request.")
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                settingsSectionHeader("Privacy and Data")
            }

            Section {
                Button(role: .destructive) {
                    showsResetConfirmation = true
                } label: {
                    Label("Reset local data", systemImage: "trash")
                        .frame(minHeight: 44)
                }
                .accessibilityHint("Asks for confirmation before resetting your week and local recipe data")
                .accessibilityIdentifier("settings-reset-data")
            } header: {
                settingsSectionHeader("Data Reset")
            }

            Section {
                settingsValueRow("Weeknight", value: versionText, symbol: "info.circle")
                Text("A warm, budget-aware weeknight dinner planner built for iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(WeeknightTheme.secondaryText)
            } header: {
                settingsSectionHeader("About")
            }

#if DEBUG
            Section {
                settingsValueRow("Catalogue", value: "\(store.recipes.count) recipes", symbol: "shippingbox")
                settingsValueRow("Recommendation source", value: store.backendState.displayTitle, symbol: "network")
                if let detail = store.backendState.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
            } header: {
                settingsSectionHeader("Developer diagnostics")
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
            Text("This restores the original local week and removes your preference changes, shopping progress, saved-recipe changes, and recipe notes.")
        }
        .accessibilityIdentifier("settings-screen")
    }

    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(WeeknightTheme.secondaryText)
            .textCase(nil)
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
