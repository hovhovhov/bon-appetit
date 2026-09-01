import SwiftUI

struct SavedView: View {
    @Environment(AppStore.self) private var store
    @State private var query: String
    @State private var filter: SavedFilter = .all
    @State private var addRecipe: Recipe?
    @State private var swapDay: Weekday?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        _query = State(initialValue: arguments.contains("--saved-no-results") ? "No matching supper" : "")
    }

    private var results: [Recipe] {
        store.savedRecipes(matching: query, filter: filter)
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
                    message: "Your local library is still on this iPhone. Try loading it again.",
                    action: "Try again"
                ) { Task { await store.retrySaved() } }
            case .empty:
                emptyState
            case .ready, .stale:
                library
            }
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $addRecipe) { recipe in
            AddToWeekSheet(recipe: recipe)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $swapDay) { day in
            SwapMealSheet(day: day) {}
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .accessibilityIdentifier("saved-screen")
    }

    private var library: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your recipe shelf")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Spacer()
                    Text("\(store.savedCount) saved")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .accessibilityIdentifier("saved-count")
                }

                searchField
                filterPicker

                if store.savedCount == 0 {
                    emptyState
                        .frame(minHeight: 360)
                } else if results.isEmpty {
                    noResultsState
                        .frame(minHeight: 330)
                } else {
                    ForEach(results) { recipe in
                        savedCard(recipe)
                    }
                }
            }
            .padding(.horizontal, WeeknightTheme.Spacing.gutter)
            .padding(.bottom, WeeknightTheme.Spacing.xLarge)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(WeeknightTheme.secondaryText)
            TextField("Search recipes, tags or ingredients", text: $query)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .accessibilityIdentifier("saved-search")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(WeeknightTheme.secondaryText)
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("clear-saved-search")
            }
        }
        .padding(.leading, 14)
        .frame(minHeight: 52)
        .background(WeeknightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WeeknightTheme.forest.opacity(0.12), lineWidth: 1)
        }
    }

    private var filterPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(SavedFilter.allCases) { option in
                    Button {
                        filter = option
                    } label: {
                        Text(option.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(filter == option ? WeeknightTheme.forest : WeeknightTheme.surface)
                            .foregroundStyle(filter == option ? WeeknightTheme.background : WeeknightTheme.primaryText)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == option ? .isSelected : [])
                    .accessibilityIdentifier("saved-filter-\(option == .all ? "all" : "recent")")
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Saved recipe filters")
    }

    private func savedCard(_ recipe: Recipe) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                RecipeDetailsView(
                    recipeID: recipe.id,
                    origin: .saved,
                    initialServings: store.scheduledSlot(for: recipe.id)?.servings ?? recipe.servings
                )
            } label: {
                HStack(alignment: .top, spacing: 13) {
                    RecipeArtwork(style: recipe.artwork, compact: true)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 7) {
                        if let slot = store.scheduledSlot(for: recipe.id) {
                            StatusPill(
                                text: slot.day.rawValue,
                                color: WeeknightTheme.forest,
                                background: WeeknightTheme.mint,
                                systemImage: "calendar"
                            )
                        }
                        Text(recipe.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(WeeknightTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(recipe.sourceName) · \(recipe.activeMinutes)m · \(recipe.estimatedCost.formatted())")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WeeknightTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(WeeknightTheme.secondaryText)
                }
                .padding(13)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("saved-recipe-\(recipe.id)")

            Divider().padding(.horizontal, 13)

            HStack(spacing: 8) {
                Button {
                    if let slot = store.scheduledSlot(for: recipe.id) {
                        swapDay = slot.day
                    } else {
                        addRecipe = recipe
                    }
                } label: {
                    Label(
                        store.scheduledSlot(for: recipe.id) == nil ? "Add to week" : "Swap meal",
                        systemImage: store.scheduledSlot(for: recipe.id) == nil ? "plus" : "arrow.triangle.2.circlepath"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(WeeknightTheme.bottle)
                .accessibilityIdentifier("saved-plan-action-\(recipe.id)")

                Button {
                    store.toggleSaved(recipe.id)
                } label: {
                    Label("Unsave", systemImage: "bookmark.slash")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("saved-unsave-\(recipe.id)")
            }
            .padding(13)
        }
        .weeknightCard()
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(WeeknightTheme.bottle)
            Text("Loading saved recipes…")
                .font(.headline)
                .foregroundStyle(WeeknightTheme.primaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Loading saved recipes")
    }

    private var emptyState: some View {
        statePanel(
            icon: "bookmark",
            title: "Your saved shelf is empty",
            message: "Save a recipe from Discover or Recipe details and it will appear here.",
            action: "Open Discover"
        ) { store.selectedTab = .discover }
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
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(WeeknightTheme.bottle)
            Text(title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(WeeknightTheme.primaryText)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(WeeknightTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button(action, action: perform)
                .buttonStyle(ForestActionButtonStyle())
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PreferencesPreviewView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your setup")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(WeeknightTheme.primaryText)
                Text("Preferences editing is planned for a later milestone. These values describe the active fixture and are read-only here.")
                    .font(.body)
                    .foregroundStyle(WeeknightTheme.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    Text("PLANNING FOR")
                        .font(.caption.weight(.bold))
                        .tracking(1.3)
                        .foregroundStyle(WeeknightTheme.background.opacity(0.62))
                    Text("1 person · 5 dinners a week · \(store.plan.budget.formatted()) at \(store.plan.storeName)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.background)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WeeknightTheme.deepPine)
                .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))

                VStack(spacing: 0) {
                    staticRow("Supermarket", value: store.plan.storeName, effect: "Prices")
                    Divider().padding(.leading, 16)
                    staticRow("Cooking days", value: "Mon, Tue, Wed, Thu, Fri", effect: "Plan")
                    Divider().padding(.leading, 16)
                    staticRow("Weekly budget", value: store.plan.budget.formatted(), effect: "Budget")
                }
                .weeknightCard()

                Button {
                    store.resetFixture()
                } label: {
                    Label("Reset demo week", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(ForestActionButtonStyle())
                .accessibilityHint("Restores the canonical three-dinner fixture and shopping progress")
                .accessibilityIdentifier("reset-fixture")
            }
            .padding(WeeknightTheme.Spacing.gutter)
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func staticRow(_ title: String, value: String, effect: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.primaryText)
                Text(effect.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(WeeknightTheme.bottle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WeeknightTheme.wash)
                    .clipShape(Capsule())
            }
            Text(value)
                .font(.body)
                .foregroundStyle(WeeknightTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
